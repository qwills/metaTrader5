//+------------------------------------------------------------------+
//|                                                 ESCalculator.mqh  |
//+------------------------------------------------------------------+
#ifndef ES_CALCULATOR_MQH
#define ES_CALCULATOR_MQH

#include "ESTypes.mqh"

int ESVolumeDigits(const double volume_step)
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

string ESDefaultLotText()
{
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   return DoubleToString(volume_min, ESVolumeDigits(volume_step));
}

double ESNormalizeVolumeDown(const double volume)
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

   return NormalizeDouble(normalized, ESVolumeDigits(volume_step));
}

double ESNormalizePrice(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathRound(price / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ESNormalizePriceUp(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathCeil((price - 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ESNormalizePriceDown(const double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(price <= 0.0)
      return 0.0;

   if(tick_size > 0.0)
      return NormalizeDouble(MathFloor((price + 0.0000000001) / tick_size) * tick_size, Digits());

   return NormalizeDouble(price, Digits());
}

double ESMinimumStopsDistance()
{
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int required_level = MathMax(stops_level, freeze_level);

   return (double)required_level * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

bool ESLossForDistance(const ENUM_ORDER_TYPE order_type,
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

bool ESDistanceFromRisk(const ENUM_ORDER_TYPE order_type,
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
      if(!ESLossForDistance(order_type, entry, lot, high, loss))
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
      if(!ESLossForDistance(order_type, entry, lot, mid, loss))
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

bool ESSLFromRiskLot(const ENUM_ORDER_TYPE order_type,
                     const double lot_input,
                     const double riskpct,
                     const double riskreward,
                     double &entry,
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

   double lot = lot_input;
   double risk_usd = riskpct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   entry = 0.0;
   if(order_type != ORDER_TYPE_BUY && order_type != ORDER_TYPE_SELL)
   {
      error_message = "Market side must be BUY or SELL.";
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
                                   DoubleToString(volume_min, ESVolumeDigits(volume_step)),
                                   DoubleToString(volume_max, ESVolumeDigits(volume_step)),
                                   DoubleToString(volume_step, ESVolumeDigits(volume_step)));
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

   double bid = ESNormalizePrice(tick.bid);
   double ask = ESNormalizePrice(tick.ask);
   double min_distance = ESMinimumStopsDistance();
   double distance = 0.0;
   double reward_distance = 0.0;

   if(order_type == ORDER_TYPE_BUY)
   {
      entry = ask;
      side = "BUY";
   }
   else
   {
      entry = bid;
      side = "SELL";
   }

   if(!ESDistanceFromRisk(order_type, entry, lot, risk_usd, distance, error_message))
      return false;
   if(distance <= 0.0)
   {
      error_message = "Calculated SL distance is invalid.";
      return false;
   }

   if(order_type == ORDER_TYPE_BUY)
   {
      sl = ESNormalizePriceDown(entry - distance);
      reward_distance = (entry - sl) * riskreward;
      tp = ESNormalizePriceUp(entry + reward_distance);
   }
   else
   {
      sl = ESNormalizePriceUp(entry + distance);
      reward_distance = (sl - entry) * riskreward;
      tp = ESNormalizePriceDown(entry - reward_distance);
   }

   if(sl <= 0.0 || tp <= 0.0)
   {
      error_message = "Calculated SL or TP is invalid.";
      return false;
   }
   if(order_type == ORDER_TYPE_BUY && min_distance > 0.0 && bid - sl < min_distance)
   {
      error_message = "Calculated BUY SL is too close to current Bid for this symbol.";
      return false;
   }
   if(order_type == ORDER_TYPE_BUY && min_distance > 0.0 && tp - bid < min_distance)
   {
      error_message = "Calculated BUY TP is too close to current Bid for this symbol.";
      return false;
   }
   if(order_type == ORDER_TYPE_SELL && min_distance > 0.0 && sl - ask < min_distance)
   {
      error_message = "Calculated SELL SL is too close to current Ask for this symbol.";
      return false;
   }
   if(order_type == ORDER_TYPE_SELL && min_distance > 0.0 && ask - tp < min_distance)
   {
      error_message = "Calculated SELL TP is too close to current Ask for this symbol.";
      return false;
   }

   return true;
}

#endif
