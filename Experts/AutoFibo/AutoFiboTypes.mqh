#ifndef AUTO_FIBO_TYPES_MQH
#define AUTO_FIBO_TYPES_MQH

enum AutoFiboAnchorSource { ANCHOR_NONE, ANCHOR_PIVOT, ANCHOR_STRUCTURE };
enum AutoFiboAnalysisResult { FIBO_ANALYSIS_ERROR, FIBO_WAITING_PAIR, FIBO_PAIR_READY };
enum AutoFiboMethod { FIBO_PIVOT, FIBO_MARKET_STRUCTURE };

string AutoFiboTimeframeName(const int timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M2: return "M2";
      case PERIOD_M3: return "M3";
      case PERIOD_M4: return "M4";
      case PERIOD_M5: return "M5";
      case PERIOD_M6: return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H2: return "H2";
      case PERIOD_H3: return "H3";
      case PERIOD_H4: return "H4";
      case PERIOD_H6: return "H6";
      case PERIOD_H8: return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
   }
   return "";
}

bool IsAutoFiboTimeframe(const int timeframe) { return AutoFiboTimeframeName(timeframe) != ""; }

bool IsValidAutoFiboSettings(const int timeframe, const int left, const int right, const int method)
{
   return IsAutoFiboTimeframe(timeframe) && (method == FIBO_PIVOT || method == FIBO_MARKET_STRUCTURE)
          && left >= 1 && left <= 20 && right >= 1 && right <= 20;
}

#endif
