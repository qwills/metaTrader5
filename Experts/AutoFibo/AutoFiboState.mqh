#ifndef AUTO_FIBO_STATE_MQH
#define AUTO_FIBO_STATE_MQH
#include <_common\Fibo\FiboState.mqh>
#include "AutoFiboAnalysis.mqh"

struct AutoFiboSnapshot
{
   int timeframe, left, right, method, source, trend;
   bool edited, transient, pending;
   datetime bar;
   string key, status;
};

class CAutoFiboState
{
private:
   CFiboState m_model_state;
   string m_prefix;
   bool WriteText(const string name, const string text)
   {
      if(ObjectFind(0, name) < 0 && !ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
      return ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)
             && ObjectSetInteger(0, name, OBJPROP_HIDDEN, true)
             && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false)
             && ObjectSetString(0, name, OBJPROP_TEXT, text);
   }
   string PointText(const SwingPoint &p) const
   {
      return IntegerToString((long)p.time) + "," + StringFormat("%.17g", p.price)
             + "," + IntegerToString((int)p.type) + "," + IntegerToString(p.confirmed ? 1 : 0);
   }
   bool ReadPoint(const string text, SwingPoint &p) const
   {
      string f[];
      if(StringSplit(text, ',', f) != 4 || (f[2] != "0" && f[2] != "1")
         || (f[3] != "0" && f[3] != "1")) return false;
      p.time = (datetime)StringToInteger(f[0]); p.price = StringToDouble(f[1]);
      p.type = (ENUM_SWING_TYPE)StringToInteger(f[2]); p.confirmed = f[3] == "1";
      return p.time >= 0 && MathIsValidNumber(p.price) && p.price != EMPTY_VALUE;
   }
