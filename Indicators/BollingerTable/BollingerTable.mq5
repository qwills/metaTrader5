#property copyright "will_santoso"
#property version   "1.00"
#property description "Bollinger Bands with a closed-bar multi-timeframe middle-band table."
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3
#property indicator_label1 "Middle BB"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_label2 "Upper BB"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrSilver
#property indicator_label3 "Lower BB"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrSilver

#include "BollingerSignal.mqh"

input int                InpPeriod       = 20;          // BB period
input double             InpDeviation    = 2.0;         // Standard deviations
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // BB applied price
input int                InpTableX       = 12;          // Table left offset (pixels)
input int                InpTableY       = 28;          // Table top offset (pixels)
input int                InpFontSize     = 10;          // Table font size (8..16)

double MiddleBuffer[], UpperBuffer[], LowerBuffer[];
int ChartHandle = INVALID_HANDLE;
int TableHandles[9];
ENUM_TIMEFRAMES Timeframes[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                               PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
string TimeframeNames[9] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
string Prefix = "";

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
   ok = ObjectSetInteger(0, background, OBJPROP_YSIZE, row_height * 11 + 12) && ok;
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
   if(!CreateLabel("Title", "BB | closed candle", left, top) ||
      !CreateLabel("TF", "TF", left, top + row_height) ||
      !CreateLabel("Middle", "Middle BB", value_x, top + row_height))
      return false;
   for(int i = 0; i < 9; i++)
   {
      int y = top + (i + 2) * row_height;
      if(!CreateLabel("TF" + IntegerToString(i), TimeframeNames[i], left, y) ||
         !CreateLabel("Value" + IntegerToString(i), "Loading...", value_x, y))
         return false;
   }
   return true;
}

bool ValidBandValue(const double value)
{
   return MathIsValidNumber(value) && value != EMPTY_VALUE;
}

void RefreshTable()
{
   for(int i = 0; i < 9; i++)
   {
      string name = Prefix + "Value" + IntegerToString(i);
      string text = "Loading...";
      color text_color = clrSilver;
      MqlRates rates[2];
      double middle[2];
      // Static arrays are chronological: [0] is shift 2, [1] is shift 1.
      // Check bar identity around the copies to avoid mixing rollover snapshots.
      datetime open_time = iTime(_Symbol, Timeframes[i], 0);
      if(open_time > 0 &&
         BarsCalculated(TableHandles[i]) >= InpPeriod + 2 &&
         CopyRates(_Symbol, Timeframes[i], 1, 2, rates) == 2 &&
         CopyBuffer(TableHandles[i], 0, 1, 2, middle) == 2 &&
         SeriesInfoInteger(_Symbol, Timeframes[i], SERIES_SYNCHRONIZED) &&
         open_time == iTime(_Symbol, Timeframes[i], 0) &&
         rates[1].time == iTime(_Symbol, Timeframes[i], 1) &&
         rates[0].time == iTime(_Symbol, Timeframes[i], 2) &&
         ValidBandValue(middle[0]) && ValidBandValue(middle[1]))
      {
         text = DoubleToString(middle[1], _Digits);
         text_color = SignalColor(BollingerSignal(rates[0].close, middle[0],
                                                 rates[1].close, middle[1]));
      }
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   }
   ChartRedraw(0);
}

int OnInit()
{
   ArrayInitialize(TableHandles, INVALID_HANDLE);
   if(InpPeriod < 2 || !MathIsValidNumber(InpDeviation) || InpDeviation <= 0 ||
      InpTableX < 0 || InpTableY < 0 || InpFontSize < 8 || InpFontSize > 16)
      return INIT_PARAMETERS_INCORRECT;

   if(!SetIndexBuffer(0, MiddleBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(1, UpperBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA))
      return INIT_FAILED;
   ArraySetAsSeries(MiddleBuffer, false);
   ArraySetAsSeries(UpperBuffer, false);
   ArraySetAsSeries(LowerBuffer, false);
   for(int i = 0; i < 3; i++)
      PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod - 1);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,
                      "BollingerTable (" + IntegerToString(InpPeriod) + ", " +
                      DoubleToString(InpDeviation, 2) + ")");

   ChartHandle = iBands(_Symbol, _Period, InpPeriod, 0, InpDeviation, InpAppliedPrice);
   if(ChartHandle == INVALID_HANDLE)
      return INIT_FAILED;
   for(int i = 0; i < 9; i++)
   {
      TableHandles[i] = iBands(_Symbol, Timeframes[i], InpPeriod, 0,
                              InpDeviation, InpAppliedPrice);
      if(TableHandles[i] == INVALID_HANDLE)
         return INIT_FAILED;
   }
   Prefix = "BBT_" + IntegerToString(ChartID()) + "_" +
            IntegerToString((long)GetMicrosecondCount()) + "_";
   if(!CreateTable() || !EventSetTimer(1))
      return INIT_FAILED;
   RefreshTable();
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
      return 0;
   int count = rates_total;
   if(prev_calculated > 0 && prev_calculated <= rates_total)
      count = rates_total - prev_calculated + 1;
   double middle[], upper[], lower[];
   if(CopyBuffer(ChartHandle, 0, 0, count, middle) != count ||
      CopyBuffer(ChartHandle, 1, 0, count, upper) != count ||
      CopyBuffer(ChartHandle, 2, 0, count, lower) != count)
      return 0;
   int start = rates_total - count;
   for(int i = 0; i < count; i++)
   {
      MiddleBuffer[start + i] = middle[i];
      UpperBuffer[start + i] = upper[i];
      LowerBuffer[start + i] = lower[i];
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
      ObjectsDeleteAll(0, Prefix);
   if(ChartHandle != INVALID_HANDLE)
      IndicatorRelease(ChartHandle);
   for(int i = 0; i < 9; i++)
      if(TableHandles[i] != INVALID_HANDLE)
         IndicatorRelease(TableHandles[i]);
   ChartRedraw(0);
}
