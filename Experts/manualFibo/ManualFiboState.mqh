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
      string text = "4|" + symbol + "|" + IntegerToString(model.Mask())
                    + "|" + IntegerToString(model.Locked() ? 1 : 0)
                    + "|" + IntegerToString(model.Ready() ? 1 : 0)
                    + "|" + IntegerToString((long)model.StartTime())
                    + "|" + StringFormat("%.17g", model.StartPrice())
                    + "|" + IntegerToString((long)model.EndTime())
                    + "|" + StringFormat("%.17g", model.EndPrice());
      text += "|" + StringFormat("%.17g", model.RiskPercent()) + "|" + IntegerToString(model.CustomStops());
      for(int i = 0; i < MANUAL_FIBO_RATIOS; i++) text += "|" + StringFormat("%.17g", model.RawStop(i));
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
      int count = StringSplit(text, '|', fields);
      if(count < 9 || !(((fields[0] == "1" || fields[0] == "2") && count == 9)
                       || ((fields[0] == "3" || fields[0] == "4") && count == 17)) || fields[1] != symbol
         || (fields[3] != "0" && fields[3] != "1") || (fields[4] != "0" && fields[4] != "1")) return false;
      int mask = (int)StringToInteger(fields[2]);
      if(fields[2] != IntegerToString(mask)) return false;
      if(fields[5] != IntegerToString(StringToInteger(fields[5]))
         || fields[7] != IntegerToString(StringToInteger(fields[7]))
         || fields[6] != StringFormat("%.17g", StringToDouble(fields[6]))
         || fields[8] != StringFormat("%.17g", StringToDouble(fields[8]))) return false;
      if(fields[4] == "0" && (fields[5] != "0" || fields[6] != "0" || fields[7] != "0" || fields[8] != "0"))
         return false; // An empty drawing cannot carry stale/invalid anchors.
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
      if(fields[0] == "3" || fields[0] == "4")
      {
         double risk = StringToDouble(fields[9]);
         int custom = (int)StringToInteger(fields[10]);
         if(fields[9] != StringFormat("%.17g", risk) || !MathIsValidNumber(risk) || risk < 0 || risk > 100) return false;
         // Earlier releases allowed more precision than the textbox displays.
         // Migrate that setting without discarding valid anchors/SL overrides.
         if(fields[0] == "3") risk = NormalizeDouble(risk, 8);
         if(!candidate.SetRiskPercent(risk) || fields[10] != IntegerToString(custom) || custom < 0 || custom >= (1 << MANUAL_FIBO_RATIOS)) return false;
         for(int i = 0; i < MANUAL_FIBO_RATIOS; i++)
         {
            double stop = StringToDouble(fields[11 + i]);
            if(fields[11 + i] != StringFormat("%.17g", stop)) return false;
            if((custom & (1 << i)) != 0) { if(!candidate.SetStop(i, stop)) return false; }
            else if(stop != 0) return false;
         }
      }
      model.CopyFrom(candidate); return true;
   }
   void Consume(void) { ObjectDelete(0, "manualFibo.State"); }
};
#endif
