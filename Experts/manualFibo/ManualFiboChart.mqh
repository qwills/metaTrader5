#ifndef MANUAL_FIBO_CHART_MQH
#define MANUAL_FIBO_CHART_MQH
#include "ManualFiboModel.mqh"

// Object presentation and candle geometry only. No swing detection or trading.
class CManualFiboChart
{
public:
   string Name(void) const { return "manualFibo.Swing.Fibo"; }
   bool HasFibo(void) const { return ObjectFind(0, Name()) >= 0; }
   bool Draw(const CManualFiboModel &model)
   {
      if(!model.Ready()) return false;
      bool existed = HasFibo();
      if(existed)
      {
         if(!ObjectMove(0, Name(), 0, model.StartTime(), model.StartPrice())
            || !ObjectMove(0, Name(), 1, model.EndTime(), model.EndPrice())) return false;
      }
      else if(!ObjectCreate(0, Name(), OBJ_FIBO, 0, model.StartTime(), model.StartPrice(),
                            model.EndTime(), model.EndPrice())) return false;
      bool ok = Configure(model);
      if(!ok && !existed) ClearFibo();
      return ok;
   }
   bool Configure(const CManualFiboModel &model)
   {
      if(!HasFibo()) return false;
      int count = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) if(model.Enabled(i)) count++;
      // With no checked ratio hide the drawing, retaining editable model anchors.
      bool ok = ObjectSetInteger(0, Name(), OBJPROP_TIMEFRAMES, count == 0 ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS)
                && ObjectSetInteger(0, Name(), OBJPROP_LEVELS, count)
                && ObjectSetInteger(0, Name(), OBJPROP_COLOR, clrBlack)
                && ObjectSetInteger(0, Name(), OBJPROP_STYLE, STYLE_SOLID)
                && ObjectSetInteger(0, Name(), OBJPROP_WIDTH, 1)
                && ObjectSetInteger(0, Name(), OBJPROP_RAY_LEFT, false)
                && ObjectSetInteger(0, Name(), OBJPROP_RAY_RIGHT, true)
                && ObjectSetInteger(0, Name(), OBJPROP_BACK, true)
                && ObjectSetInteger(0, Name(), OBJPROP_ZORDER, 0)
                && ObjectSetInteger(0, Name(), OBJPROP_HIDDEN, false)
                && Lock(model.Locked());
      int slot = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS && ok; i++)
      {
         if(!model.Enabled(i)) continue;
         double ratio = ManualFiboRatio(i), price = model.Price(i);
         if(price == EMPTY_VALUE) return false;
         ok = ObjectSetDouble(0, Name(), OBJPROP_LEVELVALUE, slot, ratio)
              && ObjectSetInteger(0, Name(), OBJPROP_LEVELCOLOR, slot, clrBlack)
              && ObjectSetInteger(0, Name(), OBJPROP_LEVELSTYLE, slot, STYLE_SOLID)
              && ObjectSetInteger(0, Name(), OBJPROP_LEVELWIDTH, slot, 1)
              && ObjectSetString(0, Name(), OBJPROP_LEVELTEXT, slot,
                                DoubleToString(ratio * 100.0, 1) + "%  " + DoubleToString(price, _Digits));
         slot++;
      }
      return ok;
   }
   bool Lock(const bool locked)
   {
      if(!HasFibo()) return true;
      return ObjectSetInteger(0, Name(), OBJPROP_SELECTABLE, !locked)
             && (!locked || ObjectSetInteger(0, Name(), OBJPROP_SELECTED, false));
   }
   bool Read(CManualFiboModel &model)
   {
      long first = 0, last = 0;
      double start = 0, end = 0;
      return ObjectGetInteger(0, Name(), OBJPROP_TIME, 0, first)
             && ObjectGetInteger(0, Name(), OBJPROP_TIME, 1, last)
             && ObjectGetDouble(0, Name(), OBJPROP_PRICE, 0, start)
             && ObjectGetDouble(0, Name(), OBJPROP_PRICE, 1, end)
             && model.SetAnchors((datetime)first, start, (datetime)last, end);
   }
   void ClearFibo(void) { ObjectDelete(0, Name()); }
   void ClearStart(void) { ObjectDelete(0, "manualFibo.Start"); }
   void ClearAll(void) { ObjectsDeleteAll(0, "manualFibo."); }
   bool MarkStart(const datetime time, const double price)
   {
      ClearStart();
      string name = "manualFibo.Start";
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price)) return false;
      bool ok = ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159)
                && ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack)
                && ObjectSetInteger(0, name, OBJPROP_BACK, true)
                && ObjectSetInteger(0, name, OBJPROP_ZORDER, 0)
                && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      if(!ok) ClearStart();
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
#endif
