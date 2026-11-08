#ifndef MANUAL_FIBO_DIALOG_MQH
#define MANUAL_FIBO_DIALOG_MQH
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\CheckBox.mqh>
#include <Controls\Panel.mqh>
#include <Controls\Edit.mqh>
#include "ManualFiboRisk.mqh"

enum ManualFiboAction { MANUAL_NONE, MANUAL_DRAW, MANUAL_RESET, MANUAL_LEVELS, MANUAL_LOCK, MANUAL_RISK, MANUAL_SL };

class CManualFiboDialog : public CAppDialog
{
private:
   CPanel m_swing_frame[5], m_risk_frame[5], m_fibo_frame[5];
   CButton m_draw, m_reset;
   CLabel m_swing_title, m_start, m_end, m_fibo_title, m_status;
   CCheckBox m_levels[MANUAL_FIBO_RATIOS];
   CCheckBox m_lock;
   CEdit m_risk_edit, m_stops[MANUAL_FIBO_RATIOS];
   CLabel m_risk_title, m_risk_label, m_budget, m_risk_note;
   CLabel m_entry_header, m_sl_header, m_lot_header, m_loss_header;
   CLabel m_lots[MANUAL_FIBO_RATIOS], m_losses[MANUAL_FIBO_RATIOS];
   string m_control_prefix, m_tooltips[MANUAL_FIBO_RATIOS];
   int m_edit_index;
   ManualFiboAction m_action;
public:
   CManualFiboDialog(void) { m_action = MANUAL_NONE; }
   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      m_action = MANUAL_NONE; m_edit_index = -1; m_control_prefix = name;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) m_tooltips[i] = "";
      if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2) || !Caption("manualFibo")) return false;
      // Register decorative frames first so native controls are created above them.
      if(!Group(m_swing_frame, chart, name + ".SwingGroup", subwin, 6, 14, 300, 128, 14, 90)
         || !Group(m_risk_frame, chart, name + ".RiskGroup", subwin, 312, 14, 596, 128, 320, 396)
         || !Group(m_fibo_frame, chart, name + ".FiboGroup", subwin, 6, 142, 596, 374, 14, 122)) return false;
      if(!Label(m_swing_title, chart, name + ".SwingTitle", "Swing", 20, 4, 84, 24)
         || !Label(m_risk_title, chart, name + ".RiskTitle", "Risk", 326, 4, 390, 24)
         || !Label(m_fibo_title, chart, name + ".FiboTitle", "Fibonacci", 20, 132, 116, 152)
         || !m_draw.Create(chart, name + ".Draw", subwin, 14, 34, 174, 62)
         || !m_draw.Text("Pilih Swing") || !Add(m_draw)
         || !m_reset.Create(chart, name + ".Reset", subwin, 188, 34, 288, 62)
         || !m_reset.Text("Reset") || !Add(m_reset)
         || !Label(m_start, chart, name + ".Start", "Awal: -", 14, 74, 288, 94)
         || !Label(m_end, chart, name + ".End", "Akhir: -", 14, 100, 288, 120)
         || !Label(m_risk_label, chart, name + ".RiskLabel", "% Equity", 324, 36, 432, 56)
         || !Edit(m_risk_edit, chart, name + ".Risk", subwin, "5", 442, 32, 584, 58)
         || !Label(m_budget, chart, name + ".Budget", "Budget: -", 324, 68, 584, 88)
         || !Label(m_risk_note, chart, name + ".RiskNote", "Risk per level, bukan total.", 324, 98, 584, 118)
         || !Label(m_entry_header, chart, name + ".EntryHeader", "Level / Entry", 14, 160, 210, 180)
         || !Label(m_sl_header, chart, name + ".SLHeader", "SL price", 224, 160, 350, 180)
         || !Label(m_lot_header, chart, name + ".LotHeader", "Lot", 366, 160, 454, 180)
         || !Label(m_loss_header, chart, name + ".LossHeader", "Est. loss", 470, 160, 584, 180)) return false;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
      {
         int top = 186 + i * 30;
         if(!m_levels[i].Create(chart, name + ".Level" + IntegerToString(i), subwin, 14, top, 210, top + 24)
            || !m_levels[i].Text(DoubleToString(ManualFiboRatio(i) * 100.0, 1) + "%: -")
            || !m_levels[i].Checked((MANUAL_FIBO_DEFAULT_MASK & (1 << i)) != 0)
            || !Add(m_levels[i])
            || !Edit(m_stops[i], chart, name + ".SL" + IntegerToString(i), subwin, "", 224, top, 350, top + 24)
            || !Label(m_lots[i], chart, name + ".Lot" + IntegerToString(i), "-", 366, top + 2, 458, top + 24)
            || !Label(m_losses[i], chart, name + ".Loss" + IntegerToString(i), "-", 470, top + 2, 584, top + 24)) return false;
      }
      return m_lock.Create(chart, name + ".Lock", subwin, 14, 386, 360, 410)
             && m_lock.Text("Kunci anchor") && m_lock.Checked(false) && Add(m_lock)
             && Label(m_status, chart, name + ".Status", "Klik Pilih Swing.", 14, 422, 584, 444);
   }
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK)
      {
         if(lparam == m_draw.Id()) { m_action = MANUAL_DRAW; return true; }
         if(lparam == m_reset.Id()) { m_action = MANUAL_RESET; return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE)
      {
         if(lparam == m_lock.Id()) { m_action = MANUAL_LOCK; return true; }
         for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
            if(lparam == m_levels[i].Id()) { m_action = MANUAL_LEVELS; return true; }
      }
      bool handled = CAppDialog::OnEvent(id, lparam, dparam, sparam);
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
      {
         if(sparam == m_control_prefix + ".Risk") { m_action = MANUAL_RISK; return true; }
         for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
            if(sparam == m_control_prefix + ".SL" + IntegerToString(i))
            { m_edit_index = i; m_action = MANUAL_SL; return true; }
      }
      return handled;
   }
   ManualFiboAction TakeAction(void)
   { ManualFiboAction action = m_action; m_action = MANUAL_NONE; return action; }
   int RatioMask(void)
   {
      int mask = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) if(m_levels[i].Checked()) mask |= 1 << i;
      return mask;
   }
   string RiskText(void) { return m_risk_edit.Text(); }
   int EditIndex(void) const { return m_edit_index; }
   string StopText(const int index) { return m_stops[index].Text(); }
   bool AnchorLocked(void) { return m_lock.Checked(); }
   bool RefreshRiskInput(const CManualFiboModel &model)
   {
      string percent = DoubleToString(model.RiskPercent(), 8);
      while(StringLen(percent) > 1 && StringSubstr(percent, StringLen(percent) - 1) == "0")
         percent = StringSubstr(percent, 0, StringLen(percent) - 1);
      if(StringSubstr(percent, StringLen(percent) - 1) == ".") percent = StringSubstr(percent, 0, StringLen(percent) - 1);
      return SetText(m_risk_edit, percent);
   }
   bool RefreshStopInput(const CManualFiboModel &model, const int index)
   {
      if(index < 0 || index >= MANUAL_FIBO_RATIOS) return false;
      double stop = model.StopPrice(index);
      return SetText(m_stops[index], stop == EMPTY_VALUE ? "" : DoubleToString(stop, _Digits));
   }
   void Refresh(const CManualFiboModel &model)
   {
      SetText(m_start, model.Ready() ? "Awal: " + DoubleToString(model.StartPrice(), _Digits) : "Awal: -");
      SetText(m_end, model.Ready() ? "Akhir: " + DoubleToString(model.EndPrice(), _Digits) : "Akhir: -");
      RefreshRiskInput(model);
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
      {
         RefreshStopInput(model, i);
         if(m_levels[i].Checked() != model.Enabled(i)) m_levels[i].Checked(model.Enabled(i));
         SetText(m_levels[i], DoubleToString(ManualFiboRatio(i) * 100.0, 1) + "%: "
                 + (model.Ready() ? DoubleToString(model.Price(i), _Digits) : "-"));
      }
      if(m_lock.Checked() != model.Locked()) m_lock.Checked(model.Locked());
      RefreshLots(model);
   }
   // Timer updates results only; never overwrite an SL or risk edit in progress.
   bool RefreshLots(const CManualFiboModel &model)
   {
      CManualFiboRisk calculator;
      ManualFiboRiskContext context; calculator.ReadContext(model, context);
      string currency = context.currency;
      bool changed = SetText(m_budget, "Budget: " + DoubleToString(context.budget, 2) + " " + currency);
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
      {
         ManualFiboLot result;
         bool valid = calculator.Calculate(model, i, context, result);
         string lot = valid ? DoubleToString(result.volume, context.volume_digits) : result.error;
         if(SetText(m_lots[i], lot)) changed = true;
         if(SetText(m_losses[i], valid ? DoubleToString(result.loss, 2) : "-")) changed = true;
         string tooltip = ManualFiboLimitName(result.kind) + "; " + (valid ? "Entry " + DoubleToString(result.entry, _Digits) + "; SL "
                          + DoubleToString(result.stop, _Digits) + "; loss " + DoubleToString(result.loss, 2) + " " + currency
                          : result.error);
         if(m_tooltips[i] != tooltip && ObjectSetString(m_chart_id, m_control_prefix + ".Lot" + IntegerToString(i), OBJPROP_TOOLTIP, tooltip))
            m_tooltips[i] = tooltip;
      }
      return changed;
   }
   void SetStatus(const string text, const bool selecting)
   {
      bool changed = SetText(m_status, text);
      if(SetText(m_draw, selecting ? "Batal" : "Pilih Swing")) changed = true;
      if(changed) ChartRedraw(m_chart_id);
   }
   virtual string IniFileName(void) const { return "manualFibo_" + IntegerToString(ChartID()) + "_GUI_v5"; }
   bool IsMinimized(void) const { return m_minimized; }
   bool Dragging(void) const { return m_drag_object != NULL; }
   void CancelDrag(void) { if(Dragging()) CDialog::OnDialogDragEnd(); MouseFocusKill(); }
