#ifndef MY_FIBO_AUTO_MQH
#define MY_FIBO_AUTO_MQH

#include <Structure\MarketStructure.mqh>
#include "MyFiboTypes.mqh"

// Auto selection: latest confirmed Pivot pair or the latest causal BOS impulse.
// Pure data logic: the EA owns market data access and chart drawing.
class CMyFiboAuto
{
private:
   CSwingDetector m_detector;
   CMarketStructure m_structure;
   MqlRates m_previous[];
   string m_error;
   bool m_reseeded;

   bool Ambiguous(const int index, const SwingPoint &point) const
   {
      SwingPoint other;
      return (m_detector.GetSwing(index - 1, other) && other.time == point.time)
             || (m_detector.GetSwing(index + 1, other) && other.time == point.time);
   }

   bool FindStructurePair(SwingPoint &start, SwingPoint &end) const
   {
      StructureBreak event;
      if(!m_structure.GetBreak(m_structure.BreakCount() - 1, event)
         || event.kind != STRUCTURE_BOS || event.direction != m_structure.Trend()
         || !event.origin.confirmed || event.origin_confirmed >= event.time
         || event.origin.time >= event.time)
         return false;

      bool bullish = event.direction == STRUCTURE_BULLISH;
      double price = bullish ? event.break_high : event.break_low;
      if(event.origin.type != (bullish ? SWING_LOW : SWING_HIGH)
         || (bullish && event.origin.price >= price)
         || (!bullish && event.origin.price <= price)) return false;
      SwingPoint endpoint;
      endpoint.time = event.time;
      endpoint.price = price;
      endpoint.type = bullish ? SWING_HIGH : SWING_LOW;
      // Closed candle extreme, not a right-confirmed pivot.
      endpoint.confirmed = false;
      start = event.origin; end = endpoint;
      return true;
   }

public:
   CMyFiboAuto(void) { m_error = ""; m_reseeded = false; }
   bool Configure(const int left, const int right)
   {
      if(left != m_detector.LeftBars() || right != m_detector.RightBars())
      {
         if(!m_detector.Configure(left, right, SWING_EQUAL_REJECT)) return false;
         ResetAnalysis();
      }
      return true;
   }

   int StructureCount(void) const { return m_structure.Count(); }
   bool GetStructurePoint(const int index, StructurePoint &point) const
   {
      return m_structure.GetPoint(index, point);
   }

   ENUM_STRUCTURE_TREND Trend(void) const { return m_structure.Trend(); }
   int BreakCount(void) const { return m_structure.BreakCount(); }
   bool GetBreak(const int index, StructureBreak &event) const
   {
      return m_structure.GetBreak(index, event);
   }

