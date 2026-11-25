#property copyright "will_santoso"
#property version   "1.04"
#property description "Bollinger Bands with a current-candle multi-timeframe middle-band table."
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3
#property indicator_label1 "Middle BB"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_label2 "Upper BB"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_label3 "Lower BB"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrGreen

#include "BollingerSignal.mqh"

input int                InpPeriod       = 20;          // BB period
input double             InpDeviation    = 2.0;         // Standard deviations
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // BB applied price
input color              InpUpperColor   = clrRed;      // Upper BB line color
input color              InpMiddleColor  = clrDodgerBlue;// Middle BB line color
input color              InpLowerColor   = clrGreen;    // Lower BB line color
input int                InpTableX       = 12;          // Table left offset (pixels)
input int                InpTableY       = 28;          // Table top offset (pixels)
input int                InpFontSize     = 10;          // Table font size (8..16)
input bool               InpShowM1       = false;       // Show M1
input bool               InpShowM5       = false;       // Show M5
input bool               InpShowM15      = true;        // Show M15
input bool               InpShowM30      = true;        // Show M30
input bool               InpShowH1       = true;        // Show H1
input bool               InpShowH4       = true;        // Show H4
input bool               InpShowD1       = false;       // Show D1
input bool               InpShowW1       = false;       // Show W1
input bool               InpShowMN1      = false;       // Show MN1

double MiddleBuffer[], UpperBuffer[], LowerBuffer[];
int ChartHandle = INVALID_HANDLE;
int TableHandles[9];
ENUM_TIMEFRAMES Timeframes[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                               PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
string TimeframeNames[9] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
string Prefix = "";
string DisplayedText[9];
color DisplayedColor[9];
string LastValidText[9];
color LastValidColor[9];
string DisplayedTooltip[9];
bool TimeframeEnabled[9];
int SelectedCount = 0;
// Reuse copy storage across ticks; normal updates need only one or two bars.
double CopyMiddle[], CopyUpper[], CopyLower[];
string TableKey = "";

// The key intentionally excludes the chart timeframe. A matching pending table
// belongs to the same configuration after MT5 unloads/reloads the indicator.
string TableSettingsKey()
{
   string key = "BBT103|" + IntegerToString(InpPeriod) + "|" +
                DoubleToString(InpDeviation, 16) + "|" + IntegerToString(InpAppliedPrice) + "|" +
                IntegerToString(InpTableX) + "|" + IntegerToString(InpTableY) + "|" +
                IntegerToString(InpFontSize) + "|" + IntegerToString(InpUpperColor) + "|" +
                IntegerToString(InpMiddleColor) + "|" + IntegerToString(InpLowerColor) + "|";
   for(int i = 0; i < 9; i++)
      key += TimeframeEnabled[i] ? "1" : "0";
   return key + "|";
}

bool RestoreTable()
{
   // Objects survive indicator reloads. Claim one pending matching instance;
   // never reuse integer indicator handles across unload/reload boundaries.
   string pending_key = "pending|" + TableKey;
   int count = ObjectsTotal(0, 0, -1);
   for(int n = 0; n < count; n++)
   {
      string name = ObjectName(0, n, 0, -1);
      int length = StringLen(name);
      if(StringFind(name, "BBT_") != 0 || length < 5 ||
         StringSubstr(name, length - 5) != "State")
         continue;
      string marker = ObjectGetString(0, name, OBJPROP_TEXT);
      if(StringFind(marker, pending_key) != 0)
         continue;
      Prefix = StringSubstr(name, 0, length - 5);
      bool valid = marker == pending_key + _Symbol;
      for(int i = 0; i < 9 && valid; i++)
      {
         if(!TimeframeEnabled[i])
            continue;
         string value_name = Prefix + "Value" + IntegerToString(i);
         valid = ObjectFind(0, value_name) >= 0 &&
                 ObjectFind(0, Prefix + "TF" + IntegerToString(i)) >= 0;
         if(valid)
         {
            DisplayedText[i] = ObjectGetString(0, value_name, OBJPROP_TEXT);
            DisplayedColor[i] = (color)ObjectGetInteger(0, value_name, OBJPROP_COLOR);
            DisplayedTooltip[i] = ObjectGetString(0, value_name, OBJPROP_TOOLTIP);
            if(DisplayedText[i] != "" && DisplayedText[i] != "Loading...")
            {
               LastValidText[i] = DisplayedText[i];
               LastValidColor[i] = DisplayedColor[i];
            }
            else
               LastValidText[i] = "";
         }
      }
      valid = valid && ObjectFind(0, Prefix + "Title") >= 0 &&
              ObjectFind(0, Prefix + "TF") >= 0 && ObjectFind(0, Prefix + "Middle") >= 0 &&
              ObjectFind(0, Prefix + "Background") >= 0;
      if(valid && ObjectSetString(0, name, OBJPROP_TEXT, "active|" + TableKey + _Symbol))
         return true;
      // A symbol change shares REASON_CHARTCHANGE: discard its old values.
      ObjectsDeleteAll(0, Prefix);
      Prefix = "";
      return false;
   }
   return false;
}

void ConfigureTimeframes()
{
   TimeframeEnabled[0] = InpShowM1;
   TimeframeEnabled[1] = InpShowM5;
   TimeframeEnabled[2] = InpShowM15;
   TimeframeEnabled[3] = InpShowM30;
   TimeframeEnabled[4] = InpShowH1;
   TimeframeEnabled[5] = InpShowH4;
   TimeframeEnabled[6] = InpShowD1;
   TimeframeEnabled[7] = InpShowW1;
   TimeframeEnabled[8] = InpShowMN1;
   SelectedCount = 0;
   for(int i = 0; i < 9; i++)
      if(TimeframeEnabled[i])
         SelectedCount++;
}

color SignalColor(const ENUM_BB_SIGNAL signal)
{
   switch(signal)
   {
      case BB_ABOVE:        return clrLimeGreen;
      case BB_BELOW:        return clrRed;
      case BB_GOLDEN_CROSS: return clrDodgerBlue;
      case BB_DEAD_CROSS:   return clrOrange;
      default:             return clrSilver;
   }
}

bool CreateLabel(const string suffix, const string text, const int x, const int y)
{
   string name = Prefix + suffix;
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return false;
   bool ok = ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ok = ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_HIDDEN, true) && ok;
   ok = ObjectSetString(0, name, OBJPROP_FONT, "Consolas") && ok;
   ok = ObjectSetString(0, name, OBJPROP_TEXT, text) && ok;
   return ok;
}

