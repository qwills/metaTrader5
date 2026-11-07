#ifndef MANUAL_FIBO_STATE_MQH
#define MANUAL_FIBO_STATE_MQH
#include "ManualFiboModel.mqh"

// A hidden chart-local handoff for timeframe changes, isolated from myFibo.
class CManualFiboState
{
public:
   bool Save(const CManualFiboModel &model, const string symbol)
   {
      string name = "manualFibo.State";
      string text = "2|" + symbol + "|" + IntegerToString(model.Mask())
                    + "|" + IntegerToString(model.Locked() ? 1 : 0)
                    + "|" + IntegerToString(model.Ready() ? 1 : 0)
                    + "|" + IntegerToString((long)model.StartTime())
                    + "|" + StringFormat("%.17g", model.StartPrice())
                    + "|" + IntegerToString((long)model.EndTime())
                    + "|" + StringFormat("%.17g", model.EndPrice());
      if(ObjectFind(0, name) < 0 && !ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
      return ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)
             && ObjectSetInteger(0, name, OBJPROP_HIDDEN, true)
             && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false)
             && ObjectSetString(0, name, OBJPROP_TEXT, text);
   }
   bool Load(CManualFiboModel &model, const string symbol)
   {
      string fields[];
      string text = ObjectGetString(0, "manualFibo.State", OBJPROP_TEXT);
      if(StringSplit(text, '|', fields) != 9 || (fields[0] != "1" && fields[0] != "2") || fields[1] != symbol
         || (fields[3] != "0" && fields[3] != "1") || (fields[4] != "0" && fields[4] != "1")) return false;
      int mask = (int)StringToInteger(fields[2]);
      if(fields[2] != IntegerToString(mask)) return false;
      if(fields[5] != IntegerToString(StringToInteger(fields[5]))
         || fields[7] != IntegerToString(StringToInteger(fields[7]))
         || fields[6] != StringFormat("%.17g", StringToDouble(fields[6]))
         || fields[8] != StringFormat("%.17g", StringToDouble(fields[8]))) return false;
      // Schema 1 used bits 0/7 for the removed 0%/100% levels.
      if(fields[0] == "1")
      {
         if(mask < 0 || mask > 255) return false;
         mask = (mask >> 1) & 63;
      }
      CManualFiboModel candidate;
      if(!candidate.SetMask(mask)) return false;
      candidate.SetLocked(fields[3] == "1");
      if(fields[4] == "1"
         && !candidate.SetAnchors((datetime)StringToInteger(fields[5]), StringToDouble(fields[6]),
                                  (datetime)StringToInteger(fields[7]), StringToDouble(fields[8]))) return false;
      model.CopyFrom(candidate); return true;
   }
   void Consume(void) { ObjectDelete(0, "manualFibo.State"); }
};
#endif
