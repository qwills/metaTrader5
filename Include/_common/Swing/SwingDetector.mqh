#ifndef SWING_DETECTOR_MQH
#define SWING_DETECTOR_MQH

#include "SwingTypes.mqh"

// Pure, closed-candle pivot detection. No chart, indicator, symbol or trade APIs.
class CSwingDetector
{
private:
   int m_left;
   int m_right;
   ENUM_SWING_EQUAL_POLICY m_equal;
   SwingPoint m_swings[];

   int Index(const int chronological_index, const int count, const bool series) const
   {
      return series ? count - 1 - chronological_index : chronological_index;
   }

   bool IsPivot(const MqlRates &bars[], const int candidate, const int count,
                const bool series, const bool high) const
   {
      int index = Index(candidate, count, series);
      double price = high ? bars[index].high : bars[index].low;
      for(int offset = -m_left; offset <= m_right; offset++)
      {
         if(offset == 0)
            continue;
         int neighbor = Index(candidate + offset, count, series);
         double other = high ? bars[neighbor].high : bars[neighbor].low;
         if((high && other > price) || (!high && other < price))
            return false;
         if(other == price)
         {
            if(m_equal == SWING_EQUAL_REJECT
               || (m_equal == SWING_EQUAL_FIRST && offset < 0)
               || (m_equal == SWING_EQUAL_LAST && offset > 0))
               return false;
         }
      }
      return true;
   }

public:
   CSwingDetector(void)
   {
      m_left = 2;
      m_right = 2;
      m_equal = SWING_EQUAL_REJECT;
   }

   // A changed configuration clears results. Invalid settings preserve everything.
   bool Configure(const int left_bars, const int right_bars,
                  const ENUM_SWING_EQUAL_POLICY equal_policy = SWING_EQUAL_REJECT)
   {
      if(left_bars < 1 || right_bars < 1
         || (long)left_bars + right_bars + 1 > INT_MAX
         || equal_policy < SWING_EQUAL_REJECT || equal_policy > SWING_EQUAL_LAST)
         return false;
      if(left_bars != m_left || right_bars != m_right || equal_policy != m_equal)
      {
         Reset();
         m_left = left_bars;
         m_right = right_bars;
         m_equal = equal_policy;
      }
      return true;
   }

   int LeftBars(void) const { return m_left; }
   int RightBars(void) const { return m_right; }
   ENUM_SWING_EQUAL_POLICY EqualPolicy(void) const { return m_equal; }
   int Count(void) const { return ArraySize(m_swings); }

   // Replace results with pivots in this complete closed-candle window.
   // Caller must exclude the forming candle (e.g. CopyRates start_pos=1).
   // Both ordinary and AS_SERIES indexing are accepted; times must be unique
   // and chronological after accounting for that flag. Invalid data is atomic.
   bool Update(const MqlRates &closed_bars[])
   {
      int count = ArraySize(closed_bars);
      bool series = ArrayGetAsSeries(closed_bars);
      datetime previous = 0;
      for(int i = 0; i < count; i++)
      {
         int index = Index(i, count, series);
         if(closed_bars[index].time <= previous
            || !MathIsValidNumber(closed_bars[index].high)
            || !MathIsValidNumber(closed_bars[index].low)
            || closed_bars[index].high == EMPTY_VALUE
            || closed_bars[index].low == EMPTY_VALUE
            || closed_bars[index].high < closed_bars[index].low)
            return false;
         previous = closed_bars[index].time;
      }
      if(count < (long)m_left + m_right + 1)
      {
         Reset();
         return true;
      }
      long capacity = 2 * (long)(count - m_left - m_right);
      if(capacity > INT_MAX)
         return false;
      SwingPoint staged[];
      if(ArrayResize(staged, (int)capacity) != (int)capacity)
         return false;
      int found = 0;
      for(int i = m_left; i < count - m_right; i++)
      {
         int index = Index(i, count, series);
         // An outside candle can qualify as both HIGH and LOW. Emit both,
         // HIGH first, without assuming the intrabar order of those extremes.
         for(int kind = 0; kind < 2; kind++)
         {
            bool high = kind == 0;
            if(!IsPivot(closed_bars, i, count, series, high))
               continue;
            staged[found].time = closed_bars[index].time;
            staged[found].price = high ? closed_bars[index].high : closed_bars[index].low;
            staged[found].type = high ? SWING_HIGH : SWING_LOW;
            staged[found].confirmed = true;
            found++;
         }
      }
      if(ArrayResize(m_swings, found) != found)
         return false;
      for(int i = 0; i < found; i++)
         m_swings[i] = staged[i];
      return true;
   }

   // Results are ordered oldest first; failed lookups leave point unchanged.
   bool GetSwing(const int index, SwingPoint &point) const
   {
      if(index < 0 || index >= Count())
         return false;
      point = m_swings[index];
      return true;
   }

   bool LastHigh(SwingPoint &point) const
   {
      for(int i = Count() - 1; i >= 0; i--)
         if(m_swings[i].type == SWING_HIGH)
            return GetSwing(i, point);
      return false;
   }

   bool LastLow(SwingPoint &point) const
   {
      for(int i = Count() - 1; i >= 0; i--)
         if(m_swings[i].type == SWING_LOW)
            return GetSwing(i, point);
      return false;
   }

   void Reset(void) { ArrayResize(m_swings, 0); }
};

#endif // SWING_DETECTOR_MQH
