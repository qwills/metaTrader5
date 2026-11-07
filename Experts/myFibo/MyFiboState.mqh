#ifndef MY_FIBO_STATE_MQH
#define MY_FIBO_STATE_MQH
#include "MyFiboAuto.mqh"

struct MyFiboSnapshot
{
   int state;
   bool has_swing;
   datetime start_time;
   double start_price;
   datetime end_time;
   double end_price;
   string status;
   int mode, timeframe, left, right;
   bool anchor_locked;
   datetime auto_bar;
   string auto_key;
   bool auto_force_pending;
   int structure_trend;
   int auto_method;
   int anchor_source;
   bool anchor_edited, transient_status;
   datetime pick_time;
   double pick_price;
};


// Chart-local persistence only. No GUI, calculation or controller globals.
class CMyFiboState
{
private:
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
   CMyFiboState(void) { m_prefix = "myFibo."; }
   bool Write(const MyFiboSnapshot &snapshot, const string symbol)
   {
      string encoded = "6|" + symbol + "|" + IntegerToString((int)snapshot.state)
                       + "|" + IntegerToString(snapshot.has_swing ? 1 : 0)
                       + "|" + IntegerToString((long)snapshot.start_time)
                       + "|" + StringFormat("%.17g", snapshot.start_price)
                       + "|" + IntegerToString((long)snapshot.end_time)
                       + "|" + StringFormat("%.17g", snapshot.end_price)
                       + "|" + IntegerToString((int)snapshot.mode)
                       + "|" + IntegerToString((int)snapshot.timeframe)
                       + "|" + IntegerToString(snapshot.left) + "|" + IntegerToString(snapshot.right)
                       + "|" + IntegerToString(snapshot.anchor_locked ? 1 : 0)
                       + "|" + IntegerToString((long)snapshot.auto_bar)
                       + "|" + (snapshot.auto_key == "" ? "_" : snapshot.auto_key)
                       + "|" + IntegerToString(snapshot.auto_force_pending ? 1 : 0)
                       + "|" + IntegerToString((int)snapshot.structure_trend)
                       + "|" + IntegerToString((int)snapshot.auto_method)
                       + "|" + IntegerToString(snapshot.anchor_source)
                       + "|" + IntegerToString(snapshot.anchor_edited ? 1 : 0)
                       + "|" + IntegerToString((long)snapshot.pick_time)
                       + "|" + StringFormat("%.17g", snapshot.pick_price)
                       + "|" + IntegerToString(snapshot.transient_status ? 1 : 0);
      return WriteText(m_prefix + "State", encoded)
             && ObjectSetString(0, m_prefix + "State", OBJPROP_TOOLTIP, snapshot.status);
   }
   bool Read(MyFiboSnapshot &snapshot, const string symbol)
   {
      string encoded; string fields[];
      if(!ObjectGetString(0, m_prefix + "State", OBJPROP_TEXT, 0, encoded)
         || StringSplit(encoded, '|', fields) < 18 || fields[1] != symbol
         || !((fields[0] == "5" && ArraySize(fields) == 18)
              || (fields[0] == "6" && ArraySize(fields) == 23))) return false;
      snapshot.state = (int)StringToInteger(fields[2]);
      snapshot.has_swing = fields[3] == "1";
      snapshot.start_time = (datetime)StringToInteger(fields[4]);
      snapshot.start_price = StringToDouble(fields[5]);
      snapshot.end_time = (datetime)StringToInteger(fields[6]);
      snapshot.end_price = StringToDouble(fields[7]);
      snapshot.status = ObjectGetString(0, m_prefix + "State", OBJPROP_TOOLTIP);
      snapshot.mode = FIBO_MANUAL;
      snapshot.timeframe = PERIOD_H1;
      snapshot.left = 2; snapshot.right = 2;
      snapshot.anchor_locked = false;
      snapshot.auto_bar = 0;
      snapshot.auto_key = "";
      snapshot.auto_force_pending = false;
      snapshot.structure_trend = STRUCTURE_UNCLEAR;
      snapshot.auto_method = FIBO_PIVOT;
      snapshot.mode = (int)StringToInteger(fields[8]);
      snapshot.timeframe = (int)StringToInteger(fields[9]);
      snapshot.left = (int)StringToInteger(fields[10]); snapshot.right = (int)StringToInteger(fields[11]);
      if(fields[12] != "0" && fields[12] != "1") return false;
      snapshot.anchor_locked = fields[12] == "1";
      snapshot.auto_bar = (datetime)StringToInteger(fields[13]);
      snapshot.auto_key = fields[14] == "_" ? "" : fields[14];
      if((fields[15] != "0" && fields[15] != "1")
         || (fields[16] != "0" && fields[16] != "1" && fields[16] != "2")
         || (fields[17] != "0" && fields[17] != "1")) return false;
      snapshot.auto_force_pending = fields[15] == "1";
      snapshot.structure_trend = (int)StringToInteger(fields[16]);
      snapshot.auto_method = (int)StringToInteger(fields[17]);
      snapshot.anchor_source = ANCHOR_NONE; // Older schema did not record provenance.
      snapshot.anchor_edited = false; snapshot.transient_status = false;
      snapshot.pick_time = snapshot.state == SELECT_END ? snapshot.start_time : 0;
      snapshot.pick_price = snapshot.state == SELECT_END ? snapshot.start_price : 0;
      if(fields[0] == "6")
      {
         if((fields[18] != "0" && fields[18] != "1" && fields[18] != "2" && fields[18] != "3")
            || (fields[19] != "0" && fields[19] != "1") || (fields[22] != "0" && fields[22] != "1")) return false;
         snapshot.anchor_source = (int)StringToInteger(fields[18]); snapshot.anchor_edited = fields[19] == "1";
         snapshot.pick_time = (datetime)StringToInteger(fields[20]); snapshot.pick_price = StringToDouble(fields[21]);
         snapshot.transient_status = fields[22] == "1";
      }
      if(!IsValidMyFiboSettings(snapshot.mode, snapshot.timeframe, snapshot.left, snapshot.right, snapshot.auto_method)
         || snapshot.auto_bar < 0
         || (snapshot.auto_force_pending && (snapshot.mode != FIBO_AUTO || snapshot.anchor_locked))
         || ((snapshot.mode == FIBO_AUTO || snapshot.anchor_locked) && snapshot.state != IDLE))
         return false;
      if(snapshot.state < IDLE || snapshot.state > SELECT_END
         || !MathIsValidNumber(snapshot.start_price) || !MathIsValidNumber(snapshot.end_price)
         || (fields[3] != "0" && fields[3] != "1"))
         return false;
      if(snapshot.has_swing)
      {
         CFibonacci check;
         return snapshot.start_time > 0 && snapshot.end_time > 0
                && (snapshot.state != SELECT_END || (snapshot.pick_time > 0 && MathIsValidNumber(snapshot.pick_price) && snapshot.pick_price != EMPTY_VALUE))
                && check.SetAnchors(snapshot.start_price, snapshot.end_price);
      }
      return snapshot.state != SELECT_END
             || (snapshot.pick_time > 0 && MathIsValidNumber(snapshot.pick_price) && snapshot.pick_price != EMPTY_VALUE);

   }
   bool SaveCheckpoint(const CMyFiboAuto &model, const string context)
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
   bool LoadCheckpoint(CMyFiboAuto &model, const string context)
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
   void ConsumeSnapshot(void) { ObjectDelete(0, m_prefix + "State"); }
   void ClearCheckpoint(void) { ObjectsDeleteAll(0, m_prefix + "Checkpoint."); }
};
#endif // MY_FIBO_STATE_MQH