bool CreateTable()
{
   int row_height = InpFontSize * 2 + 4;
   int width = InpFontSize * 22;
   string background = Prefix + "Background";
   if(!ObjectCreate(0, background, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return false;
   bool ok = ObjectSetInteger(0, background, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ok = ObjectSetInteger(0, background, OBJPROP_XDISTANCE, InpTableX) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_YDISTANCE, InpTableY) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_XSIZE, width) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_YSIZE, row_height * (SelectedCount + 2) + 12) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_BGCOLOR, C'24,28,34') && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_BORDER_TYPE, BORDER_FLAT) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_COLOR, clrDimGray) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_SELECTABLE, false) && ok;
   ok = ObjectSetInteger(0, background, OBJPROP_HIDDEN, true) && ok;
   if(!ok)
      return false;
   int left = InpTableX + 10;
   int value_x = left + InpFontSize * 6;
   int top = InpTableY + 6;
   if(!CreateLabel("Title", "BB", left, top) ||
      !CreateLabel("TF", "TF", left, top + row_height) ||
      !CreateLabel("Middle", "Middle BB", value_x, top + row_height))
      return false;
   int row = 0;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i])
         continue;
      int y = top + (row + 2) * row_height;
      if(!CreateLabel("TF" + IntegerToString(i), TimeframeNames[i], left, y) ||
         !CreateLabel("Value" + IntegerToString(i), "Loading...", value_x, y))
         return false;
      DisplayedText[i] = "Loading...";
      DisplayedColor[i] = clrWhite;
      LastValidText[i] = "";
      DisplayedTooltip[i] = "";
      row++;
   }
   // Keep handoff metadata off the chart and out of visible tooltips.
   string state = Prefix + "State";
   if(!CreateLabel("State", "", 0, 0) ||
      !ObjectSetInteger(0, state, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS))
      return false;
   return ObjectSetString(0, state, OBJPROP_TEXT, "active|" + TableKey + _Symbol);
}

bool ValidBandValue(const double value)
{
   return MathIsValidNumber(value) && value != EMPTY_VALUE;
}

void RefreshTable()
{
   bool changed = false;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i])
         continue;
      string name = Prefix + "Value" + IntegerToString(i);
      // A temporary read failure must not erase a valid restored/live value.
      // LastValid is independent of successful chart-command submission.
      bool has_cached_value = LastValidText[i] != "";
      string text = has_cached_value ? LastValidText[i] : "Loading...";
      color text_color = has_cached_value ? LastValidColor[i] : clrSilver;
      string tooltip = has_cached_value ? "Last valid value; waiting for fresh data" :
                                         "Waiting for initial data";
      MqlRates rates[2];
      double middle[2];
      // Static arrays are chronological: [0] is shift 1, [1] is current bar.
      // Check bar identity around the copies to avoid mixing rollover snapshots.
      datetime open_time = (datetime)SeriesInfoInteger(_Symbol, Timeframes[i], SERIES_LASTBAR_DATE);
      if(open_time > 0 &&
         BarsCalculated(TableHandles[i]) >= InpPeriod + 1 &&
         CopyRates(_Symbol, Timeframes[i], 0, 2, rates) == 2 &&
         CopyBuffer(TableHandles[i], 0, 0, 2, middle) == 2 &&
         SeriesInfoInteger(_Symbol, Timeframes[i], SERIES_SYNCHRONIZED) &&
         open_time == (datetime)SeriesInfoInteger(_Symbol, Timeframes[i], SERIES_LASTBAR_DATE) &&
         rates[1].time == open_time && rates[0].time < rates[1].time &&
         ValidBandValue(middle[0]) && ValidBandValue(middle[1]))
      {
         text = DoubleToString(middle[1], _Digits);
         text_color = SignalColor(BollingerSignal(rates[0].close, middle[0],
                                                 rates[1].close, middle[1]));
         LastValidText[i] = text;
         LastValidColor[i] = text_color;
         tooltip = "Live middle BB (current candle)";
      }
      // Avoid queuing chart commands when the displayed value/color is unchanged.
      if(text != DisplayedText[i] && ObjectSetString(0, name, OBJPROP_TEXT, text))
      {
         DisplayedText[i] = text;
         changed = true;
      }
      if(text_color != DisplayedColor[i] && ObjectSetInteger(0, name, OBJPROP_COLOR, text_color))
      {
         DisplayedColor[i] = text_color;
         changed = true;
      }
      if(tooltip != DisplayedTooltip[i] && ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip))
      {
         DisplayedTooltip[i] = tooltip;
         changed = true;
      }
   }
   if(changed)
      ChartRedraw(0);
}

