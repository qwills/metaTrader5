#ifndef MARKET_STRUCTURE_MQH
#define MARKET_STRUCTURE_MQH

#include <Swing\SwingDetector.mqh>

enum ENUM_STRUCTURE_LABEL { STRUCTURE_H, STRUCTURE_L, STRUCTURE_HH, STRUCTURE_HL,
                            STRUCTURE_LH, STRUCTURE_LL, STRUCTURE_EH, STRUCTURE_EL };
struct StructurePoint
{
   SwingPoint swing;
   ENUM_STRUCTURE_LABEL label;
};

enum ENUM_STRUCTURE_TREND { STRUCTURE_UNCLEAR, STRUCTURE_BULLISH, STRUCTURE_BEARISH };
enum ENUM_STRUCTURE_BREAK { STRUCTURE_BOS, STRUCTURE_CHOCH };
struct StructureBreak
{
   datetime time;                  // Open time of the closed breaking candle.
   double close_price, break_high, break_low;
   ENUM_STRUCTURE_BREAK kind;
   ENUM_STRUCTURE_TREND direction;
   SwingPoint reference;
   SwingPoint origin;             // Confirmed opposing pivot available before BOS.
   datetime origin_confirmed;
   datetime reference_confirmed;   // Open time of its final right-hand candle.
};
// Bounded continuation state, independent of the displayed candle window.
struct StructureCheckpoint
{
   SwingPoint high, low, protected_point;
   bool have_high, have_low, high_broken, low_broken, has_protection;
   int high_relation, low_relation;
   datetime high_confirmed, low_confirmed, protected_confirmed, last_bar, last_pivot;
   double previous_close;
   ENUM_STRUCTURE_TREND trend;
};
void ClearStructureCheckpoint(StructureCheckpoint &state)
{
   state.have_high = false; state.have_low = false;
   state.high_broken = false; state.low_broken = false; state.has_protection = false;
   state.high_relation = 0; state.low_relation = 0;
   state.high_confirmed = 0; state.low_confirmed = 0; state.protected_confirmed = 0;
   state.last_bar = 0; state.last_pivot = 0; state.previous_close = 0;
   state.trend = STRUCTURE_UNCLEAR;
   state.high.time = 0; state.high.price = 0; state.high.type = SWING_HIGH; state.high.confirmed = false;
   state.low = state.high; state.low.type = SWING_LOW;
   state.protected_point = state.high;
}
string StructureTrendName(const ENUM_STRUCTURE_TREND trend)
{
   return trend == STRUCTURE_BULLISH ? "Bullish"
          : (trend == STRUCTURE_BEARISH ? "Bearish" : "Belum jelas");
}
string StructureBreakName(const ENUM_STRUCTURE_BREAK kind)
{
   return kind == STRUCTURE_BOS ? "BOS" : "CHoCH";
}

string StructureLabelName(const ENUM_STRUCTURE_LABEL label)
{
   switch(label)
   {
      case STRUCTURE_H: return "H";
      case STRUCTURE_L: return "L";
      case STRUCTURE_HH: return "HH";
      case STRUCTURE_HL: return "HL";
      case STRUCTURE_LH: return "LH";
      case STRUCTURE_LL: return "LL";
      case STRUCTURE_EH: return "EH";
      case STRUCTURE_EL: return "EL";
   }
   return "?";
}

// Classify confirmed raw pivots against the previous pivot of the SAME type.
// Causal close-confirmed breaks; no trading, chart, symbol or anchor selection.
class CMarketStructure
{
private:
   StructurePoint m_points[];
   StructureBreak m_breaks[];
   StructureCheckpoint m_runtime;

   void ResetBreaks(void)
   {
      ArrayResize(m_breaks, 0);
      ClearStructureCheckpoint(m_runtime);
   }
   void RecordBreak(const int index, const ENUM_STRUCTURE_BREAK kind,
                    const ENUM_STRUCTURE_TREND direction, const MqlRates &bar,
                    const SwingPoint &reference, const datetime confirmed,
                    const SwingPoint &origin, const datetime origin_confirmed)
   {
      m_breaks[index].time = bar.time;
      m_breaks[index].close_price = bar.close;
      m_breaks[index].break_high = bar.high; m_breaks[index].break_low = bar.low;
      m_breaks[index].kind = kind;
      m_breaks[index].direction = direction;
      m_breaks[index].reference = reference;
      m_breaks[index].reference_confirmed = confirmed;
      m_breaks[index].origin = origin;
      m_breaks[index].origin_confirmed = origin_confirmed;
   }

