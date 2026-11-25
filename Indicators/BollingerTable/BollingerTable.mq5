#property copyright "will_santoso"
#property version   "1.08"
#property description "Bollinger Bands with a current-candle multi-timeframe middle-band table."
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3
#property indicator_label1 "Middle BB"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_label2 "Upper BB"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_label3 "Lower BB"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrGreen

#include "BollingerSignal.mqh"

input int                InpPeriod       = 20;          // BB period
input double             InpDeviation    = 2.0;         // Standard deviations
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // BB applied price
input color              InpUpperColor   = clrRed;      // Upper BB line color
input color              InpMiddleColor  = clrDodgerBlue;// Middle BB line color
input color              InpLowerColor   = clrGreen;    // Lower BB line color
input int                InpTableX       = 20;          // Table left offset (pixels)
input int                InpTableY       = 125;         // Table top offset (pixels)
input int                InpFontSize     = 10;          // Table font size (8..16)
input bool               InpShowM1       = false;       // Show M1
input bool               InpShowM5       = false;       // Show M5
input bool               InpShowM15      = true;        // Show M15
input bool               InpShowM30      = true;        // Show M30
input bool               InpShowH1       = true;        // Show H1
input bool               InpShowH4       = true;        // Show H4
input bool               InpShowD1       = false;       // Show D1
input bool               InpShowW1       = false;       // Show W1
input bool               InpShowMN1      = false;       // Show MN1

double MiddleBuffer[], UpperBuffer[], LowerBuffer[];
double CopyMiddle[], CopyUpper[], CopyLower[];
MqlRates TableRates[];
int ChartHandle = INVALID_HANDLE;
ENUM_TIMEFRAMES Timeframes[9] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                               PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
string TimeframeNames[9] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
bool TimeframeEnabled[9];
int SelectedCount = 0;
string Prefix = "", TableKey = "";
string LastValidText[9];
color LastValidColor[9];
datetime LastValidTime[9];
bool RowFresh[9];
bool TableNeedsRepair = false;
bool LayoutCheckPending = false;
datetime LastRepairLog = 0;
bool RestorePending = false, RestoreRetry = false;
datetime NextAuditTime = 0;
string QueuedText[9], QueuedTooltip[9], QueuedCache[9];
color QueuedColor[9];
bool QueuedColorKnown[9];

string LeaseKey(const string prefix) { return prefix + "Released"; }

bool SetLease(const string prefix, const double released)
{
   string key = LeaseKey(prefix);
   // Temporary terminal globals are independent of the graphical command queue.
   if(!GlobalVariableCheck(key) && !GlobalVariableTemp(key)) return false;
   return GlobalVariableSet(key, released) > 0;
}

void DeleteTable(const string prefix)
{
   // Queue only our known objects. Do not flush the chart with ObjectsDeleteAll.
   string names[5] = {"Background", "Title", "TF", "Middle", "State"};
   for(int i = 0; i < 5; i++) ObjectDelete(0, prefix + names[i]);
   for(int i = 0; i < 9; i++)
   {
      string number = IntegerToString(i);
      ObjectDelete(0, prefix + "TF" + number);
      ObjectDelete(0, prefix + "Value" + number);
      ObjectDelete(0, prefix + "Cache" + number);
   }
   GlobalVariableDel(LeaseKey(prefix));
}

void ForgetQueuedDisplay()
{
   for(int i = 0; i < 9; i++)
   {
      QueuedText[i] = ""; QueuedTooltip[i] = ""; QueuedCache[i] = "";
      QueuedColorKnown[i] = false;
   }
}

void ConfigureTimeframes()
{
   TimeframeEnabled[0] = InpShowM1;
   TimeframeEnabled[1] = InpShowM5;
   TimeframeEnabled[2] = InpShowM15;
   TimeframeEnabled[3] = InpShowM30;
   TimeframeEnabled[4] = InpShowH1;
   TimeframeEnabled[5] = InpShowH4;
   TimeframeEnabled[6] = InpShowD1;
   TimeframeEnabled[7] = InpShowW1;
   TimeframeEnabled[8] = InpShowMN1;
   SelectedCount = 0;
   for(int i = 0; i < 9; i++)
      if(TimeframeEnabled[i]) SelectedCount++;
}

