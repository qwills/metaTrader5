#ifndef MANUAL_FIBO_SETTINGS_MQH
#define MANUAL_FIBO_SETTINGS_MQH

// Positive IDs are also safe values for native CComboBox/CListView items.
enum ManualFiboTPMode { MANUAL_TP_NONE = 1, MANUAL_TP_SWING = 2, MANUAL_TP_RR = 3 };

class CManualFiboSettings
{
private:
   ManualFiboTPMode m_tp_mode;
   double m_rr;
public:
   CManualFiboSettings(void) { m_tp_mode = MANUAL_TP_SWING; m_rr = 2; }
   ManualFiboTPMode TPMode(void) const { return m_tp_mode; }
   double RR(void) const { return m_rr; }
   bool SetTPMode(const ManualFiboTPMode mode)
   {
      if(mode != MANUAL_TP_NONE && mode != MANUAL_TP_SWING && mode != MANUAL_TP_RR) return false;
      m_tp_mode = mode; return true;
   }
   bool SetRR(const double value)
   {
      if(!MathIsValidNumber(value) || value <= 0 || value == EMPTY_VALUE) return false;
      double rounded = NormalizeDouble(value, 8);
      if(!MathIsValidNumber(rounded) || rounded == EMPTY_VALUE || rounded <= 0 || MathAbs(value - rounded) > 0.000000000001) return false;
      m_rr = rounded; return true;
   }
   void CopyFrom(const CManualFiboSettings &other) { m_tp_mode = other.TPMode(); m_rr = other.RR(); }
   bool Save(void) const
   {
      string name = "manualFibo.TradeOptions";
      if(ObjectFind(0, name) < 0 && !ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
      return ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)
             && ObjectSetInteger(0, name, OBJPROP_HIDDEN, true)
             && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false)
             && ObjectSetString(0, name, OBJPROP_TEXT, "2|" + IntegerToString((int)m_tp_mode) + "|" + StringFormat("%.17g", m_rr));
   }
   bool Load(void)
   {
      string text = ObjectGetString(0, "manualFibo.TradeOptions", OBJPROP_TEXT);
      CManualFiboSettings candidate;
      // Older versions saved only the swing-end TP checkbox.
      if(text == "0" || text == "1") candidate.SetTPMode(text == "0" ? MANUAL_TP_NONE : MANUAL_TP_SWING);
      else
      {
         string fields[];
         if(StringSplit(text, '|', fields) != 3 || fields[0] != "2"
            || fields[1] != IntegerToString(StringToInteger(fields[1]))) return false;
         double rr = StringToDouble(fields[2]);
         if(fields[2] != StringFormat("%.17g", rr)
            || !candidate.SetTPMode((ManualFiboTPMode)StringToInteger(fields[1])) || !candidate.SetRR(rr)) return false;
      }
      CopyFrom(candidate); return true;
   }
   void Consume(void) { ObjectDelete(0, "manualFibo.TradeOptions"); }
};
#endif
