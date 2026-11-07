#ifndef MY_FIBO_CHART_MQH
#define MY_FIBO_CHART_MQH
#include <Fibo\Fibonacci.mqh>
#include "MyFiboAuto.mqh"

// Presentation only: chart objects/geometry, no pivot or Fibonacci calculation.
class CMyFiboChart
{
private:
   string m_prefix;
   string m_keys[];
   bool m_changed;
   bool Label(const int slot, const string name, const datetime time, const double price,
              const string text, const string tooltip, const int anchor)
   {
      string key = IntegerToString((long)time) + "," + StringFormat("%.17g", price)
                   + "," + text + "," + tooltip + "," + IntegerToString(anchor);
      bool exists = ObjectFind(0, name) >= 0;
      if(exists && m_keys[slot] == key) return true;
      m_changed = true;
      if(!exists)
      { if(!ObjectCreate(0, name, OBJ_TEXT, 0, time, price)) return false; }
      else if(!ObjectMove(0, name, 0, time, price)) return false;
      if(!ObjectSetString(0, name, OBJPROP_TEXT, text)
         || !ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip)
         || !ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack)
         || !ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8)
         || !ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor)
         // Background plane keeps annotations behind the native dialog.
         // ZORDER controls mouse priority, not visual stacking.
         || !ObjectSetInteger(0, name, OBJPROP_BACK, true)
         || !ObjectSetInteger(0, name, OBJPROP_ZORDER, 0)
         || !ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false)
         || !ObjectSetInteger(0, name, OBJPROP_HIDDEN, true)) return false;
      m_keys[slot] = key;
      return true;
   }
   bool RemoveLabel(const int slot, const string name)
   {
      if(ObjectFind(0, name) >= 0)
      { m_changed = true; if(!ObjectDelete(0, name)) return false; }
      m_keys[slot] = ""; return true;
   }
   bool ConfigureFiboLevels(const string name, const CFibonacci &fibo)
   {
      if(!ObjectSetInteger(0, name, OBJPROP_LEVELS, fibo.LevelCount())
         || !ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack))
         return false;
      for(int i = 0; i < fibo.LevelCount(); i++)
      {
         double ratio = fibo.LevelRatio(i);
         double price = fibo.LevelPrice(i);
         if(ratio == EMPTY_VALUE || price == EMPTY_VALUE)
            return false;
         string label = DoubleToString(ratio * 100.0, 1)
                        + "%  " + DoubleToString(price, _Digits);
         if(!ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, ratio)
            || !ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, i, clrBlack)
            || !ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, i, STYLE_SOLID)
            || !ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, i, 1)
            || !ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, label))
            return false;
      }
      return true;
   }


