#ifndef MY_FIBO_TYPES_MQH
#define MY_FIBO_TYPES_MQH

enum SelectionState { IDLE, SELECT_START, SELECT_END };
enum MyFiboAnchorSource { ANCHOR_NONE, ANCHOR_MANUAL, ANCHOR_PIVOT, ANCHOR_STRUCTURE };
enum MyFiboAnalysisResult { FIBO_ANALYSIS_ERROR, FIBO_WAITING_PAIR, FIBO_PAIR_READY };
enum MyFiboMode { FIBO_MANUAL, FIBO_AUTO };
enum MyFiboAutoMethod { FIBO_PIVOT, FIBO_MARKET_STRUCTURE };

bool IsMyFiboTimeframe(const int timeframe)
{
   return timeframe == PERIOD_M1 || timeframe == PERIOD_M5 || timeframe == PERIOD_M15
          || timeframe == PERIOD_M30 || timeframe == PERIOD_H1 || timeframe == PERIOD_H4
          || timeframe == PERIOD_D1 || timeframe == PERIOD_W1 || timeframe == PERIOD_MN1;
}

bool IsValidMyFiboSettings(const int mode, const int timeframe, const int left, const int right,
                           const int method = FIBO_PIVOT)
{
   return (mode == FIBO_MANUAL || mode == FIBO_AUTO) && IsMyFiboTimeframe(timeframe)
          && (method == FIBO_PIVOT || method == FIBO_MARKET_STRUCTURE)
          && left >= 1 && left <= 20 && right >= 1 && right <= 20;
}

#endif // MY_FIBO_TYPES_MQH
