//+------------------------------------------------------------------+
//|                                          RiskRewardShort.mq5     |
//|         Visual short-position risk/reward tool for MetaTrader 5  |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int             StopDistancePoints = 300;          // Initial stop distance (points)
input double          InitialRewardRisk   = 2.0;          // Initial reward/risk
input int             BoxWidthBars        = 15;           // Box width (bars)
input color           ProfitColor         = C'173,216,230';// Reward background: light blue
input color           LossColor           = C'255,182,193';// Risk background: light pink
input color           EntryColor          = clrDodgerBlue;// Entry line
input int             LineWidth           = 1;            // Line width

string PREFIX = "RR_SHORT_";
string ENTRY_LINE, STOP_LINE, TARGET_LINE, PROFIT_BOX, LOSS_BOX;
string ENTRY_TEXT, STOP_TEXT, TARGET_TEXT, RR_TEXT;

double NormalizePrice(const double price)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0.0)
      return NormalizeDouble(MathRound(price / tick) * tick, _Digits);
   return NormalizeDouble(price, _Digits);
}

datetime StartTime()
{
   datetime value = iTime(_Symbol, _Period, 0);
   return(value > 0 ? value : TimeCurrent());
}

datetime EndTime()
{
   int seconds = PeriodSeconds(_Period);
   if(seconds <= 0) seconds = 60;
   return StartTime() + (datetime)(seconds * MathMax(1, BoxWidthBars));
}

bool CreateLine(const string name, const double price, const color line_color,
                const ENUM_LINE_STYLE style)
{
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) return false;
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, LineWidth));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   return true;
}

void SetBox(const string name, const datetime t1, const double p1,
            const datetime t2, const double p2, const color box_color)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   else
   {
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, box_color);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
}

void SetText(const string name, const datetime when, const double price,
             const string value, const color text_color)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, when, price);
   else
      ObjectMove(0, name, 0, when, price);
   ObjectSetString(0, name, OBJPROP_TEXT, value);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void RefreshDrawing()
{
   double entry  = NormalizePrice(ObjectGetDouble(0, ENTRY_LINE, OBJPROP_PRICE));
   double stop   = NormalizePrice(ObjectGetDouble(0, STOP_LINE, OBJPROP_PRICE));
   double target = NormalizePrice(ObjectGetDouble(0, TARGET_LINE, OBJPROP_PRICE));
   ObjectSetDouble(0, ENTRY_LINE, OBJPROP_PRICE, entry);
   ObjectSetDouble(0, STOP_LINE, OBJPROP_PRICE, stop);
   ObjectSetDouble(0, TARGET_LINE, OBJPROP_PRICE, target);

   datetime t1 = StartTime(), t2 = EndTime();
   SetBox(PROFIT_BOX, t1, entry, t2, target, ProfitColor);
   SetBox(LOSS_BOX, t1, entry, t2, stop, LossColor);

   double risk = stop - entry;
   double reward = entry - target;
   double rr = (risk > 0.0 && reward > 0.0 ? reward / risk : 0.0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double risk_distance = MathAbs(stop - entry);
   double reward_distance = MathAbs(entry - target);
   string status = (rr > 0.0 ? StringFormat("R:R 1:%.2f", rr) : "INVALID");
   ObjectDelete(0, TARGET_TEXT);
   ObjectDelete(0, ENTRY_TEXT);
   ObjectDelete(0, STOP_TEXT);
   double rr_offset = MathMax(point * 10.0, (risk_distance + reward_distance) * 0.025);
   datetime middle_time = t1 + (datetime)((t2 - t1) / 2);
   SetText(RR_TEXT, middle_time, entry + rr_offset, status, clrBlack);
   ChartRedraw();
}

int OnInit()
{
   PREFIX += IntegerToString((int)ChartID()) + "_";
   ENTRY_LINE=PREFIX+"Entry"; STOP_LINE=PREFIX+"Stop"; TARGET_LINE=PREFIX+"Target";
   PROFIT_BOX=PREFIX+"ProfitBox"; LOSS_BOX=PREFIX+"LossBox";
   ENTRY_TEXT=PREFIX+"EntryText"; STOP_TEXT=PREFIX+"StopText"; TARGET_TEXT=PREFIX+"TargetText";
   RR_TEXT=PREFIX+"RRText";

   double entry = NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   if(entry <= 0.0) entry = NormalizePrice(iClose(_Symbol, _Period, 0));
   double distance = MathMax(1, StopDistancePoints) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stop = NormalizePrice(entry + distance);
   double target = NormalizePrice(entry - distance * MathMax(0.01, InitialRewardRisk));

   if(!CreateLine(ENTRY_LINE, entry, EntryColor, STYLE_SOLID) ||
      !CreateLine(STOP_LINE, stop, LossColor, STYLE_DASH) ||
      !CreateLine(TARGET_LINE, target, ProfitColor, STYLE_DASH))
      return INIT_FAILED;
   IndicatorSetString(INDICATOR_SHORTNAME, "Risk Reward Short");
   RefreshDrawing();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PREFIX);
   ChartRedraw();
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   return rates_total;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE) &&
      (sparam == ENTRY_LINE || sparam == STOP_LINE || sparam == TARGET_LINE))
      RefreshDrawing();
   else if(id == CHARTEVENT_OBJECT_DRAG && sparam == PROFIT_BOX)
   {
      ObjectSetDouble(0, ENTRY_LINE, OBJPROP_PRICE,
                      ObjectGetDouble(0, PROFIT_BOX, OBJPROP_PRICE, 0));
      ObjectSetDouble(0, TARGET_LINE, OBJPROP_PRICE,
                      ObjectGetDouble(0, PROFIT_BOX, OBJPROP_PRICE, 1));
      RefreshDrawing();
   }
   else if(id == CHARTEVENT_OBJECT_DRAG && sparam == LOSS_BOX)
   {
      ObjectSetDouble(0, ENTRY_LINE, OBJPROP_PRICE,
                      ObjectGetDouble(0, LOSS_BOX, OBJPROP_PRICE, 0));
      ObjectSetDouble(0, STOP_LINE, OBJPROP_PRICE,
                      ObjectGetDouble(0, LOSS_BOX, OBJPROP_PRICE, 1));
      RefreshDrawing();
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
      RefreshDrawing();
}