   // Replay in chronological order. Activate a pivot only on the candle AFTER
   // its right-hand confirmation candle, never retrospectively at pivot time.
   bool BuildBreaks(const MqlRates &bars[], const int right)
   {
      int count = ArraySize(bars);
      bool series = ArrayGetAsSeries(bars);
      for(int i = 0; i < count; i++)
      {
         int index = series ? count - 1 - i : i;
         if(!MathIsValidNumber(bars[index].close) || bars[index].close == EMPTY_VALUE
            || bars[index].close < bars[index].low || bars[index].close > bars[index].high)
            return false;
      }
      int retained = BreakCount();
      int confirmations[];
      if(ArrayResize(confirmations, Count()) != Count()
         || ArrayResize(m_breaks, count + retained) != count + retained) return false;
      int cursor = 0;
      for(int p = 0; p < Count(); p++)
      {
         while(cursor < count && bars[series ? count - 1 - cursor : cursor].time < m_points[p].swing.time)
            cursor++;
         if(cursor + right >= count
            || bars[series ? count - 1 - cursor : cursor].time != m_points[p].swing.time)
            return false;
         confirmations[p] = cursor + right;
      }
      int next = 0, found = retained;
      for(int i = 0; i < count; i++)
      {
         MqlRates bar = bars[series ? count - 1 - i : i];
         if(bar.time <= m_runtime.last_bar) continue;
         while(next < Count() && confirmations[next] < i)
         {
            SwingPoint point = m_points[next].swing;
            if(point.time <= m_runtime.last_pivot) { next++; continue; }
            m_runtime.last_pivot = point.time;
            datetime known = bars[series ? count - 1 - confirmations[next] : confirmations[next]].time;
            if(point.type == SWING_HIGH)
            {
               m_runtime.high_relation = !m_runtime.have_high ? 0 : (point.price > m_runtime.high.price ? 1 : (point.price < m_runtime.high.price ? -1 : 0));
               m_runtime.high = point; m_runtime.have_high = true; m_runtime.high_broken = false; m_runtime.high_confirmed = known;
            }
            else
            {
               m_runtime.low_relation = !m_runtime.have_low ? 0 : (point.price > m_runtime.low.price ? 1 : (point.price < m_runtime.low.price ? -1 : 0));
               m_runtime.low = point; m_runtime.have_low = true; m_runtime.low_broken = false; m_runtime.low_confirmed = known;
            }
            if(m_runtime.trend == STRUCTURE_UNCLEAR && m_runtime.high_relation != 0 && m_runtime.high_relation == m_runtime.low_relation
               && !(m_runtime.high_relation > 0 ? m_runtime.low_broken : m_runtime.high_broken))
            {
               m_runtime.trend = m_runtime.high_relation > 0 ? STRUCTURE_BULLISH : STRUCTURE_BEARISH;
               if(m_runtime.trend == STRUCTURE_BULLISH) m_runtime.protected_point = m_runtime.low;
               else m_runtime.protected_point = m_runtime.high;
               m_runtime.protected_confirmed = m_runtime.trend == STRUCTURE_BULLISH ? m_runtime.low_confirmed : m_runtime.high_confirmed;
               m_runtime.has_protection = true;
            }
            next++;
         }
         if(m_runtime.last_bar == 0)
         { m_runtime.last_bar = bar.time; m_runtime.previous_close = bar.close; continue; }
         double previous_close = m_runtime.previous_close;
         bool change_down = m_runtime.trend == STRUCTURE_BULLISH && m_runtime.has_protection
                            && previous_close >= m_runtime.protected_point.price && bar.close < m_runtime.protected_point.price;
         bool change_up = m_runtime.trend == STRUCTURE_BEARISH && m_runtime.has_protection
                          && previous_close <= m_runtime.protected_point.price && bar.close > m_runtime.protected_point.price;
         if(change_down || change_up)
         {
            RecordBreak(found++, STRUCTURE_CHOCH, change_up ? STRUCTURE_BULLISH : STRUCTURE_BEARISH,
                        bar, m_runtime.protected_point, m_runtime.protected_confirmed, m_runtime.protected_point, m_runtime.protected_confirmed);
            // CHoCH is a warning, not an immediate confirmed reversal.
            m_runtime.trend = STRUCTURE_UNCLEAR; m_runtime.has_protection = false;
            m_runtime.high_relation = 0; m_runtime.low_relation = 0;
         }
         else if(m_runtime.trend == STRUCTURE_BULLISH && m_runtime.have_high && !m_runtime.high_broken
                 && previous_close <= m_runtime.high.price && bar.close > m_runtime.high.price)
         {
            RecordBreak(found++, STRUCTURE_BOS, STRUCTURE_BULLISH, bar, m_runtime.high, m_runtime.high_confirmed, m_runtime.low, m_runtime.low_confirmed);
            m_runtime.protected_point = m_runtime.low; m_runtime.protected_confirmed = m_runtime.low_confirmed; m_runtime.has_protection = true;
         }
         else if(m_runtime.trend == STRUCTURE_BEARISH && m_runtime.have_low && !m_runtime.low_broken
                 && previous_close >= m_runtime.low.price && bar.close < m_runtime.low.price)
         {
            RecordBreak(found++, STRUCTURE_BOS, STRUCTURE_BEARISH, bar, m_runtime.low, m_runtime.low_confirmed, m_runtime.high, m_runtime.high_confirmed);
            m_runtime.protected_point = m_runtime.high; m_runtime.protected_confirmed = m_runtime.high_confirmed; m_runtime.has_protection = true;
         }
         // Consume an extreme even if the initial direction is still unclear.
         if(m_runtime.have_high && bar.close > m_runtime.high.price) m_runtime.high_broken = true;
         if(m_runtime.have_low && bar.close < m_runtime.low.price) m_runtime.low_broken = true;
         m_runtime.last_bar = bar.time; m_runtime.previous_close = bar.close;
      }
      return ArrayResize(m_breaks, found) == found;
   }

public:
   CMarketStructure(void) { ClearStructureCheckpoint(m_runtime); }
   ENUM_STRUCTURE_TREND Trend(void) const { return m_runtime.trend; }
   int BreakCount(void) const { return ArraySize(m_breaks); }
   bool GetBreak(const int index, StructureBreak &event) const
   {
      if(index < 0 || index >= BreakCount()) return false;
      event = m_breaks[index]; return true;
   }
   bool ProtectedSwing(SwingPoint &point) const
   {
      if(!m_runtime.has_protection) return false;
      point = m_runtime.protected_point; return true;
   }
   // Closed OHLC snapshot; validates before replacing current classifications
   // and replayed break events. Same window => same results, no duplicate events.
   bool Analyze(const MqlRates &closed_bars[], const int left, const int right)
   {
      CSwingDetector detector;
      if(!detector.Configure(left, right) || !detector.Update(closed_bars)) return false;
      return AnalyzeDetected(closed_bars, detector, false);
   }
   // Detector is shared with the selector; caller must supply matching validated
   // bars/configuration. Continue only when the previous last candle is present.
   bool AnalyzeDetected(const MqlRates &closed_bars[], const CSwingDetector &detector,
                        const bool continuation)
   {
      CMarketStructure staged;
      if(!staged.Update(detector)) return false;
      if(continuation)
      {
         staged.m_runtime = m_runtime;
         int retained = BreakCount() > 100 ? 100 : BreakCount();
         if(ArrayResize(staged.m_breaks, retained) != retained) return false;
         for(int i = 0; i < retained; i++) staged.m_breaks[i] = m_breaks[BreakCount() - retained + i];
      }
      if(!staged.BuildBreaks(closed_bars, detector.RightBars())) return false;
      if(ArrayResize(m_points, staged.Count()) != staged.Count()
         || ArrayResize(m_breaks, staged.BreakCount()) != staged.BreakCount())
      { Reset(); return false; }
      for(int i = 0; i < staged.Count(); i++) m_points[i] = staged.m_points[i];
      for(int i = 0; i < staged.BreakCount(); i++) m_breaks[i] = staged.m_breaks[i];
      m_runtime = staged.m_runtime;
      return true;
   }
   void GetCheckpoint(StructureCheckpoint &state) const { state = m_runtime; }
   bool ValidKnownPoint(const SwingPoint &point, const datetime confirmed, const datetime before) const
   {
      return point.confirmed && point.time > 0 && confirmed >= point.time && confirmed < before
             && (point.type == SWING_HIGH || point.type == SWING_LOW)
             && MathIsValidNumber(point.price) && point.price != EMPTY_VALUE;
   }
   bool RestoreCheckpoint(const StructureCheckpoint &state, const StructureBreak &events[])
   {
      if(state.last_bar <= 0 || state.last_pivot > state.last_bar
         || !MathIsValidNumber(state.previous_close) || state.previous_close == EMPTY_VALUE
         || state.high_relation < -1 || state.high_relation > 1 || state.low_relation < -1 || state.low_relation > 1
         || state.trend < STRUCTURE_UNCLEAR || state.trend > STRUCTURE_BEARISH) return false;
      if((state.have_high && (!ValidKnownPoint(state.high, state.high_confirmed, state.last_bar) || state.high.type != SWING_HIGH))
         || (state.have_low && (!ValidKnownPoint(state.low, state.low_confirmed, state.last_bar) || state.low.type != SWING_LOW))
         || (state.has_protection && (!ValidKnownPoint(state.protected_point, state.protected_confirmed, state.last_bar)
                                     || state.trend == STRUCTURE_UNCLEAR))
         || (state.trend != STRUCTURE_UNCLEAR && !state.has_protection)) return false;
      int count = ArraySize(events);
      if(count > 100) return false;
      for(int i = 0; i < count; i++)
         if(events[i].time <= 0 || events[i].time > state.last_bar
            || !ValidKnownPoint(events[i].reference, events[i].reference_confirmed, events[i].time)
            || !ValidKnownPoint(events[i].origin, events[i].origin_confirmed, events[i].time)
            || (events[i].kind != STRUCTURE_BOS && events[i].kind != STRUCTURE_CHOCH)
            || (events[i].direction != STRUCTURE_BULLISH && events[i].direction != STRUCTURE_BEARISH)
            || !MathIsValidNumber(events[i].close_price) || !MathIsValidNumber(events[i].break_high)
            || !MathIsValidNumber(events[i].break_low) || events[i].close_price == EMPTY_VALUE
            || events[i].break_high == EMPTY_VALUE || events[i].break_low == EMPTY_VALUE
            || events[i].break_low > events[i].close_price || events[i].break_high < events[i].close_price
            || (i > 0 && events[i].time <= events[i - 1].time)) return false;
      if(ArrayResize(m_breaks, count) != count) return false;
      for(int i = 0; i < count; i++) m_breaks[i] = events[i];
      m_runtime = state;
      return true;
   }
   int Count(void) const { return ArraySize(m_points); }
   void Reset(void) { ArrayResize(m_points, 0); ResetBreaks(); }
   bool GetPoint(const int index, StructurePoint &point) const
   {
      if(index < 0 || index >= Count()) return false;
      point = m_points[index];
      return true;
   }

