#ifndef MANUAL_FIBO_RISK_MQH
#define MANUAL_FIBO_RISK_MQH
#include "ManualFiboModel.mqh"

// Strict decimal input: never accept a numeric prefix of malformed text.
bool ManualFiboParseNumber(string text, double &value)
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

struct ManualFiboLot
{
   double volume, loss, entry, stop;
   string error;
};

// Estimates only: no order placement and no trading state in the Fibonacci model.
class CManualFiboRisk
{
public:
   int VolumeDigits(const double step) const
   {
      double scaled = step;
      int digits = 0;
      while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 0.00000001)
      { scaled *= 10; digits++; }
      return digits;
   }
   double Budget(const CManualFiboModel &model) const
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double budget = equity * (model.RiskPercent() / 100.0);
      return MathIsValidNumber(equity) && equity > 0 && MathIsValidNumber(budget) && budget > 0 ? budget : 0;
   }
   bool Calculate(const CManualFiboModel &model, const int index, ManualFiboLot &result) const
   {
      result.volume = 0; result.loss = 0; result.entry = 0; result.stop = 0; result.error = "-";
      if(!model.Ready() || !model.Enabled(index)) return false;
      double budget = Budget(model);
      if(budget <= 0) { result.error = "Risk?"; return false; }
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!MathIsValidNumber(step) || !MathIsValidNumber(minimum) || !MathIsValidNumber(maximum)
         || !MathIsValidNumber(tick) || step <= 0 || minimum <= 0 || maximum < minimum || tick <= 0)
      { result.error = "Data?"; return false; }
      double entry = model.Price(index), stop = model.StopPrice(index);
      if(entry == EMPTY_VALUE || stop == EMPTY_VALUE || !MathIsValidNumber(entry) || !MathIsValidNumber(stop))
      { result.error = "SL?"; return false; }
      entry = NormalizeDouble(MathRound(entry / tick) * tick, _Digits);
      stop = NormalizeDouble(MathRound(stop / tick) * tick, _Digits);
      bool buy = model.EndPrice() > model.StartPrice();
      if(!MathIsValidNumber(entry) || !MathIsValidNumber(stop) || entry <= 0 || stop <= 0
         || (buy && stop >= entry) || (!buy && stop <= entry))
      { result.error = "SL invalid"; return false; }
      result.entry = entry; result.stop = stop;
      ENUM_ORDER_TYPE side = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double profit = 0;
      if(!OrderCalcProfit(side, _Symbol, minimum, entry, stop, profit)
         || !MathIsValidNumber(profit) || profit >= 0)
      { result.error = "Data?"; return false; }
      double raw = budget / (-profit) * minimum;
      if(!MathIsValidNumber(raw)) { result.error = "Data?"; return false; }
      int digits = VolumeDigits(step);
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
      result.error = "Min lot"; return false;
   }
};
#endif
