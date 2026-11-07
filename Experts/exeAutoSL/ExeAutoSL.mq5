//+------------------------------------------------------------------+
//|                                                    ExeAutoSL.mq5      |
//|                                                     will_santoso  |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      ""
#property version   "1.00"

#include "ESDialog.mqh"

input double risk_pct = 1.0; //Risk in %;
input double risk_reward = 2.0; //RiskReward;
input long magic_number = 240624; //Magic number;

//--- initialize class
CExeAutoSLDialog ExeAutoSLDialog(risk_pct, risk_reward, magic_number);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create application dialog
   if(!ExeAutoSLDialog.Create(0, "ExeAutoSL", 0, 50, 125, 590, 450))
      return(INIT_FAILED);

//--- run application
   ExeAutoSLDialog.Run();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ExeAutoSLDialog.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ExeAutoSLDialog.Refresh();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   ExeAutoSLDialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