public:
   CMyFiboChart(void) { m_prefix = "myFibo."; ResetCache(); }
   void ResetCache(void)
   {
      ArrayResize(m_keys, 50);
      for(int i = 0; i < 50; i++) m_keys[i] = "";
   }
   void ClearStructure(void) { ObjectsDeleteAll(0, m_prefix + "Structure."); ResetCache(); }
   bool DrawFibo(const CFibonacci &fibo, const datetime start_time, const double start_price,
                 const datetime end_time, const double end_price, const bool locked)
   {
      string name = m_prefix + "Swing.Fibo";
      bool existed = ObjectFind(0, name) >= 0;
      ResetLastError();
      // Keep click order: anchor 0 is the swing start (100%), anchor 1 the end (0%).
      if(existed)
      {
         if(!ObjectMove(0, name, 0, start_time, start_price)
            || !ObjectMove(0, name, 1, end_time, end_price)) return false;
      }
      else if(!ObjectCreate(0, name, OBJ_FIBO, 0,
                            start_time, start_price, end_time, end_price))
         return false;
      bool ok = ConfigureFiboLevels(name, fibo)
                && ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID)
                && ObjectSetInteger(0, name, OBJPROP_WIDTH, 1)
                && ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false)
                && ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true)
                && ObjectSetInteger(0, name, OBJPROP_BACK, true)
                && ObjectSetInteger(0, name, OBJPROP_ZORDER, 0)
                // Allow native selection, anchor dragging, and Properties editing.
                && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !locked)
                && ObjectSetInteger(0, name, OBJPROP_HIDDEN, false)
                && ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      if(!ok)
      {
         Print("myFibo: could not configure OBJ_FIBO, error ", GetLastError());
         if(!existed) ObjectDelete(0, name);
      }
      ChartRedraw(); return ok;
   }
   bool LockFibo(const bool locked)
   {
      string name = m_prefix + "Swing.Fibo";
      if(ObjectFind(0, name) < 0) return true;
      bool ok = ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !locked);
      if(locked) ok = ObjectSetInteger(0, name, OBJPROP_SELECTED, false) && ok;
      ChartRedraw(); return ok;
   }
   bool HasFibo(void) const { return ObjectFind(0, m_prefix + "Swing.Fibo") >= 0; }
   void ClearFibo(void) { ObjectsDeleteAll(0, m_prefix + "Swing"); }
   void ClearStart(void) { ObjectDelete(0, m_prefix + "Start"); }
   void ClearAll(void) { ObjectsDeleteAll(0, m_prefix); ResetCache(); }
   bool MarkStart(const datetime time, const double price)
   {
      string name = m_prefix + "Start";
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price)) return false;
      bool ok = ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159)
                && ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack)
                && ObjectSetInteger(0, name, OBJPROP_BACK, true)
                && ObjectSetInteger(0, name, OBJPROP_ZORDER, 0)
                && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      if(!ok) ObjectDelete(0, name);
      return ok;
   }
   bool UpdateLevels(const CFibonacci &fibo) { return ConfigureFiboLevels(m_prefix + "Swing.Fibo", fibo); }
   bool ReadFibo(datetime &start_time, double &start_price, datetime &end_time, double &end_price)
   {
      long first = 0, last = 0;
      if(!ObjectGetInteger(0, m_prefix + "Swing.Fibo", OBJPROP_TIME, 0, first)
         || !ObjectGetInteger(0, m_prefix + "Swing.Fibo", OBJPROP_TIME, 1, last)
         || !ObjectGetDouble(0, m_prefix + "Swing.Fibo", OBJPROP_PRICE, 0, start_price)
         || !ObjectGetDouble(0, m_prefix + "Swing.Fibo", OBJPROP_PRICE, 1, end_price)
         || first <= 0 || last <= 0) return false;
      start_time = (datetime)first; end_time = (datetime)last; return true;
   }
   bool DrawStructure(const CMyFiboAuto &model)
   {
      m_changed = false;
      bool ok = true; int count = model.StructureCount(), slot = 0;
      int first = count > 30 ? count - 30 : 0;
      for(int i = first; i < count; i++, slot++)
      {
         StructurePoint point; if(!model.GetStructurePoint(i, point)) return false;
         if(!Label(slot, m_prefix + "Structure." + IntegerToString(slot), point.swing.time,
                   point.swing.price, StructureLabelName(point.label), "",
                   point.swing.type == SWING_HIGH ? ANCHOR_LOWER : ANCHOR_UPPER)) ok = false;
      }
      for(int i = slot; i < 30; i++)
         if(!RemoveLabel(i, m_prefix + "Structure." + IntegerToString(i))) ok = false;
      count = model.BreakCount(); first = count > 20 ? count - 20 : 0; slot = 0;
      for(int i = first; i < count; i++, slot++)
      {
         StructureBreak event; if(!model.GetBreak(i, event)) return false;
         if(!Label(30 + slot, m_prefix + "Structure.Break." + IntegerToString(slot), event.time,
                   event.close_price, StructureBreakName(event.kind) + " " + StructureTrendName(event.direction),
                   "Swing acuan: " + DoubleToString(event.reference.price, _Digits),
                   event.direction == STRUCTURE_BULLISH ? ANCHOR_LOWER : ANCHOR_UPPER)) ok = false;
      }
      for(int i = slot; i < 20; i++)
         if(!RemoveLabel(30 + i, m_prefix + "Structure.Break." + IntegerToString(i))) ok = false;
      if(m_changed) ChartRedraw();
      return ok;
   }
   bool PickCandle(const int x, const int y, datetime &bar_time, double &price)
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


};
#endif // MY_FIBO_CHART_MQH