string TableSettingsKey()
{
   // Schema, not release version. Chart timeframe is deliberately excluded.
   string key = "BBT2|" + IntegerToString(InpPeriod) + "|" +
                DoubleToString(InpDeviation, 16) + "|" + IntegerToString(InpAppliedPrice) + "|" +
                IntegerToString(InpTableX) + "|" + IntegerToString(InpTableY) + "|" +
                IntegerToString(InpFontSize) + "|" + IntegerToString(InpUpperColor) + "|" +
                IntegerToString(InpMiddleColor) + "|" + IntegerToString(InpLowerColor) + "|";
   for(int i = 0; i < 9; i++) key += TimeframeEnabled[i] ? "1" : "0";
   return key + "|";
}

bool SetText(const string name, const ENUM_OBJECT_PROPERTY_STRING property, const string value)
{
   return ObjectSetString(0, name, property, value);
}

bool SetNumber(const string name, const ENUM_OBJECT_PROPERTY_INTEGER property, const long value)
{
   return ObjectSetInteger(0, name, property, value);
}

bool EnsureObject(const string name, const ENUM_OBJECT type)
{
   bool exists = ObjectFind(0, name) >= 0;
   if(exists && ObjectGetInteger(0, name, OBJPROP_TYPE) != type)
   {
      if(!ObjectDelete(0, name)) return false;
      exists = false;
   }
   return exists || ObjectCreate(0, name, type, 0, 0, 0);
}

