//+------------------------------------------------------------------+
//|                                                 ASCalculator.mqh  |
//+------------------------------------------------------------------+
#ifndef AS_CALCULATOR_MQH
#define AS_CALCULATOR_MQH

#include "ASTypes.mqh"

int ASVolumeDigits(const double volume_step)
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

string ASDefaultLotText()
{
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   return DoubleToString(volume_min, ASVolumeDigits(volume_step));
}

double ASNormalizeVolumeDown(const double volume)
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

   return NormalizeDouble(normalized, ASVolumeDigits(volume_step));
}

double ASNormalizePrice(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathRound(price / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ASNormalizePriceUp(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathCeil((price - 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ASNormalizePriceDown(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathFloor((price + 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ASMinimumStopsDistance()
{
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int required_level = MathMax(stops_level, freeze_level);

   return (double)required_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

bool ASLossForDistance(const ENUM_ORDER_TYPE order_type,
                       const double entry,
                       const double lot,
                       const double distance,
                       double &loss)
{
   double close_price = (order_type == ORDER_TYPE_BUY ? entry - distance : entry + distance);
   double profit = 0.0;

   loss = 0.0;
   if(close_price <= 0.0)
      return false;
   if(!OrderCalcProfit(order_type, _Symbol, lot, entry, close_price, profit))
      return false;

   loss = MathAbs(profit);
   return true;
}

bool ASDistanceFromRisk(const ENUM_ORDER_TYPE order_type,
                        const double entry,
                        const double lot,
                        const double risk_usd,
                        double &distance,
                        string &error_message)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double high = tick_size;
   double loss = 0.0;

   distance = 0.0;
   if(risk_usd <= 0.0 || tick_size <= 0.0)
   {
      error_message = "Risk or tick size is invalid.";
      return false;
   }

   for(int i = 0; i < 64; i++)
   {
      if(!ASLossForDistance(order_type, entry, lot, high, loss))
      {
         error_message = "Cannot calculate risk for this symbol.";
         return false;
      }
      if(loss >= risk_usd)
         break;

      high *= 2.0;
   }

   if(loss < risk_usd)
   {
      error_message = "Calculated SL distance is invalid.";
      return false;
   }

   double low = 0.0;
   for(int i = 0; i < 48; i++)
   {
      double mid = (low + high) / 2.0;
      if(!ASLossForDistance(order_type, entry, lot, mid, loss))
      {
         error_message = "Cannot calculate risk for this symbol.";
         return false;
      }

      if(loss < risk_usd)
         low = mid;
      else
         high = mid;
   }

   distance = high;
   return true;
}

bool ASSLFromRiskLot(const double entry_input,
                     const double lot_input,
                     const double riskpct,
                     const double riskreward,
                     double &sl,
                     double &tp,
                     string &side,
                     string &error_message)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      error_message = "Cannot read current Bid/Ask for " + _Symbol;
      return false;
   }

   double entry = ASNormalizePrice(entry_input);
   double lot = lot_input;
   double risk_usd = riskpct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(entry <= 0.0)
   {
      error_message = "Entry must be a valid price.";
      return false;
   }
   if(lot <= 0.0 || lot < volume_min)
   {
      error_message = "Lot is below this symbol's minimum volume.";
      return false;
   }
   if(volume_max > 0.0 && lot > volume_max)
   {
      error_message = "Lot is above this symbol's maximum volume.";
      return false;
   }
   if(volume_step <= 0.0 || MathAbs(lot / volume_step - MathRound(lot / volume_step)) > 0.00000001)
   {
      error_message = StringFormat("Lot must match this symbol's volume step. Min=%s Max=%s Step=%s",
                                   DoubleToString(volume_min, ASVolumeDigits(volume_step)),
                                   DoubleToString(volume_max, ASVolumeDigits(volume_step)),
                                   DoubleToString(volume_step, ASVolumeDigits(volume_step)));
      return false;
   }
   if(risk_usd <= 0.0)
   {
      error_message = "Risk must be greater than zero.";
      return false;
   }
   if(riskreward <= 0.0)
   {
      error_message = "RiskReward must be greater than zero.";
      return false;
   }

   double bid = ASNormalizePrice(tick.bid);
   double ask = ASNormalizePrice(tick.ask);
   double min_distance = ASMinimumStopsDistance();
   double distance = 0.0;
   double reward_distance = 0.0;
   ENUM_ORDER_TYPE order_type;

   if(entry <= bid)
   {
      if(min_distance > 0.0 && ask - entry < min_distance)
      {
         error_message = "BUY LIMIT entry is too close to current Ask for this symbol.";
         return false;
      }
      side = "BUY LIMIT";
      order_type = ORDER_TYPE_BUY;
   }
   else if(entry >= ask)
   {
      if(min_distance > 0.0 && entry - bid < min_distance)
      {
         error_message = "SELL LIMIT entry is too close to current Bid for this symbol.";
         return false;
      }
      side = "SELL LIMIT";
      order_type = ORDER_TYPE_SELL;
   }
   else
   {
      error_message = StringFormat("Entry must be at or below Bid for buy-side SL or at or above Ask for sell-side SL. Bid=%s Ask=%s",
                                   DoubleToString(bid, Digits()),
                                   DoubleToString(ask, Digits()));
      return false;
   }

   if(!ASDistanceFromRisk(order_type, entry, lot, risk_usd, distance, error_message))
      return false;
   if(distance <= 0.0)
   {
      error_message = "Calculated SL distance is invalid.";
      return false;
   }

   reward_distance = distance * riskreward;

   if(side == "BUY LIMIT")
   {
      sl = ASNormalizePriceDown(entry - distance);
      tp = ASNormalizePriceUp(entry + reward_distance);
   }
   else
   {
      sl = ASNormalizePriceUp(entry + distance);
      tp = ASNormalizePriceDown(entry - reward_distance);
   }

   if(sl <= 0.0 || tp <= 0.0)
   {
      error_message = "Calculated SL or TP is invalid.";
      return false;
   }
   if(min_distance > 0.0 && MathAbs(entry - sl) < min_distance)
   {
      error_message = "Calculated SL is too close to Entry for this symbol.";
      return false;
   }
   if(min_distance > 0.0 && MathAbs(entry - tp) < min_distance)
   {
      error_message = "Calculated TP is too close to Entry for this symbol.";
      return false;
   }

   return true;
}

#endif
