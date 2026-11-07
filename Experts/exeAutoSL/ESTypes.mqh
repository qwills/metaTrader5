//+------------------------------------------------------------------+
//|                                                      ESTypes.mqh  |
//+------------------------------------------------------------------+
#ifndef ES_TYPES_MQH
#define ES_TYPES_MQH

struct ESInputs
{
   double risk_pct;
   double risk_reward;
   double lot;
   ENUM_ORDER_TYPE order_type;
};

struct ESOrderPlan
{
   ESInputs inputs;
   double entry;
   double lot;
   double sl;
   double tp;
   double risk_usd;
   ENUM_ORDER_TYPE order_type;
   string side;
};

#endif
