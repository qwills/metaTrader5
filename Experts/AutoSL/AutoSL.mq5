//+------------------------------------------------------------------+
//|                                                    AutoSL.mq5      |
//|                                                     will_santoso  |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      ""
#property version   "1.00"

#include "ASDialog.mqh"

input double risk_pct = 1.0; //Risk in %;
input double risk_reward = 2.0; //RiskReward;
input long magic_number = 240624; //Magic number;

//--- initialize class
CAutoSLDialog AutoSLDialog(risk_pct, risk_reward, magic_number);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create application dialog
   if(!AutoSLDialog.Create(0, "AutoSL", 0, 50, 125, 450, 450))
      return(INIT_FAILED);

//--- run application
   AutoSLDialog.Run();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   AutoSLDialog.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   AutoSLDialog.Refresh();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   AutoSLDialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
