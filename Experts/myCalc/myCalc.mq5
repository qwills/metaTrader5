//+------------------------------------------------------------------+
//|                                                    myCalc.mq5    |
//|                                                     will_santoso |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      ""
#property version   "1.00"
#include "MMDialog.mqh"

input double risk_pct = 1.0; //Risk in %;

//--- initialize class
CMMDialog MMDialog(risk_pct);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create application dialog
   if(!MMDialog.Create(0, "myCalc", 0, 50, 125, 450, 450))
      return(INIT_FAILED);

//--- run application
   MMDialog.Run();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   MMDialog.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   MMDialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
