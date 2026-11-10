#ifndef MANUAL_FIBO_DIALOG_MQH
#define MANUAL_FIBO_DIALOG_MQH
#include <_common\Fibo\FiboDialog.mqh>
#include <Controls\ComboBox.mqh>
#include "ManualFiboSettings.mqh"

// CListView treats zero as an automatic item value; use explicit positive IDs.
enum ManualFiboRiskChoice { MANUAL_RISK_ALL = 1, MANUAL_RISK_PER_LEVEL = 2 };

// Trading controls belong only to manualFibo, never to the shared AutoFibo GUI.
class CManualFiboDialog : public CFiboDialog
{
private:
   CButton m_send, m_delete;
   CComboBox m_tp_mode;
   CEdit m_rr;
   CLabel m_rr_label;
   string m_rr_name;
   CComboBox m_risk_mode;
   CLabel m_total;
   int m_trade_action;
public:
   CManualFiboDialog(void) { m_trade_action = 0; CompactRisk(true); }
   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      m_trade_action = 0;
      if(!CFiboDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      { Print("manualFibo GUI: shared controls failed, error ", GetLastError()); return false; }
      if(!m_risk_mode.Create(chart, name + ".RiskMode", subwin, 324, 66, 584, 92)
         || !m_risk_mode.AddItem("All", MANUAL_RISK_ALL)
         || !m_risk_mode.AddItem("Per level", MANUAL_RISK_PER_LEVEL))
      { Print("manualFibo GUI: risk mode creation/items failed, error ", GetLastError()); return false; }
      m_risk_mode.ListViewItems(2);
      if(!m_risk_mode.SelectByValue(MANUAL_RISK_PER_LEVEL) || !Add(m_risk_mode))
      { Print("manualFibo GUI: risk mode selection/registration failed, error ", GetLastError()); return false; }
      m_rr_name = name + ".RR";
      if(!m_tp_mode.Create(chart, name + ".TPMode", subwin, 374, 386, 584, 412)
         || !m_tp_mode.AddItem("Tanpa TP", MANUAL_TP_NONE) || !m_tp_mode.AddItem("Swing end", MANUAL_TP_SWING)
         || !m_tp_mode.AddItem("RR", MANUAL_TP_RR))
      { Print("manualFibo GUI: TP mode creation/items failed, error ", GetLastError()); return false; }
      m_tp_mode.ListViewItems(3);
      if(!m_tp_mode.SelectByValue(MANUAL_TP_SWING) || !Add(m_tp_mode))
      { Print("manualFibo GUI: TP mode selection/registration failed, error ", GetLastError()); return false; }
      bool created = Label(m_rr_label, chart, name + ".RRLabel", "RR", 440, 452, 472, 472)
             && Edit(m_rr, chart, m_rr_name, subwin, "2", 480, 450, 584, 474)
             && Label(m_total, chart, name + ".Total", "Total est. loss: -", 14, 450, 426, 472)
             && m_send.Create(chart, name + ".Send", subwin, 14, 484, 288, 514)
             && m_send.Text("Send Orders") && Add(m_send)
             && m_delete.Create(chart, name + ".Delete", subwin, 310, 484, 584, 514)
             && m_delete.Text("Delete Orders") && Add(m_delete);
      if(!created) Print("manualFibo GUI: RR/trading controls failed, error ", GetLastError());
      if(created) UpdateRRVisibility();
      return created;
   }
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK)
      {
         if(lparam == m_send.Id()) { m_trade_action = 1; return true; }
         if(lparam == m_delete.Id()) { m_trade_action = 2; return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE && lparam == m_risk_mode.Id())
      { m_trade_action = 3; return true; }
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE && lparam == m_tp_mode.Id())
      { m_trade_action = 4; return true; }
      bool handled = CFiboDialog::OnEvent(id, lparam, dparam, sparam);
      if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == m_rr_name)
      { m_trade_action = 5; return true; }
      return handled;
   }
   int TakeTradeAction(void) { int action = m_trade_action; m_trade_action = 0; return action; }
   void DispatchEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CHART_CHANGE && !IsMinimized())
      {
         long chart_height = ChartGetInteger(m_chart_id, CHART_HEIGHT_IN_PIXELS, 0);
         if(chart_height <= 0 || chart_height < Height() + CONTROLS_BORDER_WIDTH)
         {
            if(CDialog::OnEvent(id, lparam, dparam, sparam)) ChartRedraw(m_chart_id);
            SubwinOff(); return;
         }
      }
      bool minimized = IsMinimized();
      ChartEvent(id, lparam, dparam, sparam);
      if(minimized && !IsMinimized()) UpdateRRVisibility();
   }
   bool RiskAll(void) { return m_risk_mode.Value() == MANUAL_RISK_ALL; }
   void SyncRiskMode(const CFiboModel &model)
   { m_risk_mode.SelectByValue(model.RiskAll() ? MANUAL_RISK_ALL : MANUAL_RISK_PER_LEVEL); }
   ManualFiboTPMode TPMode(void) { return (ManualFiboTPMode)m_tp_mode.Value(); }
   bool ReadSettings(CManualFiboSettings &settings)
   {
      if(!settings.SetTPMode(TPMode())) return false;
      if(TPMode() != MANUAL_TP_RR) return true;
      double rr = 0;
      return FiboParseNumber(m_rr.Text(), rr) && settings.SetRR(rr);
   }
   void RefreshSettings(const CManualFiboSettings &settings)
   {
      if(m_tp_mode.Value() != (long)settings.TPMode()) m_tp_mode.SelectByValue(settings.TPMode());
      string rr = DoubleToString(settings.RR(), 8);
      while(StringLen(rr) > 1 && StringSubstr(rr, StringLen(rr) - 1) == "0") rr = StringSubstr(rr, 0, StringLen(rr) - 1);
      if(StringSubstr(rr, StringLen(rr) - 1) == ".") rr = StringSubstr(rr, 0, StringLen(rr) - 1);
      SetText(m_rr, rr); UpdateRRVisibility();
   }
   void UpdateRRVisibility(void)
   {
      bool show = TPMode() == MANUAL_TP_RR && !IsMinimized();
      if(show)
      {
         if(!m_rr.IsVisible()) m_rr.Show();
         if(!m_rr_label.IsVisible()) m_rr_label.Show();
      }
      else
      {
         if(m_rr.IsVisible()) m_rr.Hide();
         if(m_rr_label.IsVisible()) m_rr_label.Hide();
      }
   }
   virtual bool RefreshLots(const CFiboModel &model)
   {
      bool changed = CFiboDialog::RefreshLots(model);
      string text = m_all_lots_valid ? DoubleToString(m_total_loss, 2) + " " + m_loss_currency : "- (level invalid)";
      if(SetText(m_total, "Total est. loss: " + text + (model.RiskAll() ? " | All" : " | Per level"))) changed = true;
      return changed;
   }
   // Separate geometry version: old saved panel heights must not clip the buttons.
   virtual string IniFileName(void) const { return "manualFibo_" + IntegerToString(ChartID()) + "_GUI_v6"; }
};
#endif
