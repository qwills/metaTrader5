#ifndef MANUAL_FIBO_DIALOG_MQH
#define MANUAL_FIBO_DIALOG_MQH
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\CheckBox.mqh>
#include <Controls\Panel.mqh>
#include "ManualFiboModel.mqh"

enum ManualFiboAction { MANUAL_NONE, MANUAL_DRAW, MANUAL_RESET, MANUAL_LEVELS, MANUAL_LOCK };

class CManualFiboDialog : public CAppDialog
{
private:
   CPanel m_swing_group, m_fibo_group, m_swing_caption_bg, m_fibo_caption_bg;
   CButton m_draw, m_reset;
   CLabel m_swing_title, m_start, m_end, m_fibo_title, m_status;
   CCheckBox m_levels[MANUAL_FIBO_RATIOS];
   CCheckBox m_lock;
   ManualFiboAction m_action;
public:
   CManualFiboDialog(void) { m_action = MANUAL_NONE; }
   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      m_action = MANUAL_NONE;
      if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2) || !Caption("manualFibo")) return false;
      // Register decorative frames first so native controls are created above them.
      if(!Group(m_swing_group, chart, name + ".SwingGroup", subwin, 6, 14, 374, 128)
         || !Group(m_fibo_group, chart, name + ".FiboGroup", subwin, 6, 142, 374, 316)) return false;
      if(!GroupTitle(m_swing_caption_bg, m_swing_title, chart, name + ".SwingTitle", "Swing", 20, 4, 64)
         || !GroupTitle(m_fibo_caption_bg, m_fibo_title, chart, name + ".FiboTitle", "Fibonacci", 20, 132, 96)
         || !m_draw.Create(chart, name + ".Draw", subwin, 14, 34, 180, 62)
         || !m_draw.Text("Pilih Swing") || !Add(m_draw)
         || !m_reset.Create(chart, name + ".Reset", subwin, 194, 34, 300, 62)
         || !m_reset.Text("Reset") || !Add(m_reset)
         || !Label(m_start, chart, name + ".Start", "Awal: -", 14, 74, 360, 94)
         || !Label(m_end, chart, name + ".End", "Akhir: -", 14, 100, 360, 120)) return false;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
      {
         int top = 160 + i * 26;
         if(!m_levels[i].Create(chart, name + ".Level" + IntegerToString(i), subwin, 14, top, 360, top + 22)
            || !m_levels[i].Text(DoubleToString(ManualFiboRatio(i) * 100.0, 1) + "%: -")
            || !m_levels[i].Checked((MANUAL_FIBO_DEFAULT_MASK & (1 << i)) != 0)
            || !Add(m_levels[i])) return false;
      }
      return m_lock.Create(chart, name + ".Lock", subwin, 14, 324, 360, 348)
             && m_lock.Text("Kunci anchor") && m_lock.Checked(false) && Add(m_lock)
             && Label(m_status, chart, name + ".Status", "Klik Pilih Swing.", 14, 360, 365, 382);
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
      return CAppDialog::OnEvent(id, lparam, dparam, sparam);
   }
   ManualFiboAction TakeAction(void)
   { ManualFiboAction action = m_action; m_action = MANUAL_NONE; return action; }
   int RatioMask(void)
   {
      int mask = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) if(m_levels[i].Checked()) mask |= 1 << i;
      return mask;
   }
   bool AnchorLocked(void) { return m_lock.Checked(); }
   void Refresh(const CManualFiboModel &model)
   {
      SetText(m_start, model.Ready() ? "Awal: " + DoubleToString(model.StartPrice(), _Digits) : "Awal: -");
      SetText(m_end, model.Ready() ? "Akhir: " + DoubleToString(model.EndPrice(), _Digits) : "Akhir: -");
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
      {
         if(m_levels[i].Checked() != model.Enabled(i)) m_levels[i].Checked(model.Enabled(i));
         SetText(m_levels[i], DoubleToString(ManualFiboRatio(i) * 100.0, 1) + "%: "
                 + (model.Ready() ? DoubleToString(model.Price(i), _Digits) : "-"));
      }
      if(m_lock.Checked() != model.Locked()) m_lock.Checked(model.Locked());
   }
   void SetStatus(const string text, const bool selecting)
   { SetText(m_status, text); SetText(m_draw, selecting ? "Batal" : "Pilih Swing"); ChartRedraw(m_chart_id); }
   virtual string IniFileName(void) const { return "manualFibo_" + IntegerToString(ChartID()) + "_GUI_v3"; }
   bool Dragging(void) const { return m_drag_object != NULL; }
   void CancelDrag(void) { if(Dragging()) CDialog::OnDialogDragEnd(); MouseFocusKill(); }
protected:
   bool GroupTitle(CPanel &background, CLabel &label, const long chart, const string name,
                   const string text, const int x, const int y, const int width)
   {
      // A small dialog-colored backing breaks the frame's top edge behind its title.
      return background.Create(chart, name + ".Background", 0, x - 6, y, x + width, y + 20)
             && background.BorderType(BORDER_FLAT)
             && background.ColorBackground(CONTROLS_DIALOG_COLOR_BG)
             && background.ColorBorder(CONTROLS_DIALOG_COLOR_BG) && Add(background)
             && Label(label, chart, name, text, x, y, x + width, y + 20);
   }
   bool Group(CPanel &panel, const long chart, const string name, const int subwin,
              const int x1, const int y1, const int x2, const int y2)
   {
      return panel.Create(chart, name, subwin, x1, y1, x2, y2)
             && panel.BorderType(BORDER_FLAT)
             && panel.ColorBackground(CONTROLS_DIALOG_COLOR_BG)
             && panel.ColorBorder(clrSilver) && Add(panel);
   }
   void SetText(CLabel &control, const string text) { if(control.Text() != text) control.Text(text); }
   void SetText(CButton &control, const string text) { if(control.Text() != text) control.Text(text); }
   void SetText(CCheckBox &control, const string text) { if(control.Text() != text) control.Text(text); }
   bool Label(CLabel &label, const long chart, const string name, const string text,
              const int x1, const int y1, const int x2, const int y2)
   { return label.Create(chart, name, 0, x1, y1, x2, y2) && label.Text(text) && Add(label); }
};
#endif
