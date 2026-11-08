#ifndef MANUAL_FIBO_MODEL_MQH
#define MANUAL_FIBO_MODEL_MQH
#include <Fibo\Fibonacci.mqh>

#define MANUAL_FIBO_RATIOS 6
#define MANUAL_FIBO_DEFAULT_MASK 28 // 50%, 61.8%, 78.6%.

double ManualFiboRatio(const int index)
{
   double ratios[] = {0.236, 0.382, 0.5, 0.618, 0.786, 0.886};
   return index >= 0 && index < MANUAL_FIBO_RATIOS ? ratios[index] : EMPTY_VALUE;
}

// Pure model: the shared Fibonacci class owns calculation; no chart/GUI APIs.
class CManualFiboModel
{
private:
   CFibonacci m_fibo;
   datetime m_start_time, m_end_time;
   double m_start, m_end;
   int m_mask;
   bool m_ready, m_locked;
   double m_risk_percent, m_stops[MANUAL_FIBO_RATIOS];
   int m_custom_stops;
public:
   CManualFiboModel(void)
   {
      m_start_time = 0; m_end_time = 0; m_start = 0; m_end = 0;
      m_mask = MANUAL_FIBO_DEFAULT_MASK; m_ready = false; m_locked = false;
      m_risk_percent = 5.0; m_custom_stops = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) m_stops[i] = 0;
   }
   bool SetAnchors(const datetime first, const double start, const datetime last, const double end)
   {
      if(first <= 0 || last <= 0 || !m_fibo.SetAnchors(start, end)) return false;
      m_start_time = first; m_end_time = last; m_start = start; m_end = end; m_ready = true;
      return true;
   }
   void Clear(void)
   {
      m_ready = false; m_start_time = 0; m_end_time = 0; m_start = 0; m_end = 0;
      m_custom_stops = 0;
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) m_stops[i] = 0;
   }
   void CopyFrom(const CManualFiboModel &other)
   {
      if(other.Ready()) SetAnchors(other.StartTime(), other.StartPrice(), other.EndTime(), other.EndPrice());
      else Clear();
      m_mask = other.Mask(); m_locked = other.Locked(); m_risk_percent = other.RiskPercent();
      m_custom_stops = other.CustomStops();
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) m_stops[i] = other.RawStop(i);
   }
   bool SetMask(const int mask)
   {
      if(mask < 0 || mask >= (1 << MANUAL_FIBO_RATIOS)) return false;
      m_mask = mask; return true;
   }
   bool SetRiskPercent(const double percent)
   {
      if(!MathIsValidNumber(percent) || percent < 0 || percent > 100) return false;
      m_risk_percent = percent; return true;
   }
   double RiskPercent(void) const { return m_risk_percent; }
   int CustomStops(void) const { return m_custom_stops; }
   bool StopCustom(const int index) const
   { return index >= 0 && index < MANUAL_FIBO_RATIOS && (m_custom_stops & (1 << index)) != 0; }
   double RawStop(const int index) const
   { return index >= 0 && index < MANUAL_FIBO_RATIOS ? m_stops[index] : EMPTY_VALUE; }
   double StopPrice(const int index) const
   {
      if(index < 0 || index >= MANUAL_FIBO_RATIOS) return EMPTY_VALUE;
      return StopCustom(index) ? m_stops[index] : (m_ready ? m_start : EMPTY_VALUE);
   }
   bool SetStop(const int index, const double price)
   {
      if(index < 0 || index >= MANUAL_FIBO_RATIOS || !MathIsValidNumber(price)
         || price <= 0 || price == EMPTY_VALUE) return false;
      m_stops[index] = price; m_custom_stops |= 1 << index; return true;
   }
   void ResetStop(const int index)
   {
      if(index < 0 || index >= MANUAL_FIBO_RATIOS) return;
      m_custom_stops &= ~(1 << index); m_stops[index] = 0;
   }
   bool Enabled(const int index) const
   { return index >= 0 && index < MANUAL_FIBO_RATIOS && (m_mask & (1 << index)) != 0; }
   int Mask(void) const { return m_mask; }
   bool Ready(void) const { return m_ready; }
   bool Locked(void) const { return m_locked; }
   void SetLocked(const bool locked) { m_locked = locked; }
   datetime StartTime(void) const { return m_start_time; }
   datetime EndTime(void) const { return m_end_time; }
   double StartPrice(void) const { return m_start; }
   double EndPrice(void) const { return m_end; }
   double Price(const int index) const
   { return m_ready ? m_fibo.PriceAt(ManualFiboRatio(index)) : EMPTY_VALUE; }
};
#endif
