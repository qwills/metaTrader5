#ifndef FIBONACCI_MQH
#define FIBONACCI_MQH

// Retracement convention: 0 = swing end, 1 = swing start.
// No symbol dependencies, price rounding, chart objects, or trading actions.
class CFibonacci
{
private:
   double m_start;
   double m_end;
   double m_levels[];
   bool   m_ready;

public:
   CFibonacci(void)
   {
      m_start = 0.0;
      m_end = 0.0;
      m_ready = false;
      double defaults[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
      SetLevels(defaults);
   }

   // Invalid updates preserve the previous valid anchors.
   bool SetAnchors(const double swing_start, const double swing_end)
   {
      if(!MathIsValidNumber(swing_start) || !MathIsValidNumber(swing_end)
         || swing_start == EMPTY_VALUE || swing_end == EMPTY_VALUE
         || swing_start == swing_end
         || !MathIsValidNumber(swing_start - swing_end))
         return false;

      m_start = swing_start;
      m_end = swing_end;
      m_ready = true;
      return true;
   }

   bool IsReady(void) const { return m_ready; }
   int LevelCount(void) const { return ArraySize(m_levels); }

   // Preserve supplied order and duplicates. Negative ratios project beyond
   // the swing end; ratios greater than 1 project beyond the swing start.
   // Invalid updates preserve the previous levels.
   bool SetLevels(const double &ratios[])
   {
      int count = ArraySize(ratios);
      if(count == 0)
         return false;
      for(int i = 0; i < count; i++)
         if(!MathIsValidNumber(ratios[i]) || ratios[i] == EMPTY_VALUE)
            return false;

      if(ArrayResize(m_levels, count) != count)
         return false;
      for(int i = 0; i < count; i++)
         m_levels[i] = ratios[i];
      return true;
   }

   // EMPTY_VALUE signals an invalid index or unavailable/invalid result.
   double LevelRatio(const int index) const
   {
      if(index < 0 || index >= LevelCount())
         return EMPTY_VALUE;
      return m_levels[index];
   }

   double PriceAt(const double ratio) const
   {
      if(!m_ready || !MathIsValidNumber(ratio) || ratio == EMPTY_VALUE)
         return EMPTY_VALUE;
      double price = m_end + (m_start - m_end) * ratio;
      if(!MathIsValidNumber(price))
         return EMPTY_VALUE;
      return price;
   }

   double LevelPrice(const int index) const
   {
      if(index < 0 || index >= LevelCount())
         return EMPTY_VALUE;
      return PriceAt(m_levels[index]);
   }
};

#endif // FIBONACCI_MQH
