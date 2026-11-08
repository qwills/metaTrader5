#ifndef FIBO_RISK_MQH
#define FIBO_RISK_MQH
#include "FiboModel.mqh"

// Strict decimal input: never accept a numeric prefix of malformed text.
bool FiboParseNumber(string text, double &value)
{
   StringTrimLeft(text); StringTrimRight(text);
   bool decimal = false, digit = false;
   if(StringLen(text) == 0) return false;
   for(int i = 0; i < StringLen(text); i++)
   {
      ushort ch = StringGetCharacter(text, i);
      if(ch >= '0' && ch <= '9') { digit = true; continue; }
      if(ch == '.' && !decimal) { decimal = true; continue; }
      return false;
   }
   if(!digit) return false;
   double parsed = StringToDouble(text);
   if(!MathIsValidNumber(parsed) || parsed == EMPTY_VALUE) return false;
   value = parsed; return true;
}

enum FiboLimit { FIBO_LIMIT_NONE, FIBO_LIMIT_BUY, FIBO_LIMIT_SELL };

string FiboLimitName(const FiboLimit kind)
{
   if(kind == FIBO_LIMIT_BUY) return "BUY LIMIT";
   if(kind == FIBO_LIMIT_SELL) return "SELL LIMIT";
   return "-";
}

struct FiboLot
{
   double volume, loss, entry, stop;
   FiboLimit kind;
   string error;
};

// One account/symbol snapshot shared by every level in a refresh.
struct FiboRiskContext
{
   double total_budget, budget, step, minimum, maximum, tick, bid, ask, stop_distance;
   int volume_digits;
   string currency;
   bool valid, quotes_valid;
};

