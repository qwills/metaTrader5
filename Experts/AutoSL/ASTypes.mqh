//+------------------------------------------------------------------+
//|                                                      ASTypes.mqh  |
//+------------------------------------------------------------------+
#ifndef AS_TYPES_MQH
#define AS_TYPES_MQH

struct ASInputs
{
   double risk_pct;
   double risk_reward;
   double entry;
   double lot;
};

struct ASOrderPlan
{
   ASInputs inputs;
   double entry;
   double lot;
   double sl;
   double tp;
   double risk_usd;
   string side;
};

#endif