bool CreateLabel(const string suffix, const string text, const int x, const int y)
{
   string name = Prefix + suffix;
   if(!EnsureObject(name, OBJ_LABEL)) return false;
   bool ok = SetNumber(name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ok = SetNumber(name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER) && ok;
   ok = SetNumber(name, OBJPROP_XDISTANCE, x) && ok;
   ok = SetNumber(name, OBJPROP_YDISTANCE, y) && ok;
   ok = SetNumber(name, OBJPROP_FONTSIZE, InpFontSize) && ok;
   ok = SetNumber(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS) && ok;
   ok = SetNumber(name, OBJPROP_COLOR, clrWhite) && ok;
   ok = SetNumber(name, OBJPROP_SELECTABLE, false) && ok;
   ok = SetNumber(name, OBJPROP_HIDDEN, true) && ok;
   ok = SetText(name, OBJPROP_FONT, "Consolas") && ok;
   ok = SetText(name, OBJPROP_TEXT, text) && ok;
   return ok;
}

bool CreateHiddenLabel(const string suffix, const string text)
{
   string name = Prefix + suffix;
   if(!EnsureObject(name, OBJ_LABEL)) return false;
   // Hide before assigning metadata, so intermediate chart paints cannot show it.
   if(!SetNumber(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)) return false;
   bool ok = SetNumber(name, OBJPROP_HIDDEN, true);
   ok = SetNumber(name, OBJPROP_SELECTABLE, false) && ok;
   return SetText(name, OBJPROP_TEXT, text) && ok;
}

bool ValidNumberText(const string text)
{
   int length = StringLen(text), digits = 0, dots = 0;
   if(length == 0 || length > 64) return false;
   for(int i = 0; i < length; i++)
   {
      ushort ch = StringGetCharacter(text, i);
      if(ch >= '0' && ch <= '9') digits++;
      else if(ch == '.' && dots == 0) dots++;
      else if(ch != '-' || i != 0) return false;
   }
   double value = StringToDouble(text);
   return digits > 0 && MathIsValidNumber(value) && value != EMPTY_VALUE;
}

bool ValidIntegerText(const string text)
{
   if(StringLen(text) == 0 || StringLen(text) > 18) return false;
   for(int i = 0; i < StringLen(text); i++)
      if(StringGetCharacter(text, i) < '0' || StringGetCharacter(text, i) > '9') return false;
   return true;
}

bool ValidSignalColor(const color value)
{
   return value == clrLimeGreen || value == clrRed || value == clrDodgerBlue ||
          value == clrOrange || value == clrSilver;
}

string EncodeRow(const int row)
{
   if(LastValidText[row] == "") return "1|0|0|Loading...";
   return "1|" + IntegerToString(LastValidTime[row]) + "|" +
          IntegerToString(LastValidColor[row]) + "|" + LastValidText[row];
}

bool DecodeRow(const string text, string &value, color &tint, datetime &updated)
{
   string fields[];
   if(StringSplit(text, '|', fields) != 4 || fields[0] != "1" ||
      !ValidIntegerText(fields[1]) || !ValidIntegerText(fields[2])) return false;
   if(fields[1] == "0" && fields[2] == "0" && fields[3] == "Loading...")
   {
      value = ""; tint = clrSilver; updated = 0;
      return true;
   }
   long raw_color = StringToInteger(fields[2]);
   updated = (datetime)StringToInteger(fields[1]);
   if(raw_color > 0xFFFFFF || !ValidSignalColor((color)raw_color) || updated <= 0 ||
      updated > TimeLocal() || !ValidNumberText(fields[3])) return false;
   value = fields[3]; tint = (color)raw_color;
   return true;
}

bool RestoreTable()
{
   RestoreRetry = false;
   string pending_key = "pending|" + TableKey;
   string active_key = "active|" + TableKey;
   // Backward traversal remains valid when an invalid candidate is deleted.
   for(int n = ObjectsTotal(0, 0, OBJ_LABEL) - 1; n >= 0; n--)
   {
      string name = ObjectName(0, n, 0, OBJ_LABEL);
      int length = StringLen(name);
      if(StringFind(name, "BBT_") != 0 || length < 5 ||
         StringSubstr(name, length - 5) != "State") continue;
      string marker = ObjectGetString(0, name, OBJPROP_TEXT);
      string candidate = StringSubstr(name, 0, length - 5);
      bool legacy_pending = StringFind(marker, pending_key) == 0;
      string lease = LeaseKey(candidate);
      bool has_lease = GlobalVariableCheck(lease);
      bool released = has_lease && GlobalVariableGet(lease) == 1;
      if(!legacy_pending && !(released && StringFind(marker, active_key) == 0)) continue;
      if(legacy_pending && has_lease && !released) continue;
      string values[9]; color tints[9]; datetime updated[9];
      bool valid = marker == (legacy_pending ? pending_key : active_key) + _Symbol;
      for(int i = 0; i < 9 && valid; i++)
      {
         if(!TimeframeEnabled[i]) continue;
         string cache = candidate + "Cache" + IntegerToString(i);
         valid = ObjectFind(0, cache) >= 0 &&
                 DecodeRow(ObjectGetString(0, cache, OBJPROP_TEXT), values[i], tints[i], updated[i]);
      }
      // Claim one released instance. Live same-settings instances keep lease=0.
      if(valid && legacy_pending && !has_lease && !SetLease(candidate, 1))
      { RestoreRetry = true; return false; }
      if(valid)
      {
         if(!GlobalVariableSetOnCondition(lease, 0, 1))
         {
            if(GlobalVariableCheck(lease) && GlobalVariableGet(lease) == 1)
            { RestoreRetry = true; return false; }
            continue; // another instance claimed it; never delete its table
         }
         Prefix = candidate;
         for(int i = 0; i < 9; i++)
         {
            if(!TimeframeEnabled[i]) continue;
            LastValidText[i] = values[i]; LastValidColor[i] = tints[i];
            LastValidTime[i] = updated[i]; RowFresh[i] = false;
         }
         return true;
      }
      DeleteTable(candidate);
      // Continue searching: another matching pending instance may be valid.
      int remaining = ObjectsTotal(0, 0, OBJ_LABEL);
      if(n > remaining) n = remaining;
   }
   return false;
}

string RowText(const int row)
{
   if(LastValidText[row] == "") return "Loading...";
   datetime now = TimeLocal();
   bool stale = !RowFresh[row] && (now < LastValidTime[row] || now - LastValidTime[row] >= 3);
   return LastValidText[row] + (stale ? " *" : "");
}

string RowTooltip(const int row)
{
   if(LastValidText[row] == "") return "Waiting for initial data";
   return "Updated " + TimeToString(LastValidTime[row], TIME_DATE | TIME_SECONDS) +
          (RowFresh[row] ? " | Live" : " | Waiting for data (* = cached)");
}

bool CreateTable()
{
   TableNeedsRepair = true;
   int row_height = InpFontSize * 2 + 4;
   string background = Prefix + "Background";
   if(!EnsureObject(background, OBJ_RECTANGLE_LABEL)) return false;
   bool ok = SetNumber(background, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ok = SetNumber(background, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS) && ok;
   ok = SetNumber(background, OBJPROP_XDISTANCE, InpTableX) && ok;
   ok = SetNumber(background, OBJPROP_YDISTANCE, InpTableY) && ok;
   ok = SetNumber(background, OBJPROP_XSIZE, InpFontSize * 22) && ok;
   ok = SetNumber(background, OBJPROP_YSIZE, row_height * (SelectedCount + 2) + 12) && ok;
   ok = SetNumber(background, OBJPROP_BGCOLOR, C'24,28,34') && ok;
   ok = SetNumber(background, OBJPROP_BORDER_TYPE, BORDER_FLAT) && ok;
   ok = SetNumber(background, OBJPROP_COLOR, clrDimGray) && ok;
   ok = SetNumber(background, OBJPROP_SELECTABLE, false) && ok;
   ok = SetNumber(background, OBJPROP_HIDDEN, true) && ok;
   int left = InpTableX + 10, value_x = left + InpFontSize * 6, top = InpTableY + 6;
   ok = CreateLabel("Title", "BB", left, top) && ok;
   ok = CreateLabel("TF", "TF", left, top + row_height) && ok;
   ok = CreateLabel("Middle", "Middle BB", value_x, top + row_height) && ok;
   int row = 0;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i]) continue;
      int y = top + (row + 2) * row_height;
      ok = CreateLabel("TF" + IntegerToString(i), TimeframeNames[i], left, y) && ok;
      string suffix = "Value" + IntegerToString(i), name = Prefix + suffix;
      ok = CreateLabel(suffix, RowText(i), value_x, y) && ok;
      ok = SetNumber(name, OBJPROP_COLOR, LastValidText[i] == "" ? clrSilver : LastValidColor[i]) && ok;
      ok = SetText(name, OBJPROP_TOOLTIP, RowTooltip(i)) && ok;
      ok = CreateHiddenLabel("Cache" + IntegerToString(i), EncodeRow(i)) && ok;
      row++;
   }
   ok = CreateHiddenLabel("State", "active|" + TableKey + _Symbol) && ok;
   LayoutCheckPending = true;
   TableNeedsRepair = !ok;
   return ok;
}

