#property strict
#property version "1.20"
#property description "Draw Fibonacci levels by selecting two candle extremes."

#include "..\..\Include\Fibo\Fibonacci.mqh"

input color InpLevelColor = clrDodgerBlue;
input color InpSwingColor = clrOrange;

enum SelectionState { IDLE, SELECT_START, SELECT_END };
SelectionState g_state = IDLE;
CFibonacci g_fibo;
string g_prefix = "EA1.";
datetime g_start_time;
double g_start_price;
int g_panel_x = 12;
int g_panel_y = 24;
bool g_dragging = false;
bool g_left_down = false;
int g_drag_offset_x = 0;
int g_drag_offset_y = 0;
ulong g_ignore_click_until = 0;
bool g_saved_mouse_move = false;
bool g_saved_mouse_scroll = true;
bool g_selection_locked = false;

void LockSelection(void)
{
   if(g_selection_locked)
      return;
   g_saved_mouse_scroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   g_selection_locked = true;
}

void UnlockSelection(void)
{
   if(!g_selection_locked)
      return;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, g_saved_mouse_scroll);
   g_selection_locked = false;
}

bool InPanel(const int x, const int y)
{
   return x >= g_panel_x && x <= g_panel_x + 580
          && y >= g_panel_y && y <= g_panel_y + 146;
}

void MovePanel(const int x, const int y)
{
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int max_x = chart_width > 580 ? chart_width - 580 : 0;
   int max_y = chart_height > 146 ? chart_height - 146 : 0;
   g_panel_x = x < 0 ? 0 : (x > max_x ? max_x : x);
   g_panel_y = y < 0 ? 0 : (y > max_y ? max_y : y);
   string names[] = {"Panel", "Title", "Button", "Reset", "Status", "Status2"};
   int offsets_x[] = {0, 12, 12, 182, 12, 12};
   int offsets_y[] = {0, 10, 36, 36, 76, 98};
   for(int i = 0; i < ArraySize(names); i++)
   {
      ObjectSetInteger(0, g_prefix + names[i], OBJPROP_XDISTANCE,
                       g_panel_x + offsets_x[i]);
      ObjectSetInteger(0, g_prefix + names[i], OBJPROP_YDISTANCE,
                       g_panel_y + offsets_y[i]);
   }
   ChartRedraw();
}

void EndPanelDrag(void)
{
   if(!g_dragging)
      return;
   g_dragging = false;
   g_ignore_click_until = GetTickCount64() + 250;
   if(g_state == IDLE)
      UnlockSelection();
}

void HandlePanelMouse(const int x, const int y, const string flags)
{
   bool down = (StringToInteger(flags) & 1) != 0;
   if(down && !g_left_down && InPanel(x, y) && y < g_panel_y + 32)
   {
      g_dragging = true;
      g_drag_offset_x = x - g_panel_x;
      g_drag_offset_y = y - g_panel_y;
      LockSelection();
   }
   if(g_dragging)
   {
      if(down)
         MovePanel(x - g_drag_offset_x, y - g_drag_offset_y);
      else
         EndPanelDrag();
   }
   g_left_down = down;
}

bool PanelObject(const string suffix, const ENUM_OBJECT type,
                 const int x, const int y, const int width, const int height,
                 const string text, const color foreground, const color background)
{
   string name = g_prefix + suffix;
   if(!ObjectCreate(0, name, type, 0, 0, 0))
      return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_COLOR, foreground);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrSlateGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, type == OBJ_BUTTON ? 20 : 10);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

bool SetInteger(const string name, const ENUM_OBJECT_PROPERTY_INTEGER property,
                const long value)
{
   return ObjectSetInteger(0, name, property, value);
}

void SetStatus(const string message)
{
   int split = -1;
   if(StringLen(message) > 70)
      for(int i = 0; i < 70; i++)
         if(StringSubstr(message, i, 1) == " ")
            split = i;
   ObjectSetString(0, g_prefix + "Status", OBJPROP_TEXT,
                   split < 0 ? message : StringSubstr(message, 0, split));
   ObjectSetString(0, g_prefix + "Status2", OBJPROP_TEXT,
                   split < 0 ? "" : StringSubstr(message, split + 1));
   ObjectSetString(0, g_prefix + "Button", OBJPROP_TEXT,
                   g_state == IDLE ? "Draw Fibonacci" : "Cancel drawing");
   SetInteger(g_prefix + "Button", OBJPROP_STATE, false);
   ChartRedraw();
}