int OnInit()
{
   ArrayInitialize(TableHandles, INVALID_HANDLE);
   ConfigureTimeframes();
   TableKey = TableSettingsKey();
   if(InpPeriod < 2 || !MathIsValidNumber(InpDeviation) || InpDeviation <= 0 ||
      InpTableX < 0 || InpTableY < 0 || InpFontSize < 8 || InpFontSize > 16)
      return INIT_PARAMETERS_INCORRECT;

   // Claim retained objects before any operation that could fail initialization,
   // so REASON_INITFAILED also cleans up a previously retained table.
   bool restored = SelectedCount > 0 && RestoreTable();
   if(!SetIndexBuffer(0, MiddleBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(1, UpperBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA))
      return INIT_FAILED;
   ArraySetAsSeries(MiddleBuffer, false);
   ArraySetAsSeries(UpperBuffer, false);
   ArraySetAsSeries(LowerBuffer, false);
   for(int i = 0; i < 3; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod - 1);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpMiddleColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpUpperColor);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpLowerColor);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,
                      "BollingerTable (" + IntegerToString(InpPeriod) + ", " +
                      DoubleToString(InpDeviation, 2) + ")");

   ChartHandle = iBands(_Symbol, _Period, InpPeriod, 0, InpDeviation, InpAppliedPrice);
   if(ChartHandle == INVALID_HANDLE)
      return INIT_FAILED;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i])
         continue;
      // The chart timeframe already has an identical BB handle.
      if(Timeframes[i] == _Period)
         TableHandles[i] = ChartHandle;
      else
         TableHandles[i] = iBands(_Symbol, Timeframes[i], InpPeriod, 0,
                                 InpDeviation, InpAppliedPrice);
      if(TableHandles[i] == INVALID_HANDLE)
         return INIT_FAILED;
   }
   if(SelectedCount > 0)
   {
      if(!restored)
      {
         Prefix = "BBT_" + IntegerToString(ChartID()) + "_" +
                  IntegerToString((long)GetMicrosecondCount()) + "_";
         if(!CreateTable())
            return INIT_FAILED;
      }
      if(!EventSetTimer(1))
         return INIT_FAILED;
      // A TF switch does not force another table read or clear its last values.
      // The normal timer will pick up live prices independently of chart TF.
      if(!restored)
         RefreshTable();
   }
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(prev_calculated == 0)
   {
      ArrayInitialize(MiddleBuffer, EMPTY_VALUE);
      ArrayInitialize(UpperBuffer, EMPTY_VALUE);
      ArrayInitialize(LowerBuffer, EMPTY_VALUE);
   }
   if(rates_total < InpPeriod || BarsCalculated(ChartHandle) < rates_total)
      return prev_calculated;
   int count = rates_total;
   if(prev_calculated > 0 && prev_calculated <= rates_total)
      count = rates_total - prev_calculated + 1;
   if(CopyBuffer(ChartHandle, 0, 0, count, CopyMiddle) != count ||
      CopyBuffer(ChartHandle, 1, 0, count, CopyUpper) != count ||
      CopyBuffer(ChartHandle, 2, 0, count, CopyLower) != count)
      return prev_calculated;
   int start = rates_total - count;
   for(int i = 0; i < count; i++)
   {
      MiddleBuffer[start + i] = CopyMiddle[i];
      UpperBuffer[start + i] = CopyUpper[i];
      LowerBuffer[start + i] = CopyLower[i];
   }
   return rates_total;
}

void OnTimer()
{
   RefreshTable();
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(Prefix != "")
   {
      bool retained = reason == REASON_CHARTCHANGE &&
                      ObjectSetString(0, Prefix + "State", OBJPROP_TEXT,
                                      "pending|" + TableKey + _Symbol);
      if(!retained)
         ObjectsDeleteAll(0, Prefix);
   }
   if(ChartHandle != INVALID_HANDLE)
      IndicatorRelease(ChartHandle);
   for(int i = 0; i < 9; i++)
      if(TableHandles[i] != INVALID_HANDLE && TableHandles[i] != ChartHandle)
         IndicatorRelease(TableHandles[i]);
   ChartRedraw(0);
}