bool TableObjectsReady()
{
   string names[5] = {"Background", "Title", "TF", "Middle", "State"};
   for(int i = 0; i < 5; i++)
      if(ObjectFind(0, Prefix + names[i]) < 0 ||
         ObjectGetInteger(0, Prefix + names[i], OBJPROP_TYPE) != (i == 0 ? OBJ_RECTANGLE_LABEL : OBJ_LABEL))
         return false;
   if(ObjectGetInteger(0, Prefix + "State", OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS) return false;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i]) continue;
      string suffixes[3] = {"TF", "Value", "Cache"};
      for(int k = 0; k < 3; k++)
      {
         string name = Prefix + suffixes[k] + IntegerToString(i);
         if(ObjectFind(0, name) < 0 || ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_LABEL) return false;
         if(k == 2 && ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES) != OBJ_NO_PERIODS) return false;
      }
   }
   return true;
}

bool LabelLayoutReady(const string suffix, const int x, const int y)
{
   string name = Prefix + suffix;
   return ObjectGetInteger(0, name, OBJPROP_XDISTANCE) == x &&
          ObjectGetInteger(0, name, OBJPROP_YDISTANCE) == y &&
          ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES) == OBJ_ALL_PERIODS;
}

bool TableLayoutReady()
{
   // One deferred layout check after a build, never a readback after each setter.
   int height = InpFontSize * 2 + 4, left = InpTableX + 10, top = InpTableY + 6;
   int value_x = left + InpFontSize * 6;
   string background = Prefix + "Background";
   if(ObjectGetInteger(0, background, OBJPROP_XDISTANCE) != InpTableX ||
      ObjectGetInteger(0, background, OBJPROP_YDISTANCE) != InpTableY ||
      ObjectGetInteger(0, background, OBJPROP_XSIZE) != InpFontSize * 22 ||
      ObjectGetInteger(0, background, OBJPROP_YSIZE) != height * (SelectedCount + 2) + 12 ||
      ObjectGetInteger(0, background, OBJPROP_TIMEFRAMES) != OBJ_ALL_PERIODS ||
      !LabelLayoutReady("Title", left, top) || !LabelLayoutReady("TF", left, top + height) ||
      !LabelLayoutReady("Middle", value_x, top + height)) return false;
   int row = 0;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i]) continue;
      int y = top + (row + 2) * height;
      if(!LabelLayoutReady("TF" + IntegerToString(i), left, y) ||
         !LabelLayoutReady("Value" + IntegerToString(i), value_x, y)) return false;
      row++;
   }
   return true;
}