   // Complete snapshot, oldest first (AS_SERIES arrays are also accepted).
   // Invalid/unconfirmed input preserves the previous result. An empty snapshot
   // clears it. Same-candle HIGH+LOW is valid but omitted as ambiguous.
   bool Update(const SwingPoint &swings[])
   {
      int count = ArraySize(swings);
      bool series = ArrayGetAsSeries(swings);
      datetime previous = 0;
      int same_time = 0;
      ENUM_SWING_TYPE previous_type = SWING_HIGH;
      for(int i = 0; i < count; i++)
      {
         int index = series ? count - 1 - i : i;
         SwingPoint point = swings[index];
         if(point.time <= 0 || point.time < previous || !point.confirmed
            || (point.type != SWING_HIGH && point.type != SWING_LOW)
            || !MathIsValidNumber(point.price) || point.price == EMPTY_VALUE)
            return false;
         same_time = point.time == previous ? same_time + 1 : 1;
         if(same_time > 2 || (same_time == 2 && point.type == previous_type)) return false;
         previous = point.time;
         previous_type = point.type;
      }
      StructurePoint staged[];
      if(ArrayResize(staged, count) != count) return false;
      bool have_high = false, have_low = false;
      double high = 0.0, low = 0.0;
      int found = 0;
      for(int i = 0; i < count; i++)
      {
         int index = series ? count - 1 - i : i;
         SwingPoint point = swings[index];
         int before = series ? index + 1 : index - 1;
         int after = series ? index - 1 : index + 1;
         if((i > 0 && swings[before].time == point.time)
            || (i + 1 < count && swings[after].time == point.time)) continue;
         ENUM_STRUCTURE_LABEL label;
         if(point.type == SWING_HIGH)
         {
            label = !have_high ? STRUCTURE_H : (point.price > high ? STRUCTURE_HH
                    : (point.price < high ? STRUCTURE_LH : STRUCTURE_EH));
            high = point.price; have_high = true;
         }
         else
         {
            label = !have_low ? STRUCTURE_L : (point.price > low ? STRUCTURE_HL
                    : (point.price < low ? STRUCTURE_LL : STRUCTURE_EL));
            low = point.price; have_low = true;
         }
         staged[found].swing = point;
         staged[found].label = label;
         found++;
      }
      if(ArrayResize(m_points, found) != found) return false;
      for(int i = 0; i < found; i++) m_points[i] = staged[i];
      ResetBreaks();
      return true;
   }

   bool Update(const CSwingDetector &detector)
   {
      SwingPoint points[];
      int count = detector.Count();
      if(ArrayResize(points, count) != count) return false;
      for(int i = 0; i < count; i++)
         if(!detector.GetSwing(i, points[i])) return false;
      return Update(points);
   }
};

#endif // MARKET_STRUCTURE_MQH
