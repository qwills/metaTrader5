#ifndef MY_FIBO_DIALOG_MQH
#define MY_FIBO_DIALOG_MQH

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\ComboBox.mqh>
#include <Controls\CheckBox.mqh>
#include <Controls\SpinEdit.mqh>
#include "MyFiboTypes.mqh"

enum MyFiboPanelAction { PANEL_NONE, PANEL_DRAW, PANEL_RESET, PANEL_SETTINGS, PANEL_LOCK };

// Refresh the edit text even when the stored value has not changed.
// Standard CSpinEdit may recreate an empty edit while retaining its value.
class CMyFiboSpinEdit : public CSpinEdit
{
public:
   void SetDisplayedValue(const int value)
   {
      if(Value() != value) Value(value);
      else OnChangeValue();
   }
};

class CMyFiboDialog : public CAppDialog
{
private:
   CComboBox m_mode;
   CLabel m_timeframe;
   CComboBox m_auto_method;
   CLabel m_auto_method_label;
   CMyFiboSpinEdit m_left;
   CMyFiboSpinEdit m_right;
   CCheckBox m_lock;
   CLabel m_mode_label, m_tf_label, m_method, m_left_label, m_right_label;
   CLabel m_swing_title, m_fibo_title, m_start, m_end, m_direction, m_origin;
   CLabel m_level50, m_level618, m_level786, m_status, m_status2;
   CButton m_draw, m_reset;
   MyFiboPanelAction m_action;
   int m_auto_offset;
   bool m_selecting;
   string m_message;

public:
   CMyFiboDialog(void)
   {
      m_action = PANEL_NONE;
      m_auto_offset = 0;
      m_selecting = false;
      m_message = "";
   }

   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      m_action = PANEL_NONE;
      m_auto_offset = 0;
      m_selecting = false;
      m_message = "";
      if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2) || !Caption("myFibo"))
         return false;
      if(!Label(m_mode_label, chart, name + ".ModeLabel", "Mode", 20, 10, 75, 34)
         || !Label(m_tf_label, chart, name + ".TFLabel", "TF", 300, 10, 345, 34)
         || !m_mode.Create(chart, name + ".Mode", subwin, 80, 10, 235, 34)
         || !m_mode.AddItem("Manual", FIBO_MANUAL) || !m_mode.AddItem("Auto", FIBO_AUTO)
         || !Add(m_mode)
         || !Label(m_timeframe, chart, name + ".Timeframe", "Chart: " + MyFiboTimeframeName(_Period), 350, 10, 550, 34))
         return false;
      m_mode.SelectByValue(FIBO_MANUAL);
      m_mode.ListViewItems(2);
      if(!Label(m_auto_method_label, chart, name + ".AutoMethodLabel", "Metode", 20, 44, 95, 64)
         || !m_auto_method.Create(chart, name + ".AutoMethod", subwin, 100, 44, 310, 68)
         || !m_auto_method.AddItem("Pivot", FIBO_PIVOT)
         || !m_auto_method.AddItem("Market Structure", FIBO_MARKET_STRUCTURE)
         || !Add(m_auto_method)
         || !Label(m_method, chart, name + ".Method", "Struktur: Belum jelas", 320, 44, 550, 64)
         || !Label(m_left_label, chart, name + ".LeftLabel", "Candle kiri", 20, 76, 125, 98)
         || !Label(m_right_label, chart, name + ".RightLabel", "Candle kanan", 265, 76, 385, 98)
         || !m_left.Create(chart, name + ".Left", subwin, 130, 76, 210, 98)
         || !m_right.Create(chart, name + ".Right", subwin, 390, 76, 470, 98))
         return false;
      m_auto_method.SelectByValue(FIBO_PIVOT);
      m_auto_method.ListViewItems(2);
      m_left.MinValue(1); m_left.MaxValue(20); m_left.SetDisplayedValue(2);
      m_right.MinValue(1); m_right.MaxValue(20); m_right.SetDisplayedValue(2);
      if(!Add(m_left) || !Add(m_right)
         || !Label(m_swing_title, chart, name + ".SwingTitle", "Swing", 20, 44, 540, 64)
         || !m_draw.Create(chart, name + ".Draw", subwin, 20, 76, 180, 104)
         || !m_draw.Text("Pilih Swing") || !Add(m_draw)
         || !m_reset.Create(chart, name + ".Reset", subwin, 190, 76, 290, 104)
         || !m_reset.Text("Reset") || !Add(m_reset)
         || !Label(m_start, chart, name + ".Start", "Awal : -", 20, 114, 540, 134)
         || !Label(m_end, chart, name + ".End", "Akhir : -", 20, 140, 540, 160)
         || !Label(m_direction, chart, name + ".Direction", "Arah : -", 20, 166, 240, 186)
         || !Label(m_origin, chart, name + ".Origin", "Sumber: -", 245, 166, 550, 186)
         || !Label(m_fibo_title, chart, name + ".FiboTitle", "Fibonacci", 20, 202, 540, 222)
         || !Label(m_level50, chart, name + ".Level50", "50.0% : -", 20, 228, 540, 248)
         || !Label(m_level618, chart, name + ".Level618", "61.8% : -", 20, 254, 540, 274)
         || !Label(m_level786, chart, name + ".Level786", "78.6% : -", 20, 280, 540, 300)
         || !m_lock.Create(chart, name + ".Lock", subwin, 20, 318, 300, 342)
         || !m_lock.Text("Kunci anchor") || !m_lock.Checked(false) || !Add(m_lock)
         || !Label(m_status, chart, name + ".Status", "", 10, 356, 560, 376)
         || !Label(m_status2, chart, name + ".Status2", "", 10, 378, 560, 398))
         return false;
      AutoVisibility();
      return true;
   }

   virtual bool OnEvent(const int id, const long &lparam,
                        const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CUSTOM + ON_CLICK)
      {
         if(lparam == m_draw.Id()) { m_action = PANEL_DRAW; return true; }
         if(lparam == m_reset.Id()) { m_action = PANEL_RESET; return true; }
      }
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE)
      {
         if(lparam == m_lock.Id()) { m_action = PANEL_LOCK; return true; }
         if(lparam == m_mode.Id() || lparam == m_auto_method.Id()
            || lparam == m_left.Id() || lparam == m_right.Id())
         { m_action = PANEL_SETTINGS; return true; }
      }
      bool minimized = m_minimized;
      bool handled = CAppDialog::OnEvent(id, lparam, dparam, sparam);
      if(minimized != m_minimized)
         AutoVisibility();
      return handled;
   }

   MyFiboPanelAction TakeAction(void)
   {
      MyFiboPanelAction action = m_action;
      m_action = PANEL_NONE;
      return action;
   }

   // Some terminal library versions expose non-const Value/Checked getters.
   MyFiboMode Mode(void) { return (MyFiboMode)m_mode.Value(); }
   MyFiboAutoMethod AutoMethod(void) { return (MyFiboAutoMethod)m_auto_method.Value(); }
   int LeftBars(void) { return m_left.Value(); }
   int RightBars(void) { return m_right.Value(); }
   bool AnchorLocked(void) { return m_lock.Checked(); }

   void SetSettings(const MyFiboMode mode, const ENUM_TIMEFRAMES timeframe,
                    const int left, const int right, const bool locked,
                    const MyFiboAutoMethod method = FIBO_PIVOT)
   {
      if(m_auto_method.Value() != method) m_auto_method.SelectByValue(method);
      if(m_mode.Value() != mode) m_mode.SelectByValue(mode);
      string tf_text = "Chart: " + MyFiboTimeframeName(timeframe);
      if(m_timeframe.Text() != tf_text) m_timeframe.Text(tf_text);
      m_left.SetDisplayedValue(left);
      m_right.SetDisplayedValue(right);
      if(m_lock.Checked() != locked) m_lock.Checked(locked);
      int offset = mode == FIBO_AUTO ? 84 : 0;
      int delta = offset - m_auto_offset;
      if(delta != 0)
      {
         m_swing_title.Shift(0, delta); m_draw.Shift(0, delta); m_reset.Shift(0, delta);
         m_start.Shift(0, delta); m_end.Shift(0, delta); m_direction.Shift(0, delta); m_origin.Shift(0, delta);
         m_fibo_title.Shift(0, delta); m_level50.Shift(0, delta);
         m_level618.Shift(0, delta); m_level786.Shift(0, delta);
         m_lock.Shift(0, delta); m_status.Shift(0, delta); m_status2.Shift(0, delta);
         m_auto_offset = offset;
         m_norm_rect.bottom = m_norm_rect.top + 440 + offset;
         if(!m_minimized)
         {
            Height(440 + offset);
            m_norm_rect.SetBound(m_rect);
         }
      }
      AutoVisibility();
      ButtonCaption();
   }

   void SetStructureTrend(const string trend)
   {
      string text = "Struktur: " + trend;
      if(m_method.Text() != text) m_method.Text(text);
   }

   void SetStatus(const string message, const bool selecting)
   {
      m_selecting = selecting;
      if(m_message != message)
      {
         int split = -1;
         if(StringLen(message) > 70)
            for(int i = 0; i < 70; i++)
               if(StringSubstr(message, i, 1) == " ") split = i;
         m_status.Text(split < 0 ? message : StringSubstr(message, 0, split));
         m_status2.Text(split < 0 ? "" : StringSubstr(message, split + 1));
         m_message = message;
      }
      ButtonCaption();
      ChartRedraw(m_chart_id);
   }

   void ClearSwing(void)
   {
      m_start.Text("Awal : -"); m_end.Text("Akhir : -"); m_direction.Text("Arah : -"); m_origin.Text("Sumber: -");
      m_level50.Text("50.0% : -"); m_level618.Text("61.8% : -"); m_level786.Text("78.6% : -");
   }
   void SetSwingStart(const double price) { m_start.Text("Awal : " + DoubleToString(price, _Digits)); }
   void SetSwingEnd(const double price) { m_end.Text("Akhir : " + DoubleToString(price, _Digits)); }
   void SetAnchorSource(const string source) { m_origin.Text("Sumber: " + source); }
   void SetDirection(const bool upward) { m_direction.Text(upward ? "Arah : Naik" : "Arah : Turun"); }
   void SetLevels(const double a, const double b, const double c)
   {
      m_level50.Text("50.0% : " + DoubleToString(a, _Digits));
      m_level618.Text("61.8% : " + DoubleToString(b, _Digits));
      m_level786.Text("78.6% : " + DoubleToString(c, _Digits));
   }
   virtual string IniFileName(void) const
   {
      return "myFibo_" + IntegerToString(ChartID()) + "_GUI_v6";
   }
   bool Dragging(void) const { return m_drag_object != NULL; }
   void CancelDrag(void)
   {
      if(Dragging()) CDialog::OnDialogDragEnd();
      MouseFocusKill();
   }

protected:
   bool Label(CLabel &label, const long chart, const string name, const string text,
              const int x1, const int y1, const int x2, const int y2)
   {
      return label.Create(chart, name, 0, x1, y1, x2, y2) && label.Text(text) && Add(label);
   }
   void AutoVisibility(void)
   {
      bool visible = Mode() == FIBO_AUTO && !m_minimized;
      m_auto_method.Visible(visible); m_auto_method_label.Visible(visible);
      m_method.Visible(visible); m_left_label.Visible(visible); m_right_label.Visible(visible);
      m_left.Visible(visible); m_right.Visible(visible);
   }
   void ButtonCaption(void)
   {
      string text = m_selecting ? "Batal" : (Mode() == FIBO_AUTO ? "Cari Swing" : "Pilih Swing");
      if(m_draw.Text() != text) m_draw.Text(text);
   }
};

#endif // MY_FIBO_DIALOG_MQH