color SignalColor(const ENUM_BB_SIGNAL signal)
{
   switch(signal)
   {
      case BB_ABOVE:        return clrLimeGreen;
      case BB_BELOW:        return clrRed;
      case BB_GOLDEN_CROSS: return clrDodgerBlue;
      case BB_DEAD_CROSS:   return clrOrange;
      default:             return clrSilver;
   }
}

// Middle BB is an SMA. Compute both middles and closes from ONE rates snapshot,
// rather than combining CopyRates and independently scheduled indicator buffers.
// Only period+1 bars are read, never the full multi-timeframe history.
double AppliedPrice(const MqlRates &bar)
{
   switch(InpAppliedPrice)
   {
      case PRICE_OPEN:     return bar.open;
      case PRICE_HIGH:     return bar.high;
      case PRICE_LOW:      return bar.low;
      case PRICE_MEDIAN:   return bar.high / 2.0 + bar.low / 2.0;
      case PRICE_TYPICAL:  return bar.high / 3.0 + bar.low / 3.0 + bar.close / 3.0;
      case PRICE_WEIGHTED: return bar.high / 4.0 + bar.low / 4.0 + bar.close / 2.0;
      default:             return bar.close;
   }
}

void AddPrice(const double value, double &sum, double &correction)
{
   // Compensated summation avoids turning a flat price series into a false
   // above/below signal through repeated fractional additions.
   double term = value - correction;
   double next = sum + term;
   correction = (next - sum) - term;
   sum = next;
}

bool ReadTableRow(const int row, string &text, color &tint)
{
   int count = InpPeriod + 1;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) ||
      CopyRates(_Symbol, Timeframes[row], 0, count, TableRates) != count ||
      !SeriesInfoInteger(_Symbol, Timeframes[row], SERIES_SYNCHRONIZED) ||
      TableRates[InpPeriod].time != (datetime)SeriesInfoInteger(_Symbol, Timeframes[row], SERIES_LASTBAR_DATE))
      return false;
   double previous = 0, current = 0, previous_correction = 0, current_correction = 0;
   for(int i = 0; i < count; i++)
   {
      double value = AppliedPrice(TableRates[i]);
      if(!MathIsValidNumber(value) || value == EMPTY_VALUE ||
         !MathIsValidNumber(TableRates[i].close) || TableRates[i].close == EMPTY_VALUE ||
         TableRates[i].time <= 0 || (i > 0 && TableRates[i].time <= TableRates[i-1].time)) return false;
      if(i < InpPeriod) AddPrice(value, previous, previous_correction);
      if(i > 0) AddPrice(value, current, current_correction);
   }
   previous /= InpPeriod;
   current /= InpPeriod;
   if(!MathIsValidNumber(previous) || !MathIsValidNumber(current)) return false;
   text = DoubleToString(current, _Digits);
   tint = SignalColor(BollingerSignal(TableRates[InpPeriod-1].close, previous,
                                      TableRates[InpPeriod].close, current));
   return ValidNumberText(text);
}

