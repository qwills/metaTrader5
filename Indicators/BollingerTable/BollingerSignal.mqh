#ifndef BOLLINGER_TABLE_SIGNAL_MQH
#define BOLLINGER_TABLE_SIGNAL_MQH

enum ENUM_BB_SIGNAL
{
   BB_EQUAL,
   BB_ABOVE,
   BB_BELOW,
   BB_GOLDEN_CROSS,
   BB_DEAD_CROSS
};

// Compare the previous closed bar and the current bar with their own middle bands.
ENUM_BB_SIGNAL BollingerSignal(const double previous_close,
                              const double previous_middle,
                              const double latest_close,
                              const double latest_middle)
{
   if(latest_close > latest_middle)
      return previous_close <= previous_middle ? BB_GOLDEN_CROSS : BB_ABOVE;
   if(latest_close < latest_middle)
      return previous_close >= previous_middle ? BB_DEAD_CROSS : BB_BELOW;
   return BB_EQUAL;
}

#endif