void CancelSelection(void)
{
   g_state = IDLE;
   if(!g_dragging)
      UnlockSelection();
   ObjectDelete(0, g_prefix + "Start");
   SetStatus("Click Draw Fibonacci to select a swing.");
}

int OnInit(void)
{
   // A chart runs one EA. Remove only objects owned by this EA on reinitialization.
   ObjectsDeleteAll(0, g_prefix);
   g_saved_mouse_move = (bool)ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   if(!PanelObject("Panel", OBJ_RECTANGLE_LABEL, 12, 24, 580, 146,
                   "", clrSlateGray, clrDarkSlateGray)
      || !PanelObject("Title", OBJ_LABEL, 24, 34, 0, 0,
                      "EA1 | Fibonacci drawing | drag header to move", clrWhite, clrDarkSlateGray)
      || !PanelObject("Button", OBJ_BUTTON, 24, 60, 160, 28,
                      "Draw Fibonacci", clrWhite, clrTeal)
      || !PanelObject("Reset", OBJ_BUTTON, 194, 60, 120, 28,
                      "Reset", clrWhite, clrMaroon)
      || !PanelObject("Status", OBJ_LABEL, 24, 100, 0, 0,
                      "", clrOrange, clrDarkSlateGray)
      || !PanelObject("Status2", OBJ_LABEL, 24, 122, 0, 0,
                      "", clrOrange, clrDarkSlateGray))
   {
      ObjectsDeleteAll(0, g_prefix);
      return INIT_FAILED;
   }
   MovePanel(g_panel_x, g_panel_y);
   CancelSelection();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_dragging = false;
   UnlockSelection();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, g_saved_mouse_move);
   ObjectsDeleteAll(0, g_prefix);
   ChartRedraw();
}

bool CandleAnchor(const int x, const int y, datetime &bar_time, double &price)
{
   int window = 0;
   datetime clicked_time;
   double clicked_price;
   if(!ChartXYToTimePrice(0, x, y, window, clicked_time, clicked_price)
      || window != 0)
      return false;
   // Time conversion can fall just before the candle open. Compare the
   // actual screen centers instead of flooring time to the previous candle.
   int seed = iBarShift(_Symbol, _Period, clicked_time, false);
   if(seed < 0)
      return false;
   int shift = -1;
   double best_distance = DBL_MAX;
   int total = Bars(_Symbol, _Period);
   int first = seed > 2 ? seed - 2 : 0;
   int last = seed + 2 < total ? seed + 2 : total - 1;
   for(int candidate = first; candidate <= last; candidate++)
   {
      int candle_x, candle_y;
      datetime candidate_time = iTime(_Symbol, _Period, candidate);
      if(candidate_time == 0
         || !ChartTimePriceToXY(0, 0, candidate_time, clicked_price,
                               candle_x, candle_y))
         continue;
      double distance = MathAbs((double)x - candle_x);
      if(distance < best_distance)
      {
         best_distance = distance;
         shift = candidate;
      }
   }
   if(shift < 0)
      return false;
   // Reject future/empty space rather than snapping it onto the last bar.
   int center_x, center_y, neighbor_x, neighbor_y;
   int neighbor = shift == 0 ? 1 : shift - 1;
   if(neighbor >= total
      || !ChartTimePriceToXY(0, 0, iTime(_Symbol, _Period, shift),
                            clicked_price, center_x, center_y)
      || !ChartTimePriceToXY(0, 0, iTime(_Symbol, _Period, neighbor),
                            clicked_price, neighbor_x, neighbor_y)
      || best_distance > MathMax(1.0, MathAbs((double)neighbor_x - center_x) / 2.0))
      return false;
   MqlRates candle[1];
   if(CopyRates(_Symbol, _Period, shift, 1, candle) != 1)
      return false;
   bar_time = candle[0].time;
   // A midpoint tie chooses the high, including a candle with no range.
   price = MathAbs(clicked_price - candle[0].high)
           <= MathAbs(clicked_price - candle[0].low)
           ? candle[0].high : candle[0].low;
   return true;
}