void RefreshTable()
{
   if(SelectedCount == 0) return;
   if(RestorePending)
   {
      // Restore only after init has finished; a timeframe switch never waits on UI.
      RestorePending = false;
      if(!RestoreTable())
      {
         if(RestoreRetry) { RestorePending = true; return; }
         Prefix = "BBT_" + IntegerToString(ChartID()) + "_" + IntegerToString((long)GetMicrosecondCount()) + "_";
         SetLease(Prefix, 0);
         TableNeedsRepair = true;
      }
      ForgetQueuedDisplay();
      NextAuditTime = 0;
   }
   if(Prefix == "") return;
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i]) continue;
      string text; color tint;
      RowFresh[i] = ReadTableRow(i, text, tint);
      if(RowFresh[i])
      {
         LastValidText[i] = text; LastValidColor[i] = tint; LastValidTime[i] = TimeLocal();
      }
   }
   datetime now = TimeLocal();
   bool audit = LayoutCheckPending || TableNeedsRepair || now >= NextAuditTime || now < NextAuditTime - 5;
   bool ready = !audit || TableObjectsReady();
   bool deferred_failure = false;
   if(LayoutCheckPending)
   {
      ready = ready && TableLayoutReady();
      deferred_failure = !ready;
      LayoutCheckPending = false;
   }
   if(audit)
   {
      // Reconcile dropped commands/external edits in a bounded five-second audit.
      // Ordinary one-second refreshes need no ObjectFind/Get/ObjectsTotal calls.
      if(ready)
      {
         for(int i = 0; i < 9; i++)
         {
            if(!TimeframeEnabled[i]) continue;
            string name = Prefix + "Value" + IntegerToString(i);
            QueuedText[i] = ObjectGetString(0, name, OBJPROP_TEXT);
            QueuedColor[i] = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
            QueuedColorKnown[i] = true;
            QueuedTooltip[i] = ObjectGetString(0, name, OBJPROP_TOOLTIP);
            QueuedCache[i] = ObjectGetString(0, Prefix + "Cache" + IntegerToString(i), OBJPROP_TEXT);
         }
      }
      NextAuditTime = now + 5;
   }
   bool changed = TableNeedsRepair || !ready;
   if(changed)
   {
      // GUI failures are retried here; they must never disable BB plot buffers.
      bool queued = CreateTable();
      ForgetQueuedDisplay();
      if((!queued || deferred_failure) && (LastRepairLog == 0 || TimeLocal() - LastRepairLog >= 30))
      {
         PrintFormat("BollingerTable: table repair incomplete; retrying (error=%d)", GetLastError());
         LastRepairLog = TimeLocal();
      }
      ChartRedraw(0);
      return; // Verify the batch on the next timer, after chart rendering.
   }
   for(int i = 0; i < 9; i++)
   {
      if(!TimeframeEnabled[i]) continue;
      string name = Prefix + "Value" + IntegerToString(i), text = RowText(i);
      color tint = LastValidText[i] == "" ? clrSilver : LastValidColor[i];
      if(QueuedText[i] != text && ObjectSetString(0, name, OBJPROP_TEXT, text))
      { QueuedText[i] = text; changed = true; }
      if((!QueuedColorKnown[i] || QueuedColor[i] != tint) && ObjectSetInteger(0, name, OBJPROP_COLOR, tint))
      { QueuedColor[i] = tint; QueuedColorKnown[i] = true; changed = true; }
      string tooltip = RowTooltip(i), checkpoint = EncodeRow(i);
      if(QueuedTooltip[i] != tooltip && ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip))
         QueuedTooltip[i] = tooltip;
      if(QueuedCache[i] != checkpoint && ObjectSetString(0, Prefix + "Cache" + IntegerToString(i), OBJPROP_TEXT, checkpoint))
         QueuedCache[i] = checkpoint;
   }
   if(changed) ChartRedraw(0);
}

int InitFailure(const string stage, const int result = INIT_FAILED)
{
   PrintFormat("BollingerTable: initialization failed at %s (error=%d)", stage, GetLastError());
   return result;
}