public:
   CAutoFiboState(void) { m_prefix = "AutoFibo."; m_model_state.SetPrefix(m_prefix); }
   bool Write(const CFiboModel &model, const AutoFiboSnapshot &s, const string symbol)
   {
      string text = "1|" + symbol + "|" + IntegerToString(s.timeframe)
                    + "|" + IntegerToString(s.left) + "|" + IntegerToString(s.right)
                    + "|" + IntegerToString(s.method) + "|" + IntegerToString(s.source)
                    + "|" + IntegerToString(s.trend) + "|" + IntegerToString(s.edited ? 1 : 0)
                    + "|" + IntegerToString(s.transient ? 1 : 0) + "|" + IntegerToString(s.pending ? 1 : 0)
                    + "|" + IntegerToString((long)s.bar) + "|" + (s.key == "" ? "_" : s.key);
      return m_model_state.Save(model, symbol) && WriteText(m_prefix + "AutoState", text)
             && ObjectSetString(0, m_prefix + "AutoState", OBJPROP_TOOLTIP, s.status);
   }
   bool Read(CFiboModel &model, AutoFiboSnapshot &s, const string symbol)
   {
      string f[];
      if(StringSplit(ObjectGetString(0, m_prefix + "AutoState", OBJPROP_TEXT), '|', f) != 13
         || f[0] != "1" || f[1] != symbol) return false;
      for(int i = 2; i <= 11; i++) if(f[i] != IntegerToString(StringToInteger(f[i]))) return false;
      s.timeframe = (int)StringToInteger(f[2]); s.left = (int)StringToInteger(f[3]); s.right = (int)StringToInteger(f[4]);
      s.method = (int)StringToInteger(f[5]); s.source = (int)StringToInteger(f[6]); s.trend = (int)StringToInteger(f[7]);
      if(!IsValidAutoFiboSettings(s.timeframe, s.left, s.right, s.method)
         || (s.source != ANCHOR_NONE && s.source != ANCHOR_PIVOT && s.source != ANCHOR_STRUCTURE)
         || (s.trend != STRUCTURE_UNCLEAR && s.trend != STRUCTURE_BULLISH && s.trend != STRUCTURE_BEARISH)
         || (f[8] != "0" && f[8] != "1") || (f[9] != "0" && f[9] != "1") || (f[10] != "0" && f[10] != "1")) return false;
      s.edited = f[8] == "1"; s.transient = f[9] == "1"; s.pending = f[10] == "1";
      s.bar = (datetime)StringToInteger(f[11]); s.key = f[12] == "_" ? "" : f[12];
      s.status = ObjectGetString(0, m_prefix + "AutoState", OBJPROP_TOOLTIP);
      CFiboModel candidate;
      if(s.bar < 0 || !m_model_state.Load(candidate, symbol) || (candidate.Locked() && s.pending)) return false;
      model.CopyFrom(candidate); return true;
   }
   bool SaveCheckpoint(const CAutoFiboAnalysis &model, const string context)
   {
      StructureCheckpoint state; model.GetCheckpoint(state);
      if(state.last_bar == 0) { ClearCheckpoint(); return true; }
      string data = PointText(state.high) + "|" + PointText(state.low) + "|" + PointText(state.protected_point) + "|" + IntegerToString(state.have_high ? 1 : 0) + "|" + IntegerToString(state.have_low ? 1 : 0) + "|" + IntegerToString(state.high_broken ? 1 : 0) + "|" + IntegerToString(state.low_broken ? 1 : 0) + "|" + IntegerToString(state.has_protection ? 1 : 0) + "|" + IntegerToString((long)state.high_relation) + "|" + IntegerToString((long)state.low_relation) + "|" + IntegerToString((long)state.high_confirmed) + "|" + IntegerToString((long)state.low_confirmed) + "|" + IntegerToString((long)state.protected_confirmed) + "|" + IntegerToString((long)state.last_bar) + "|" + IntegerToString((long)state.last_pivot) + "|" + StringFormat("%.17g", state.previous_close) + "|" + IntegerToString((long)state.trend);
      if(!WriteText(m_prefix + "Checkpoint.Runtime", data)) return false;
      int count = model.BreakCount() > 20 ? 20 : model.BreakCount();
      for(int i = 0; i < count; i++)
      {
         StructureBreak event;
         if(!model.GetBreak(model.BreakCount() - count + i, event)) return false;
         data = IntegerToString((long)event.time) + "|" + StringFormat("%.17g", event.close_price) + "|" + StringFormat("%.17g", event.break_high) + "|" + StringFormat("%.17g", event.break_low) + "|" + IntegerToString((long)event.kind) + "|" + IntegerToString((long)event.direction) + "|" + PointText(event.reference) + "|" + PointText(event.origin) + "|" + IntegerToString((long)event.reference_confirmed) + "|" + IntegerToString((long)event.origin_confirmed);
         if(!WriteText(m_prefix + "Checkpoint.Event." + IntegerToString(i), data)) return false;
      }
      return WriteText(m_prefix + "Checkpoint.Meta", context + "|" + IntegerToString(count));
   }
   bool LoadCheckpoint(CAutoFiboAnalysis &model, const string context)
   {
      string meta = ObjectGetString(0, m_prefix + "Checkpoint.Meta", OBJPROP_TEXT);
      string f[];
      int split = StringLen(context);
      if(StringSubstr(meta, 0, split + 1) != context + "|") return false;
      int count = (int)StringToInteger(StringSubstr(meta, split + 1));
      if(count < 0 || count > 20) return false;
      string data = ObjectGetString(0, m_prefix + "Checkpoint.Runtime", OBJPROP_TEXT);
      if(StringSplit(data, '|', f) != 17) return false;
      StructureCheckpoint state;
      if(!ReadPoint(f[0], state.high)) return false;
      if(!ReadPoint(f[1], state.low)) return false;
      if(!ReadPoint(f[2], state.protected_point)) return false;
      if(f[3] != "0" && f[3] != "1") return false;
      state.have_high = f[3] == "1";
      if(f[4] != "0" && f[4] != "1") return false;
      state.have_low = f[4] == "1";
      if(f[5] != "0" && f[5] != "1") return false;
      state.high_broken = f[5] == "1";
      if(f[6] != "0" && f[6] != "1") return false;
      state.low_broken = f[6] == "1";
      if(f[7] != "0" && f[7] != "1") return false;
      state.has_protection = f[7] == "1";
      state.high_relation = (int)StringToInteger(f[8]);
      state.low_relation = (int)StringToInteger(f[9]);
      state.high_confirmed = (datetime)StringToInteger(f[10]);
      state.low_confirmed = (datetime)StringToInteger(f[11]);
      state.protected_confirmed = (datetime)StringToInteger(f[12]);
      state.last_bar = (datetime)StringToInteger(f[13]);
      state.last_pivot = (datetime)StringToInteger(f[14]);
      state.previous_close = StringToDouble(f[15]);
      state.trend = (ENUM_STRUCTURE_TREND)StringToInteger(f[16]);
      StructureBreak events[];
      if(ArrayResize(events, count) != count) return false;
      for(int i = 0; i < count; i++)
      {
         data = ObjectGetString(0, m_prefix + "Checkpoint.Event." + IntegerToString(i), OBJPROP_TEXT);
         if(StringSplit(data, '|', f) != 10) return false;
      events[i].time = (datetime)StringToInteger(f[0]);
      events[i].close_price = StringToDouble(f[1]);
      events[i].break_high = StringToDouble(f[2]);
      events[i].break_low = StringToDouble(f[3]);
      events[i].kind = (ENUM_STRUCTURE_BREAK)StringToInteger(f[4]);
      events[i].direction = (ENUM_STRUCTURE_TREND)StringToInteger(f[5]);
      if(!ReadPoint(f[6], events[i].reference)) return false;
      if(!ReadPoint(f[7], events[i].origin)) return false;
      events[i].reference_confirmed = (datetime)StringToInteger(f[8]);
      events[i].origin_confirmed = (datetime)StringToInteger(f[9]);
      }
      return model.RestoreCheckpoint(state, events);
   }
   void ConsumeSnapshot(void) { m_model_state.Consume(); ObjectDelete(0, m_prefix + "AutoState"); }
   void ClearCheckpoint(void) { ObjectsDeleteAll(0, m_prefix + "Checkpoint."); }
};
#endif
