//+------------------------------------------------------------------+
//|                                                 MMCalculator.mqh  |
//+------------------------------------------------------------------+
#ifndef MM_CALCULATOR_MQH
#define MM_CALCULATOR_MQH

#include "MMTypes.mqh"

int MMVolumeDigits(const double volume_step)
{
   int digits = 0;
   double value = volume_step;

   while(digits < 8 && MathAbs(value - MathRound(value)) > 0.00000001)
   {
      value *= 10.0;
      digits++;
   }

   return digits;
}

double MMNormalizeVolumeDown(const double volume)
{
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(volume <= 0.0 || volume_step <= 0.0)
      return 0.0;

   double normalized = MathFloor(volume / volume_step) * volume_step;

   if(volume_max > 0.0 && normalized > volume_max)
      normalized = MathFloor(volume_max / volume_step) * volume_step;

   if(normalized < volume_min)
      return 0.0;

   return NormalizeDouble(normalized, MMVolumeDigits(volume_step));
}

double MMNormalizePrice(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathRound(price / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double MMNormalizePriceUp(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathCeil((price - 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double MMNormalizePriceDown(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathFloor((price + 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double MMMinimumStopsDistance()
{
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int required_level = MathMax(stops_level, freeze_level);

   return (double)required_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

double MMLotByPoints(const double entry, const double sl, const double riskpct)
{
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_usd    = riskpct / 100.0 * balance;
   double tick_size   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   double distance    = MathAbs(entry - sl);

   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(risk_usd <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 || distance <= 0.0)
      return 0.0;

   double loss_per_lot = (distance / tick_size) * tick_value;
   double lot = risk_usd / loss_per_lot;

   return MMNormalizeVolumeDown(lot);
}

string MMRewardRiskText(const double entry, const double sl, const double tp)
{
   if(tp <= 0.0)
      return "-";

   double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return "-";

   bool is_buy = (sl < entry);
   if(is_buy && tp <= entry)
      return "-";
   if(!is_buy && tp >= entry)
      return "-";

   double reward = (is_buy ? tp - entry : entry - tp);
   if(reward <= 0.0)
      return "-";

   return DoubleToString(reward / risk, 2);
}

string MMRewardRiskText(const double entry, const double buy_sl, const double sell_sl, const double tp)
{
   if(tp > entry)
      return MMRewardRiskText(entry, buy_sl, tp);
   if(tp < entry)
      return MMRewardRiskText(entry, sell_sl, tp);

   return "-";
}

bool MMTPFromRewardRisk(const double entry, const double sl, const double rr, double &tp)
{
   double risk = MathAbs(entry - sl);
   if(rr <= 0.0 || risk <= 0.0)
      return false;

   tp = entry + risk * rr;
   if(sl > entry)
      tp = entry - risk * rr;

   return true;
}

string MMLotText(const double entry, const double sl, const double riskpct)
{
   double lot = MMLotByPoints(entry, sl, riskpct);
   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return "-";

   return DoubleToString(lot, MMVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
}

#endif