// Estimates only: no order placement and no trading state in the Fibonacci model.
class CFiboRisk
{
public:
   int VolumeDigits(const double step) const
   {
      double scaled = step;
      int digits = 0;
      while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 0.0000000001)
      { scaled *= 10; digits++; }
      return digits;
   }
   double Budget(const CFiboModel &model) const
   {
      double capital = AccountInfoDouble(model.BalanceRisk() ? ACCOUNT_BALANCE : ACCOUNT_EQUITY);
      double budget = capital * (model.RiskPercent() / 100.0);
      return MathIsValidNumber(capital) && capital > 0 && MathIsValidNumber(budget) && budget > 0 ? budget : 0;
   }
   void ReadContext(const CFiboModel &model, FiboRiskContext &context) const
   {
      context.total_budget = Budget(model);
      context.budget = context.total_budget;
      if(model.RiskAll() && model.SelectedCount() > 0) context.budget /= model.SelectedCount();
      context.currency = AccountInfoString(ACCOUNT_CURRENCY);
      context.step = 0; context.minimum = 0; context.maximum = 0; context.tick = 0;
      context.volume_digits = 0; context.valid = false; context.quotes_valid = false;
      context.bid = 0; context.ask = 0; context.stop_distance = 0;
      if(!model.Ready() || model.Mask() == 0 || context.budget <= 0) return;
      context.step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      context.minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      context.maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      context.tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      long stops = 0;
      if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stops) || stops < 0
         || !MathIsValidNumber(point) || point <= 0) return;
      context.stop_distance = (double)stops * point;
      if(!MathIsValidNumber(context.stop_distance)) return;
      MqlTick quote = {};
      context.quotes_valid = SymbolInfoTick(_Symbol, quote) && quote.time > 0
                             && MathIsValidNumber(quote.bid) && MathIsValidNumber(quote.ask)
                             && quote.bid > 0 && quote.ask >= quote.bid;
      if(context.quotes_valid) { context.bid = quote.bid; context.ask = quote.ask; }
      if(!MathIsValidNumber(context.step) || !MathIsValidNumber(context.minimum)
         || !MathIsValidNumber(context.maximum) || !MathIsValidNumber(context.tick)
         || context.step <= 0 || context.minimum <= 0 || context.maximum < context.minimum || context.tick <= 0) return;
      context.volume_digits = VolumeDigits(context.step);
      // Do not silently round unsupported volume precision into another step.
      double rounded_step = NormalizeDouble(context.step, context.volume_digits);
      context.valid = rounded_step > 0 && MathAbs(rounded_step - context.step) <= context.step * 0.00000001;
   }
   bool Calculate(const CFiboModel &model, const int index, FiboLot &result) const
   {
      FiboRiskContext context; ReadContext(model, context);
      return Calculate(model, index, context, result);
   }
   bool Calculate(const CFiboModel &model, const int index,
                  const FiboRiskContext &context, FiboLot &result) const
   {
      result.volume = 0; result.loss = 0; result.entry = 0; result.stop = 0; result.error = "-";
      result.kind = FIBO_LIMIT_NONE;
      if(!model.Ready() || !model.Enabled(index)) return false;
      double budget = context.budget;
      if(budget <= 0) { result.error = "Risk?"; return false; }
      if(!context.valid) { result.error = "Data?"; return false; }
      if(!context.quotes_valid) { result.error = "Quotes?"; return false; }
      double step = context.step, minimum = context.minimum, maximum = context.maximum, tick = context.tick;
      double entry = model.Price(index), stop = model.StopPrice(index);
      if(entry == EMPTY_VALUE || stop == EMPTY_VALUE || !MathIsValidNumber(entry) || !MathIsValidNumber(stop))
      { result.error = "SL?"; return false; }
      entry = NormalizeDouble(MathRound(entry / tick) * tick, _Digits);
      stop = NormalizeDouble(MathRound(stop / tick) * tick, _Digits);
      if(!MathIsValidNumber(entry) || entry <= 0) { result.error = "Entry?"; return false; }
      result.entry = entry; result.stop = stop;
      // Reject the spread first: entry must have one unambiguous limit direction.
      // No swing-direction assumption and no stop-order alternative.
      if(entry < context.bid) result.kind = FIBO_LIMIT_BUY;
      else if(entry > context.ask) result.kind = FIBO_LIMIT_SELL;
      else { result.error = "Spread"; return false; }
      bool buy = result.kind == FIBO_LIMIT_BUY;
      double tolerance = tick * 0.0000001;
      double distance = buy ? context.ask - entry : entry - context.bid;
      if(distance + tolerance < context.stop_distance) { result.error = "Near market"; return false; }
      if(!MathIsValidNumber(stop) || stop <= 0 || (buy && stop >= entry) || (!buy && stop <= entry))
      { result.error = "SL invalid"; return false; }
      if(MathAbs(entry - stop) + tolerance < context.stop_distance) { result.error = "SL too close"; return false; }
      // OrderCalcProfit accepts market BUY/SELL sides for estimation, while the
      // user-facing preview is always the corresponding pending LIMIT type.
      ENUM_ORDER_TYPE side = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double profit = 0;
      if(!OrderCalcProfit(side, _Symbol, minimum, entry, stop, profit)
         || !MathIsValidNumber(profit) || profit >= 0)
      { result.error = "Data?"; return false; }
      double raw = budget / (-profit) * minimum;
      if(!MathIsValidNumber(raw)) { result.error = "Data?"; return false; }
      int digits = context.volume_digits;
      double volume = NormalizeDouble(MathFloor(MathMin(raw, maximum) / step) * step, digits);
      if(!MathIsValidNumber(volume) || volume < minimum) { result.error = "Min lot"; return false; }
      // Verify final estimated loss after volume/price normalization. Never round
      // up to the minimum or leave an over-budget preview on screen.
      for(int attempt = 0; attempt < 2; attempt++)
      {
         if(volume < minimum) break;
         if(!OrderCalcProfit(side, _Symbol, volume, entry, stop, profit)
            || !MathIsValidNumber(profit) || profit >= 0)
         { result.error = "Data?"; return false; }
         if(-profit <= budget)
         { result.volume = volume; result.loss = -profit; result.error = ""; return true; }
         volume = NormalizeDouble(volume - step, digits);
      }
      result.error = volume < minimum ? "Min lot" : "Data?"; return false;
   }
};
#endif
