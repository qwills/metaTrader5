#ifndef FIBO_DIALOG_MQH
#define FIBO_DIALOG_MQH
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\CheckBox.mqh>
#include <Controls\Panel.mqh>
#include <Controls\Edit.mqh>
#include "FiboRisk.mqh"

enum FiboAction { FIBO_PANEL_NONE, FIBO_PANEL_DRAW, FIBO_PANEL_RESET, FIBO_PANEL_LEVELS, FIBO_PANEL_LOCK, FIBO_PANEL_RISK, FIBO_PANEL_SL };

class CFiboDialog : public CAppDialog
{
private:
   CPanel m_swing_frame[5], m_risk_frame[5], m_fibo_frame[5];
   CButton m_draw, m_reset;
   CLabel m_swing_title, m_start, m_end, m_fibo_title, m_status;
   CCheckBox m_levels[FIBO_RATIOS];
   CCheckBox m_lock;
   CEdit m_risk_edit, m_stops[FIBO_RATIOS];
   CLabel m_risk_title, m_risk_label, m_budget, m_risk_note;
   CLabel m_entry_header, m_sl_header, m_lot_header, m_loss_header;
   CLabel m_lots[FIBO_RATIOS], m_losses[FIBO_RATIOS];
   string m_app_name, m_draw_caption;
   int m_content_offset;
   string m_control_prefix, m_tooltips[FIBO_RATIOS];
   int m_edit_index;
   FiboAction m_action;
public:
   CFiboDialog(void)
   {
      m_action = FIBO_PANEL_NONE; m_total_loss = 0; m_all_lots_valid = false;
      Configure("Fibonacci", 0, "Pilih Swing");
   }
   void Configure(const string app_name, const int offset, const string draw_caption)
   { m_app_name = app_name; m_content_offset = offset; m_draw_caption = draw_caption; }
   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      m_action = FIBO_PANEL_NONE; m_edit_index = -1; m_control_prefix = name;
      for(int i = 0; i < FIBO_RATIOS; i++) m_tooltips[i] = "";
      if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2) || !Caption(m_app_name)) return false;
      // Register decorative frames first so native controls are created above them.
      if(!Group(m_swing_frame, chart, name + ".SwingGroup", subwin, 6, 14, 300, 128, 14, 90)
         || !Group(m_risk_frame, chart, name + ".RiskGroup", subwin, 312, 14, 596, 128, 320, 396)
         || !Group(m_fibo_frame, chart, name + ".FiboGroup", subwin, 6, 142, 596, 374, 14, 122)) return false;
      if(!Label(m_swing_title, chart, name + ".SwingTitle", "Swing", 20, 4, 84, 24)
         || !Label(m_risk_title, chart, name + ".RiskTitle", "Risk", 326, 4, 390, 24)
         || !Label(m_fibo_title, chart, name + ".FiboTitle", "Fibonacci", 20, 132, 116, 152)
         || !m_draw.Create(chart, name + ".Draw", subwin, 14, 34 + m_content_offset, 174, 62 + m_content_offset)
         || !m_draw.Text(m_draw_caption) || !Add(m_draw)
         || !m_reset.Create(chart, name + ".Reset", subwin, 188, 34 + m_content_offset, 288, 62 + m_content_offset)
         || !m_reset.Text("Reset") || !Add(m_reset)
         || !Label(m_start, chart, name + ".Start", "Awal: -", 14, 74, 288, 94)
         || !Label(m_end, chart, name + ".End", "Akhir: -", 14, 100, 288, 120)
         || !Label(m_risk_label, chart, name + ".RiskLabel", "% Equity", 324, 36, 432, 56)
         || !Edit(m_risk_edit, chart, name + ".Risk", subwin, "5", 442, 32 + m_content_offset, 584, 58 + m_content_offset)
         || !Label(m_budget, chart, name + ".Budget", "Budget: -", 324, 68, 584, 88)
         || !Label(m_risk_note, chart, name + ".RiskNote", "Risk per level, bukan total.", 324, 98, 584, 118)
         || !Label(m_entry_header, chart, name + ".EntryHeader", "Level / Entry", 14, 160, 210, 180)
         || !Label(m_sl_header, chart, name + ".SLHeader", "SL price", 224, 160, 350, 180)
         || !Label(m_lot_header, chart, name + ".LotHeader", "Lot", 366, 160, 454, 180)
         || !Label(m_loss_header, chart, name + ".LossHeader", "Est. loss", 470, 160, 584, 180)) return false;
      for(int i = 0; i < FIBO_RATIOS; i++)
      {
         int top = 186 + i * 30 + m_content_offset;
         if(!m_levels[i].Create(chart, name + ".Level" + IntegerToString(i), subwin, 14, top, 210, top + 24)
            || !m_levels[i].Text(DoubleToString(FiboRatio(i) * 100.0, 1) + "%: -")
            || !m_levels[i].Checked((FIBO_DEFAULT_MASK & (1 << i)) != 0)
            || !Add(m_levels[i])
            || !Edit(m_stops[i], chart, name + ".SL" + IntegerToString(i), subwin, "", 224, top, 350, top + 24)
            || !Label(m_lots[i], chart, name + ".Lot" + IntegerToString(i), "-", 366, top + 2 - m_content_offset, 458, top + 24 - m_content_offset)
            || !Label(m_losses[i], chart, name + ".Loss" + IntegerToString(i), "-", 470, top + 2 - m_content_offset, 584, top + 24 - m_content_offset)) return false;
      }
      return m_lock.Create(chart, name + ".Lock", subwin, 14, 386 + m_content_offset, 360, 410 + m_content_offset)
             && m_lock.Text("Kunci anchor") && m_lock.Checked(false) && Add(m_lock)
             && Label(m_status, chart, name + ".Status", "Klik Pilih Swing.", 14, 422, 584, 444);
   }
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK)
      {
         if(lparam == m_draw.Id()) { m_action = FIBO_PANEL_DRAW; return true; }
         if(lparam == m_reset.Id()) { m_action = FIBO_PANEL_RESET; return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE)
      {
         if(lparam == m_lock.Id()) { m_action = FIBO_PANEL_LOCK; return true; }
         for(int i = 0; i < FIBO_RATIOS; i++)
            if(lparam == m_levels[i].Id()) { m_action = FIBO_PANEL_LEVELS; return true; }
      }
      bool handled = CAppDialog::OnEvent(id, lparam, dparam, sparam);
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
      {
         if(sparam == m_control_prefix + ".Risk") { m_action = FIBO_PANEL_RISK; return true; }
         for(int i = 0; i < FIBO_RATIOS; i++)
            if(sparam == m_control_prefix + ".SL" + IntegerToString(i))
            { m_edit_index = i; m_action = FIBO_PANEL_SL; return true; }
      }
      return handled;
   }
   FiboAction TakeAction(void)
   { FiboAction action = m_action; m_action = FIBO_PANEL_NONE; return action; }
   int RatioMask(void)
   {
      int mask = 0;
      for(int i = 0; i < FIBO_RATIOS; i++) if(m_levels[i].Checked()) mask |= 1 << i;
      return mask;
   }
   string RiskText(void) { return m_risk_edit.Text(); }
   int EditIndex(void) const { return m_edit_index; }
   string StopText(const int index) { return m_stops[index].Text(); }
   bool AnchorLocked(void) { return m_lock.Checked(); }
   bool RefreshRiskInput(const CFiboModel &model)
   {
      string percent = DoubleToString(model.RiskPercent(), 8);
      while(StringLen(percent) > 1 && StringSubstr(percent, StringLen(percent) - 1) == "0")
         percent = StringSubstr(percent, 0, StringLen(percent) - 1);
      if(StringSubstr(percent, StringLen(percent) - 1) == ".") percent = StringSubstr(percent, 0, StringLen(percent) - 1);
      return SetText(m_risk_edit, percent);
   }
   bool RefreshStopInput(const CFiboModel &model, const int index)
   {
      if(index < 0 || index >= FIBO_RATIOS) return false;
      double stop = model.StopPrice(index);
      return SetText(m_stops[index], stop == EMPTY_VALUE ? "" : DoubleToString(stop, _Digits));
   }
   void Refresh(const CFiboModel &model, const bool refresh_lots = true)
   {
      SetText(m_start, model.Ready() ? "Awal: " + DoubleToString(model.StartPrice(), _Digits) : "Awal: -");
      SetText(m_end, model.Ready() ? "Akhir: " + DoubleToString(model.EndPrice(), _Digits) : "Akhir: -");
      RefreshRiskInput(model);
      for(int i = 0; i < FIBO_RATIOS; i++)
      {
         RefreshStopInput(model, i);
         if(m_levels[i].Checked() != model.Enabled(i)) m_levels[i].Checked(model.Enabled(i));
         SetText(m_levels[i], DoubleToString(FiboRatio(i) * 100.0, 1) + "%: "
                 + (model.Ready() ? DoubleToString(model.Price(i), _Digits) : "-"));
      }
      if(m_lock.Checked() != model.Locked()) m_lock.Checked(model.Locked());
      if(refresh_lots && !IsMinimized()) RefreshLots(model);
   }
   // Timer updates results only; never overwrite an SL or risk edit in progress.
   virtual bool RefreshLots(const CFiboModel &model)
   {
      CFiboRisk calculator;
      FiboRiskContext context; calculator.ReadContext(model, context);
      string currency = context.currency;
      m_total_loss = 0; m_all_lots_valid = model.Ready() && model.Mask() != 0;
      m_loss_currency = currency;
      bool changed = SetText(m_budget, "Budget: " + DoubleToString(context.budget, 2) + " " + currency);
      for(int i = 0; i < FIBO_RATIOS; i++)
      {
         FiboLot result;
         bool valid = calculator.Calculate(model, i, context, result);
         if(model.Enabled(i))
         {
            if(valid) m_total_loss += result.loss;
            else m_all_lots_valid = false;
         }
         string lot = valid ? DoubleToString(result.volume, context.volume_digits) : result.error;
         if(SetText(m_lots[i], lot)) changed = true;
         if(SetText(m_losses[i], valid ? DoubleToString(result.loss, 2) : "-")) changed = true;
         string tooltip = FiboLimitName(result.kind) + "; " + (valid ? "Entry " + DoubleToString(result.entry, _Digits) + "; SL "
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
      if(SetText(m_draw, selecting ? "Batal" : m_draw_caption)) changed = true;
      if(changed) ChartRedraw(m_chart_id);
   }
   virtual string IniFileName(void) const { return m_app_name + "_" + IntegerToString(ChartID()) + "_GUI_v5"; }
   bool IsMinimized(void) const { return m_minimized; }
   bool Dragging(void) const { return m_drag_object != NULL; }
   void CancelDrag(void) { if(Dragging()) CDialog::OnDialogDragEnd(); MouseFocusKill(); }
protected:
   // Derived dialogs can show a basket estimate without a second broker snapshot.
   double m_total_loss;
   bool m_all_lots_valid;
   string m_loss_currency;
   // Five one-pixel edges leave a real gap for a transparent title label.
   // All pieces belong to the native dialog: no extra mouse or drag driver.
   bool Group(CPanel &edges[], const long chart, const string name, const int subwin,
              const int x1, const int y1, const int x2, const int y2,
              const int gap_start, const int gap_end, const bool apply_offset = true)
   {
      int offset = apply_offset ? m_content_offset : 0;
      return Edge(edges[0], chart, name + ".TopLeft", subwin, x1, y1, gap_start, y1 + 1, offset)
             && Edge(edges[1], chart, name + ".TopRight", subwin, gap_end, y1, x2, y1 + 1, offset)
             && Edge(edges[2], chart, name + ".Left", subwin, x1, y1, x1 + 1, y2, offset)
             && Edge(edges[3], chart, name + ".Right", subwin, x2 - 1, y1, x2, y2, offset)
             && Edge(edges[4], chart, name + ".Bottom", subwin, x1, y2 - 1, x2, y2, offset);
   }
   bool Edge(CPanel &panel, const long chart, const string name, const int subwin,
             const int x1, const int y1, const int x2, const int y2, const int offset)
   {
      return panel.Create(chart, name, subwin, x1, y1 + offset, x2, y2 + offset)
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
              const int x1, const int y1, const int x2, const int y2, const bool apply_offset = true)
   { int offset = apply_offset ? m_content_offset : 0;
     return label.Create(chart, name, 0, x1, y1 + offset, x2, y2 + offset) && label.Text(text) && Add(label); }
};
#endif