bool DrawSwing(const datetime end_time, const double end_price)
{
   if(!g_fibo.SetAnchors(g_start_price, end_price))
      return false;
   ObjectsDeleteAll(0, g_prefix + "Swing");
   string group = g_prefix + "Swing.";
   datetime left = g_start_time < end_time ? g_start_time : end_time;
   datetime right = g_start_time > end_time ? g_start_time : end_time;
   // Give same-candle swings nonzero horizontal width for their levels.
   if(left == right)
      right = left + PeriodSeconds(_Period);
   bool ok = ObjectCreate(0, group + "Anchor", OBJ_TREND, 0,
                          g_start_time, g_start_price, end_time, end_price);
   SetInteger(group + "Anchor", OBJPROP_COLOR, InpSwingColor);
   SetInteger(group + "Anchor", OBJPROP_RAY_RIGHT, false);
   SetInteger(group + "Anchor", OBJPROP_SELECTABLE, false);
   for(int i = 0; i < g_fibo.LevelCount(); i++)
   {
      double price = g_fibo.LevelPrice(i);
      string name = group + IntegerToString(i);
      if(price == EMPTY_VALUE
         || !ObjectCreate(0, name, OBJ_TREND, 0, left, price, right, price))
      {
         ok = false;
         break;
      }
      SetInteger(name, OBJPROP_COLOR, InpLevelColor);
      SetInteger(name, OBJPROP_RAY_RIGHT, true);
      SetInteger(name, OBJPROP_SELECTABLE, false);
      string label = DoubleToString(g_fibo.LevelRatio(i) * 100.0, 1)
                     + "%  " + DoubleToString(price, _Digits);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, label);
      if(!ObjectCreate(0, name + "Label", OBJ_TEXT, 0, right, price))
      {
         ok = false;
         break;
      }
      ObjectSetString(0, name + "Label", OBJPROP_TEXT, label);
      SetInteger(name + "Label", OBJPROP_COLOR, InpLevelColor);
      SetInteger(name + "Label", OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      SetInteger(name + "Label", OBJPROP_FONTSIZE, 9);
      SetInteger(name + "Label", OBJPROP_SELECTABLE, false);
   }
   if(!ok)
      ObjectsDeleteAll(0, group);
   return ok;
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      HandlePanelMouse((int)lparam, (int)dparam, sparam);
      return;
   }
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      MovePanel(g_panel_x, g_panel_y);
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_prefix + "Button")
   {
      if(g_state != IDLE)
         CancelSelection();
      else
      {
         ObjectsDeleteAll(0, g_prefix + "Swing");
         ObjectDelete(0, g_prefix + "Start");
         LockSelection();
         g_state = SELECT_START;
         SetStatus("Select swing start: click near a candle high or low. Esc cancels.");
      }
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_prefix + "Reset")
   {
      CancelSelection();
      ObjectsDeleteAll(0, g_prefix + "Swing");
      SetInteger(g_prefix + "Reset", OBJPROP_STATE, false);
      SetStatus("Drawings cleared. Click Draw Fibonacci to select a swing.");
      return;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 27)
   {
      EndPanelDrag();
      CancelSelection();
      return;
   }
   if(id != CHARTEVENT_CLICK || g_state == IDLE)
      return;
   int x = (int)lparam;
   int y = (int)dparam;
   // Object clicks can also generate chart clicks. Never use the UI as an anchor.
   if(g_dragging || GetTickCount64() < g_ignore_click_until || InPanel(x, y))
      return;
   datetime bar_time;
   double price;
   if(!CandleAnchor(x, y, bar_time, price))
   {
      SetStatus("Click a candle in the main price chart.");
      return;
   }
   if(g_state == SELECT_START)
   {
      g_start_time = bar_time;
      g_start_price = price;
      if(!ObjectCreate(0, g_prefix + "Start", OBJ_ARROW, 0, bar_time, price))
      {
         SetStatus("Could not mark start. Select the start again.");
         return;
      }
      SetInteger(g_prefix + "Start", OBJPROP_ARROWCODE, 159);
      SetInteger(g_prefix + "Start", OBJPROP_COLOR, InpSwingColor);
      SetInteger(g_prefix + "Start", OBJPROP_SELECTABLE, false);
      g_state = SELECT_END;
      SetStatus("Start: " + TimeToString(bar_time, TIME_DATE | TIME_MINUTES)
                + " @ " + DoubleToString(price, _Digits)
                + ". Select swing end near a candle high or low.");
      return;
   }
   if(price == g_start_price)
   {
      SetStatus("End must have a different price. Select swing end again.");
      return;
   }
   if(!DrawSwing(bar_time, price))
   {
      SetStatus("Drawing failed. Select swing end again; see Experts log.");
      Print("EA1 drawing error: ", GetLastError());
      return;
   }
   CancelSelection();
   SetStatus("Fibonacci drawn. Click Draw Fibonacci to replace this swing.");
}
