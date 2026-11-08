#ifndef MANUAL_FIBO_DIALOG_MQH
#define MANUAL_FIBO_DIALOG_MQH
#include <_common\Fibo\FiboDialog.mqh>
#include <Controls\ComboBox.mqh>

// CListView treats zero as an automatic item value; use explicit positive IDs.
enum ManualFiboRiskChoice { MANUAL_RISK_ALL = 1, MANUAL_RISK_PER_LEVEL = 2 };

// Trading controls belong only to manualFibo, never to the shared AutoFibo GUI.
class CManualFiboDialog : public CFiboDialog
{
private:
   CButton m_send, m_delete;
   CCheckBox m_take_profit;
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
      bool created = m_take_profit.Create(chart, name + ".TP", subwin, 374, 386, 584, 410)
             && m_take_profit.Text("TP: swing end") && m_take_profit.Checked(true) && Add(m_take_profit)
             && Label(m_total, chart, name + ".Total", "Total est. loss: -", 14, 450, 584, 472)
             && m_send.Create(chart, name + ".Send", subwin, 14, 484, 288, 514)
             && m_send.Text("Send Orders") && Add(m_send)
             && m_delete.Create(chart, name + ".Delete", subwin, 310, 484, 584, 514)
             && m_delete.Text("Delete Orders") && Add(m_delete);
      if(!created) Print("manualFibo GUI: trading controls failed, error ", GetLastError());
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
      return CFiboDialog::OnEvent(id, lparam, dparam, sparam);
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
      ChartEvent(id, lparam, dparam, sparam);
   }
   bool RiskAll(void) { return m_risk_mode.Value() == MANUAL_RISK_ALL; }
   void SyncRiskMode(const CFiboModel &model)
   { m_risk_mode.SelectByValue(model.RiskAll() ? MANUAL_RISK_ALL : MANUAL_RISK_PER_LEVEL); }
   bool UseTP(void) { return m_take_profit.Checked(); }
   void UseTP(const bool value) { m_take_profit.Checked(value); }
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
