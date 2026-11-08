#ifndef AUTO_FIBO_DIALOG_MQH
#define AUTO_FIBO_DIALOG_MQH
#include <Fibo\FiboDialog.mqh>
#include <Controls\ComboBox.mqh>
#include <Controls\SpinEdit.mqh>
#include "AutoFiboTypes.mqh"

class CAutoFiboSpinEdit : public CSpinEdit
{
public:
   void SetDisplayedValue(const int value) { if(Value() != value) Value(value); else OnChangeValue(); }
};

class CAutoFiboDialog : public CFiboDialog
{
private:
   CPanel m_analysis_frame[5];
   CComboBox m_method;
   CAutoFiboSpinEdit m_left, m_right;
   CLabel m_analysis_title, m_method_label, m_left_label, m_right_label, m_structure_label, m_anchor_source_label, m_status2;
   bool m_settings_changed;
public:
   virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2)
   {
      Configure("AutoFibo", 100, "Cari Swing"); m_settings_changed = false;
      if(!CFiboDialog::Create(chart, name, subwin, x1, y1, x2, y2)) return false;
      // Analysis controls use native client coordinates above the shared content.
      if(!Group(m_analysis_frame, chart, name + ".AnalysisGroup", subwin, 6, 14, 596, 96, 14, 160, false)
         || !AnalysisLabel(m_analysis_title, chart, name + ".AnalysisTitle", "Swing Otomatis", 20, 4, 154, 24)
         || !AnalysisLabel(m_method_label, chart, name + ".MethodLabel", "Metode", 14, 34, 74, 54)
         || !m_method.Create(chart, name + ".Method", subwin, 80, 28, 280, 54)
         || !m_method.AddItem("Pivot", FIBO_PIVOT) || !m_method.AddItem("Market Structure", FIBO_MARKET_STRUCTURE)
         || !Add(m_method)
         || !AnalysisLabel(m_left_label, chart, name + ".LeftLabel", "Candle kiri", 14, 66, 96, 86)
         || !AnalysisLabel(m_right_label, chart, name + ".RightLabel", "Candle kanan", 194, 66, 276, 86)
         || !m_left.Create(chart, name + ".Left", subwin, 100, 60, 170, 84)
         || !m_right.Create(chart, name + ".Right", subwin, 280, 60, 350, 84)) return false;
      m_method.ListViewItems(2); m_method.SelectByValue(FIBO_PIVOT);
      m_left.MinValue(1); m_left.MaxValue(20); m_left.SetDisplayedValue(2);
      m_right.MinValue(1); m_right.MaxValue(20); m_right.SetDisplayedValue(2);
      return Add(m_left) && Add(m_right)
             && AnalysisLabel(m_anchor_source_label, chart, name + ".Source", "Sumber: -", 300, 34, 584, 54)
             && AnalysisLabel(m_structure_label, chart, name + ".Trend", "Struktur: Belum jelas", 374, 66, 584, 86)
             && AnalysisLabel(m_status2, chart, name + ".Status2", "", 14, 546, 584, 568);
   }
   // CAppDialog's chart-resize branch can minimize a tall main-chart EA panel.
   // Keep its explicit minimize button behavior, without losing child notifications.
   void DispatchEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CHART_CHANGE && !IsMinimized())
      {
         long chart_height = ChartGetInteger(m_chart_id, CHART_HEIGHT_IN_PIXELS, 0);
         if(chart_height <= 0 || chart_height < Height() + CONTROLS_BORDER_WIDTH)
         {
            if(CDialog::OnEvent(id, lparam, dparam, sparam)) ChartRedraw(m_chart_id);
            SubwinOff();
            return;
         }
      }
      ChartEvent(id, lparam, dparam, sparam);
   }
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE
         && (lparam == m_method.Id() || lparam == m_left.Id() || lparam == m_right.Id()))
      { m_settings_changed = true; return true; }
      return CFiboDialog::OnEvent(id, lparam, dparam, sparam);
   }
   bool TakeSettingsChange(void) { bool changed = m_settings_changed; m_settings_changed = false; return changed; }
   AutoFiboMethod Method(void) { return (AutoFiboMethod)m_method.Value(); }
   int LeftBars(void) { return m_left.Value(); }
   int RightBars(void) { return m_right.Value(); }
   void SetSettings(const AutoFiboMethod method, const int left, const int right)
   {
      if(m_method.Value() != method) m_method.SelectByValue(method);
      m_left.SetDisplayedValue(left); m_right.SetDisplayedValue(right);
   }
   void SetStructureTrend(const string trend) { SetText(m_structure_label, "Struktur: " + trend); }
   void SetAnchorSource(const string source) { SetText(m_anchor_source_label, "Sumber: " + source); }
   void Status(const string message)
   {
      int split = -1;
      if(StringLen(message) > 70)
         for(int i = 0; i < 70; i++) if(StringSubstr(message, i, 1) == " ") split = i;
      bool changed = SetText(m_status2, split < 0 ? "" : StringSubstr(message, split + 1));
      SetStatus(split < 0 ? message : StringSubstr(message, 0, split), false);
      if(changed) ChartRedraw();
   }
protected:
   bool AnalysisLabel(CLabel &label, const long chart, const string name, const string text,
                      const int x1, const int y1, const int x2, const int y2)
   { return Label(label, chart, name, text, x1, y1, x2, y2, false); }
public:
   virtual string IniFileName(void) const { return "AutoFibo_" + IntegerToString(ChartID()) + "_GUI_v1"; }
};
#endif
