#ifndef AUTO_FIBO_CHART_MQH
#define AUTO_FIBO_CHART_MQH
#include <Fibo\FiboChart.mqh>
#include "AutoFiboAnalysis.mqh"

class CAutoFiboChart : public CFiboChart
{
private:
   string m_keys[];
   bool m_changed;
   bool Label(const int slot, const string name, const datetime time, const double price,
              const string text, const string tooltip, const int anchor)
   {
      string key = IntegerToString((long)time) + "," + StringFormat("%.17g", price)
                   + "," + text + "," + tooltip + "," + IntegerToString(anchor);
      bool exists = ObjectFind(0, name) >= 0;
      if(exists && m_keys[slot] == key) return true;
      m_keys[slot] = ""; // A failed/recreated label must never reuse its old success key.
      m_changed = true;
      if(!exists)
      { if(!ObjectCreate(0, name, OBJ_TEXT, 0, time, price)) return false; }
      else if(!ObjectMove(0, name, 0, time, price)) return false;
      if(!ObjectSetString(0, name, OBJPROP_TEXT, text)
         || !ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip)
         || !ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack)
         || !ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8)
         || !ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor)
         // Background plane keeps annotations behind the native dialog.
         // ZORDER controls mouse priority, not visual stacking.
         || !ObjectSetInteger(0, name, OBJPROP_BACK, true)
         || !ObjectSetInteger(0, name, OBJPROP_ZORDER, 0)
         || !ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false)
         || !ObjectSetInteger(0, name, OBJPROP_HIDDEN, true)) return false;
      m_keys[slot] = key;
      return true;
   }
   bool RemoveLabel(const int slot, const string name)
   {
      if(ObjectFind(0, name) >= 0)
      { m_changed = true; if(!ObjectDelete(0, name)) return false; }
      m_keys[slot] = ""; return true;
   }
public:
   CAutoFiboChart(void) { SetPrefix("AutoFibo."); ResetCache(); }
   void ResetCache(void)
   {
      ArrayResize(m_keys, 50);
      for(int i = 0; i < 50; i++) m_keys[i] = "";
   }
   void ClearStructure(void) { ObjectsDeleteAll(0, m_prefix + "Structure."); ResetCache(); }
   bool DrawStructure(const CAutoFiboAnalysis &model)
   {
      m_changed = false;
      bool ok = true; int count = model.StructureCount(), slot = 0;
      int first = count > 30 ? count - 30 : 0;
      for(int i = first; i < count; i++, slot++)
      {
         StructurePoint point; if(!model.GetStructurePoint(i, point)) return false;
         if(!Label(slot, m_prefix + "Structure." + IntegerToString(slot), point.swing.time,
                   point.swing.price, StructureLabelName(point.label), "",
                   point.swing.type == SWING_HIGH ? ANCHOR_LOWER : ANCHOR_UPPER)) ok = false;
      }
      for(int i = slot; i < 30; i++)
         if(!RemoveLabel(i, m_prefix + "Structure." + IntegerToString(i))) ok = false;
      count = model.BreakCount(); first = count > 20 ? count - 20 : 0; slot = 0;
      for(int i = first; i < count; i++, slot++)
      {
         StructureBreak event; if(!model.GetBreak(i, event)) return false;
         if(!Label(30 + slot, m_prefix + "Structure.Break." + IntegerToString(slot), event.time,
                   event.close_price, StructureBreakName(event.kind) + " " + StructureTrendName(event.direction),
                   "Swing acuan: " + DoubleToString(event.reference.price, _Digits),
                   event.direction == STRUCTURE_BULLISH ? ANCHOR_LOWER : ANCHOR_UPPER)) ok = false;
      }
      for(int i = slot; i < 20; i++)
         if(!RemoveLabel(30 + i, m_prefix + "Structure.Break." + IntegerToString(i))) ok = false;
      if(m_changed) ChartRedraw();
      return ok;
   }
};
#endif