int OnInit()
{
   ChartHandle = INVALID_HANDLE;
   Prefix = "";
   TableNeedsRepair = false;
   LayoutCheckPending = false; LastRepairLog = 0;
   RestorePending = false; RestoreRetry = false; NextAuditTime = 0; ForgetQueuedDisplay();
   ArrayInitialize(LastValidTime, 0);
   for(int i = 0; i < 9; i++) { LastValidText[i] = ""; RowFresh[i] = false; }
   ConfigureTimeframes();
   TableKey = TableSettingsKey();
   RestorePending = SelectedCount > 0;
   if(InpPeriod < 2 || InpPeriod >= 2147483647 || !MathIsValidNumber(InpDeviation) || InpDeviation <= 0 ||
      InpTableX < 0 || InpTableY < 0 || InpFontSize < 8 || InpFontSize > 16)
      return InitFailure("inputs", INIT_PARAMETERS_INCORRECT);
   if(!SetIndexBuffer(0, MiddleBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(1, UpperBuffer, INDICATOR_DATA) ||
      !SetIndexBuffer(2, LowerBuffer, INDICATOR_DATA)) return InitFailure("plot buffers");
   ArraySetAsSeries(MiddleBuffer, false); ArraySetAsSeries(UpperBuffer, false);
   ArraySetAsSeries(LowerBuffer, false); ArraySetAsSeries(TableRates, false);
   for(int i = 0; i < 3; i++)
      if(!PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, InpPeriod - 1)) return InitFailure("plot draw begin");
   if(!PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpMiddleColor) ||
      !PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpUpperColor) ||
      !PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpLowerColor)) return InitFailure("plot colors");
   if(!IndicatorSetInteger(INDICATOR_DIGITS, _Digits) ||
      !IndicatorSetString(INDICATOR_SHORTNAME, "BollingerTable (" + IntegerToString(InpPeriod) + ", " +
                         DoubleToString(InpDeviation, 2) + ")")) return InitFailure("indicator properties");
   ChartHandle = iBands(_Symbol, _Period, InpPeriod, 0, InpDeviation, InpAppliedPrice);
   if(ChartHandle == INVALID_HANDLE) return InitFailure("iBands handle");
   if(SelectedCount > 0)
   {
      // No graphical API, history read or restoration in init.
      if(!EventSetTimer(1)) return InitFailure("timer");
   }
   PrintFormat("BollingerTable 1.08: initialized (%s, %s, %d table rows)",
               _Symbol, EnumToString(_Period), SelectedCount);
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   int previous = prev_calculated <= rates_total ? prev_calculated : 0;
   if(previous == 0)
   {
      ArrayInitialize(MiddleBuffer, EMPTY_VALUE); ArrayInitialize(UpperBuffer, EMPTY_VALUE);
      ArrayInitialize(LowerBuffer, EMPTY_VALUE);
   }
   else if(previous < rates_total)
   {
      ArrayFill(MiddleBuffer, previous, rates_total - previous, EMPTY_VALUE);
      ArrayFill(UpperBuffer, previous, rates_total - previous, EMPTY_VALUE);
      ArrayFill(LowerBuffer, previous, rates_total - previous, EMPTY_VALUE);
   }
   if(rates_total < InpPeriod || BarsCalculated(ChartHandle) < rates_total) return previous;
   int count = previous > 0 ? rates_total - previous + 1 : rates_total;
   if(CopyBuffer(ChartHandle, 0, 0, count, CopyMiddle) != count ||
      CopyBuffer(ChartHandle, 1, 0, count, CopyUpper) != count ||
      CopyBuffer(ChartHandle, 2, 0, count, CopyLower) != count) return previous;
   int start = rates_total - count;
   for(int i = 0; i < count; i++)
   {
      MiddleBuffer[start+i] = CopyMiddle[i]; UpperBuffer[start+i] = CopyUpper[i];
      LowerBuffer[start+i] = CopyLower[i];
   }
   return rates_total;
}

void OnTimer() { RefreshTable(); }

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(reason == REASON_CHARTCHANGE)
   {
      // No graphical calls, reads, deletion or redraw during a timeframe change.
      // The last periodic checkpoint is validated by the next instance's timer.
      if(Prefix != "" && !SetLease(Prefix, 1))
         PrintFormat("BollingerTable: could not release table checkpoint (error=%d)", GetLastError());
   }
   else
   {
      // Removal/init failure before the first timer still owns one released table.
      if(Prefix == "" && RestorePending) RestoreTable();
      if(Prefix != "") DeleteTable(Prefix);
   }
   if(ChartHandle != INVALID_HANDLE) { IndicatorRelease(ChartHandle); ChartHandle = INVALID_HANDLE; }
}