   void ResetAnalysis(void)
   {
      m_structure.Reset(); ArrayResize(m_previous, 0); m_error = ""; m_reseeded = false;
   }
   string LastError(void) const { return m_error; }
   bool Reseeded(void) const { return m_reseeded; }
   void GetCheckpoint(StructureCheckpoint &state) const { m_structure.GetCheckpoint(state); }
   bool RestoreCheckpoint(const StructureCheckpoint &state, const StructureBreak &events[])
   {
      ArrayResize(m_previous, 0);
      return m_structure.RestoreCheckpoint(state, events);
   }
   MyFiboAnalysisResult Analyze(const MqlRates &closed_bars[], SwingPoint &start, SwingPoint &end,
                               const MyFiboAutoMethod method, const bool allow_gap_reset = false)
   {
      m_error = ""; m_reseeded = false;
      if(method != FIBO_PIVOT && method != FIBO_MARKET_STRUCTURE)
      { m_error = "Metode tidak valid."; return FIBO_ANALYSIS_ERROR; }
      if(!m_detector.Update(closed_bars))
      { m_error = "Data high/low atau waktu tidak valid."; return FIBO_ANALYSIS_ERROR; }
      int count = ArraySize(closed_bars);
      bool series = ArrayGetAsSeries(closed_bars);
      for(int i = 0; i < count; i++)
      {
         MqlRates bar = closed_bars[series ? count - 1 - i : i];
         if(!MathIsValidNumber(bar.close) || bar.close == EMPTY_VALUE
            || bar.close < bar.low || bar.close > bar.high)
         { m_error = "Data close tidak valid."; return FIBO_ANALYSIS_ERROR; }
      }
      StructureCheckpoint state; m_structure.GetCheckpoint(state);
      bool continuation = state.last_bar > 0;
      bool revised = false;
      if(continuation)
      {
         int anchor = -1;
         for(int i = 0; i < count; i++)
            if(closed_bars[series ? count - 1 - i : i].time == state.last_bar) anchor = i;
         if(anchor < m_detector.LeftBars() + m_detector.RightBars())
         {
            if(!allow_gap_reset)
            { m_error = "Gap histori; klik Cari Swing untuk memulai ulang."; return FIBO_ANALYSIS_ERROR; }
            revised = true;
         }
         else if(closed_bars[series ? count - 1 - anchor : anchor].close != state.previous_close) revised = true;
         int old = 0;
         for(int i = 0; i < count && !revised && ArraySize(m_previous) > 0; i++)
         {
            MqlRates bar = closed_bars[series ? count - 1 - i : i];
            while(old < ArraySize(m_previous) && m_previous[old].time < bar.time) old++;
            if(old < ArraySize(m_previous) && m_previous[old].time == bar.time
               && (m_previous[old].high != bar.high || m_previous[old].low != bar.low
                   || m_previous[old].close != bar.close)) revised = true;
         }
         if(ArraySize(m_previous) > 0 && count > 0
            && closed_bars[series ? count - 1 : 0].time < m_previous[0].time) revised = true;
         if(revised) { continuation = false; m_reseeded = true; }
      }
      // Only one detector pass. Model receives that validated result.
      if(!m_structure.AnalyzeDetected(closed_bars, m_detector, continuation))
      { m_error = "Analisis struktur gagal."; return FIBO_ANALYSIS_ERROR; }
      if(ArrayResize(m_previous, count) != count)
      { m_error = "Alokasi cache gagal."; return FIBO_ANALYSIS_ERROR; }
      for(int i = 0; i < count; i++) m_previous[i] = closed_bars[series ? count - 1 - i : i];
      if(method == FIBO_MARKET_STRUCTURE)
         return FindStructurePair(start, end) ? FIBO_PAIR_READY : FIBO_WAITING_PAIR;
      return FindPivotPair(start, end) ? FIBO_PAIR_READY : FIBO_WAITING_PAIR;
   }
   bool FindPair(const MqlRates &closed_bars[], SwingPoint &start, SwingPoint &end,
                 const MyFiboAutoMethod method = FIBO_PIVOT)
   {
      return Analyze(closed_bars, start, end, method, true) == FIBO_PAIR_READY;
   }
private:
   bool FindPivotPair(SwingPoint &start, SwingPoint &end) const
   {
      SwingPoint last;
      bool found = false;
      int last_index = -1;
      for(int i = m_detector.Count() - 1; i >= 0; i--)
      {
         if(m_detector.GetSwing(i, last) && !Ambiguous(i, last))
         {
            last_index = i;
            found = true;
            break;
         }
      }
      if(!found)
         return false;
      SwingPoint first;
      for(int i = last_index - 1; i >= 0; i--)
      {
         if(!m_detector.GetSwing(i, first) || Ambiguous(i, first)
            || first.type == last.type || first.time >= last.time)
            continue;
         if((last.type == SWING_HIGH && first.price >= last.price)
            || (last.type == SWING_LOW && first.price <= last.price))
            continue;
         start = first;
         end = last;
         return true;
      }
      return false;
   }
};

#endif // MY_FIBO_AUTO_MQH