protected:
   // Five one-pixel edges leave a real gap for a transparent title label.
   // All pieces belong to the native dialog: no extra mouse or drag driver.
   bool Group(CPanel &edges[], const long chart, const string name, const int subwin,
              const int x1, const int y1, const int x2, const int y2,
              const int gap_start, const int gap_end)
   {
      return Edge(edges[0], chart, name + ".TopLeft", subwin, x1, y1, gap_start, y1 + 1)
             && Edge(edges[1], chart, name + ".TopRight", subwin, gap_end, y1, x2, y1 + 1)
             && Edge(edges[2], chart, name + ".Left", subwin, x1, y1, x1 + 1, y2)
             && Edge(edges[3], chart, name + ".Right", subwin, x2 - 1, y1, x2, y2)
             && Edge(edges[4], chart, name + ".Bottom", subwin, x1, y2 - 1, x2, y2);
   }
   bool Edge(CPanel &panel, const long chart, const string name, const int subwin,
             const int x1, const int y1, const int x2, const int y2)
   {
      return panel.Create(chart, name, subwin, x1, y1, x2, y2)
             && panel.BorderType(BORDER_FLAT)
             && panel.ColorBackground(clrSilver) && panel.ColorBorder(clrSilver) && Add(panel);
   }
   bool SetText(CLabel &control, const string text)
   { if(control.Text() == text) return false; return control.Text(text); }
   bool SetText(CButton &control, const string text)
   { if(control.Text() == text) return false; return control.Text(text); }
   bool Edit(CEdit &edit, const long chart, const string name, const int subwin, const string text,
             const int x1, const int y1, const int x2, const int y2)
   { return edit.Create(chart, name, subwin, x1, y1, x2, y2) && edit.ReadOnly(false) && edit.Text(text) && Add(edit); }
   bool SetText(CEdit &control, const string text)
   { if(control.Text() == text) return false; return control.Text(text); }
   bool SetText(CCheckBox &control, const string text)
   { if(control.Text() == text) return false; return control.Text(text); }
   bool Label(CLabel &label, const long chart, const string name, const string text,
              const int x1, const int y1, const int x2, const int y2)
   { return label.Create(chart, name, 0, x1, y1, x2, y2) && label.Text(text) && Add(label); }
};
#endif
