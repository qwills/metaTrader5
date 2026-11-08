// Development-only test fixtures; not an installable MetaTrader script.
#include <_common\Structure\MarketStructure.mqh>

int g_failures = 0;
int g_checks = 0;
void Check(const bool ok, const string message)
{
   g_checks++;
   if(!ok) { g_failures++; Print("FAIL: ", message); }
}
void Put(SwingPoint &points[], const int index, const datetime time,
         const double price, const ENUM_SWING_TYPE type)
{
   points[index].time = time;
   points[index].price = price;
   points[index].type = type;
   points[index].confirmed = true;
}
void BreakFixture(MqlRates &bars[], const int count, const bool mirror = false)
{
   double highs[] = {10,12,11,13,12,15,14,16,15,17,14,12,13,11,12,10};
   double lows[] = {8,9,7,10,9,12,11,13,12,14,9,8,9,7,8,5};
   double closes[] = {9,11,10,12,11,14,12.5,15.5,14,16.5,10,9,12,8,11,6};
   ArraySetAsSeries(bars, false); ArrayResize(bars, count);
   for(int i = 0; i < count; i++)
   {
      bars[i].time = 1000 + i * 60;
      bars[i].high = mirror ? 30 - lows[i] : highs[i];
      bars[i].low = mirror ? 30 - highs[i] : lows[i];
      bars[i].close = mirror ? 30 - closes[i] : closes[i];
      bars[i].open = bars[i].close;
   }
}
void RunBreakChecks(void)
{
   CMarketStructure structure;
   MqlRates bars[];
   StructureBreak event;
   SwingPoint protected_point;
   Check(structure.Trend() == STRUCTURE_UNCLEAR && structure.BreakCount() == 0,
         "Break state initially unclear");
   Check(!structure.ProtectedSwing(protected_point), "No initial protection");
   BreakFixture(bars, 7);
   Check(structure.Analyze(bars, 1, 1) && structure.Trend() == STRUCTURE_BULLISH,
         "HH and HL establish bullish structure");
   Check(structure.BreakCount() == 0, "No retrospective break on unconfirmed reference");
   Check(structure.ProtectedSwing(protected_point) && protected_point.price == 9,
         "Initial bullish protection is confirmed HL");
   BreakFixture(bars, 8);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 1, "First bullish BOS");
   Check(structure.GetBreak(0, event) && event.kind == STRUCTURE_BOS
         && event.direction == STRUCTURE_BULLISH && event.time == bars[7].time
         && event.reference.time == bars[5].time && event.reference_confirmed == bars[6].time,
         "BOS reference known before breaking candle");
   Check(event.origin.price == 9 && event.origin.time == bars[4].time
         && event.origin_confirmed == bars[5].time, "BOS records opposing origin known before break");
   BreakFixture(bars, 10);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 2, "Second continuation BOS");
   Check(structure.ProtectedSwing(protected_point) && protected_point.price == 11,
         "BOS promotes last available opposing pivot, not future low");
   Check(structure.GetBreak(1, event) && event.origin.price == 11
         && event.origin_confirmed < event.time, "Second BOS freezes causal impulse origin");
   BreakFixture(bars, 11);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 3, "Opposing protection break is CHoCH");
   Check(structure.GetBreak(2, event) && event.kind == STRUCTURE_CHOCH
         && event.direction == STRUCTURE_BEARISH && event.reference.price == 11,
         "CHoCH uses protected low instead of newer unprotected low");
   Check(structure.Trend() == STRUCTURE_UNCLEAR && !structure.ProtectedSwing(protected_point),
         "CHoCH clears direction until fresh structure agrees");
   BreakFixture(bars, 16);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 4
         && structure.Trend() == STRUCTURE_BEARISH, "Fresh LH/LL confirms bearish structure");
   Check(structure.GetBreak(3, event) && event.kind == STRUCTURE_BOS
         && event.direction == STRUCTURE_BEARISH && event.time == bars[15].time,
         "Bearish BOS after reversal confirmation");
   for(int i = 0; i < structure.BreakCount(); i++)
      Check(structure.GetBreak(i, event) && event.reference_confirmed < event.time,
            "Every break is causal");
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 4, "Reanalysis does not duplicate events");
   ArraySetAsSeries(bars, true);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 4
         && structure.GetBreak(3, event) && event.time == 1900, "AS_SERIES break replay");
   ArraySetAsSeries(bars, false);
   bars[15].close = EMPTY_VALUE;
   Check(!structure.Analyze(bars, 1, 1) && structure.BreakCount() == 4, "Invalid close preserves state");
   bars[15].close = bars[15].high + 1;
   Check(!structure.Analyze(bars, 1, 1), "Close outside candle rejected");
   BreakFixture(bars, 8); bars[7].close = 15;
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 0, "Wick-only and equal close are not BOS");
   bars[7].close = 14.5;
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 0, "Wick without close crossing ignored");
   BreakFixture(bars, 8); ArrayResize(bars, 10);
   for(int i = 8; i < 10; i++)
   {
      bars[i].time = 1000 + i * 60; bars[i].high = 9 + i;
      bars[i].low = 6 + i; bars[i].close = 8 + i; bars[i].open = bars[i].close;
   }
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 1,
         "Several closes beyond one pivot emit only one BOS");
   BreakFixture(bars, 11); bars[10].close = 11;
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 2
         && structure.Trend() == STRUCTURE_BULLISH, "Equal protection close is not CHoCH");
   BreakFixture(bars, 16, true);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 4
         && structure.Trend() == STRUCTURE_BULLISH, "Mirrored bearish to bullish sequence");
   Check(structure.GetBreak(0, event) && event.kind == STRUCTURE_BOS
         && event.direction == STRUCTURE_BEARISH, "Bearish continuation symmetry");
   Check(structure.GetBreak(2, event) && event.kind == STRUCTURE_CHOCH
         && event.direction == STRUCTURE_BULLISH, "Bullish CHoCH symmetry");
   event.close_price = 123;
   Check(!structure.GetBreak(-1, event) && !structure.GetBreak(4, event)
         && event.close_price == 123, "Break lookup failure preserves output");
   Check(!structure.Analyze(bars, 0, 1) && structure.BreakCount() == 4, "Invalid settings preserve events");
   // Every historical prefix must produce the exact same event prefix as a
   // replay with later candles present (no use of future pivot confirmation).
   CMarketStructure full;
   BreakFixture(bars, 16); full.Analyze(bars, 1, 1);
   for(int size = 1; size <= 16; size++)
   {
      BreakFixture(bars, size);
      Check(structure.Analyze(bars, 1, 1), "Prefix analysis succeeds");
      int expected = 0;
      for(int i = 0; i < full.BreakCount(); i++)
      {
         full.GetBreak(i, event);
         if(event.time <= bars[size - 1].time) expected++;
      }
      Check(structure.BreakCount() == expected, "Historical prefix has no look-ahead events");
      for(int i = 0; i < expected; i++)
      {
         StructureBreak past;
         full.GetBreak(i, event); structure.GetBreak(i, past);
         Check(past.time == event.time && past.kind == event.kind
               && past.direction == event.direction && past.reference.time == event.reference.time,
               "Future candles cannot rewrite an earlier break");
      }
   }
   MqlRates original[];
   BreakFixture(original, 16);
   ArrayResize(bars, 31);
   for(int i = 0; i < 31; i++)
   {
      int a = i / 2;
      bars[i].time = 1000 + i * 30;
      bars[i].high = i % 2 == 0 ? original[a].high : (original[a].high + original[a + 1].high) / 2;
      bars[i].low = i % 2 == 0 ? original[a].low : (original[a].low + original[a + 1].low) / 2;
      bars[i].close = i % 2 == 0 ? original[a].close : (original[a].close + original[a + 1].close) / 2;
      bars[i].open = bars[i].close;
   }
   Check(structure.Analyze(bars, 2, 2) && structure.BreakCount() == 4,
         "Two-right-candle confirmation replay");
   Check(structure.GetBreak(0, event) && event.reference_confirmed == bars[12].time
         && event.time == bars[14].time, "Right-bars setting determines actual availability");
   ArrayResize(bars, 0);
   Check(structure.Analyze(bars, 1, 1) && structure.BreakCount() == 0
         && structure.Trend() == STRUCTURE_UNCLEAR, "Empty analysis clears break state");
}
void RunStreamingChecks(void)
{
   MqlRates full_bars[];
   MqlRates window[];
   CMarketStructure stream, reference;
   CSwingDetector detector;
   detector.Configure(1, 1);
   for(int size = 6; size <= 16; size++)
   {
      BreakFixture(full_bars, size);
      int first = size - 6;
      ArrayResize(window, 6);
      for(int i = 0; i < 6; i++) window[i] = full_bars[first + i];
      Check(detector.Update(window) && stream.AnalyzeDetected(window, detector, size != 6),
            "Streaming consumes one validated detector snapshot");
      Check(reference.Analyze(full_bars, 1, 1) && stream.Trend() == reference.Trend(),
            "Sliding-window trend matches fixed-origin replay");
      if(reference.BreakCount() > 0)
      {
         StructureBreak actual, expected;
         Check(stream.GetBreak(stream.BreakCount() - 1, actual)
               && reference.GetBreak(reference.BreakCount() - 1, expected)
               && actual.time == expected.time && actual.origin.time == expected.origin.time,
               "Sliding-window BOS origin remains causal and stable");
      }
   }
   StructureCheckpoint checkpoint;
   stream.GetCheckpoint(checkpoint);
   StructureBreak events[];
   ArrayResize(events, stream.BreakCount());
   for(int i = 0; i < stream.BreakCount(); i++) stream.GetBreak(i, events[i]);
   CMarketStructure restored;
   Check(restored.RestoreCheckpoint(checkpoint, events) && restored.Trend() == stream.Trend(),
         "Checkpoint restores confirmed structure regime");
   checkpoint.previous_close = EMPTY_VALUE;
   Check(!restored.RestoreCheckpoint(checkpoint, events), "Invalid checkpoint rejected");
}
void RunMarketStructureChecks(void)
{
   RunBreakChecks();
   RunStreamingChecks();
   CMarketStructure structure;
   StructurePoint point;
   point.swing.price = 123;
   Check(structure.Count() == 0, "Initially empty");
   Check(!structure.GetPoint(0, point) && point.swing.price == 123, "Failed lookup preserves output");
   SwingPoint points[];
   ArrayResize(points, 10);
   Put(points, 0, 10, 10, SWING_HIGH);
   Put(points, 1, 20, 5, SWING_LOW);
   Put(points, 2, 30, 12, SWING_HIGH);
   Put(points, 3, 40, 6, SWING_LOW);
   Put(points, 4, 50, 11, SWING_HIGH);
   Put(points, 5, 60, 4, SWING_LOW);
   Put(points, 6, 70, 11, SWING_HIGH);
   Put(points, 7, 80, 4, SWING_LOW);
   Put(points, 8, 90, 13, SWING_HIGH);
   Put(points, 9, 100, 14, SWING_HIGH);
   Check(structure.Update(points) && structure.Count() == 10, "Classify complete snapshot");
   for(int i = 0; i < 10; i++)
   {
      string expected = i == 0 ? "H" : i == 1 ? "L" : i == 2 ? "HH" : i == 3 ? "HL"
                        : i == 4 ? "LH" : i == 5 ? "LL" : i == 6 ? "EH" : i == 7 ? "EL" : "HH";
      Check(structure.GetPoint(i, point) && StructureLabelName(point.label) == expected,
            "Classifies each pivot including consecutive highs");
   }
   ArraySetAsSeries(points, true);
   Check(structure.Update(points) && structure.GetPoint(9, point) && point.swing.price == 14,
         "AS_SERIES gives chronological output");
   ArraySetAsSeries(points, false);
   points[9].confirmed = false;
   Check(!structure.Update(points) && structure.Count() == 10, "Unconfirmed input rejected atomically");
   points[9].confirmed = true; points[9].time = 1;
   Check(!structure.Update(points) && structure.Count() == 10, "Unsorted snapshot rejected");
   points[9].time = 90;
   Check(!structure.Update(points), "Duplicate same-kind candle rejected");
   points[9].time = 100; points[9].price = EMPTY_VALUE;
   Check(!structure.Update(points), "Empty price rejected");
   points[9].price = 14; points[9].time = 0;
   Check(!structure.Update(points), "Zero timestamp rejected");
   points[9].time = 100;
   // Ambiguous high/low must not affect the next comparison reference.
   ArrayResize(points, 5);
   Put(points, 0, 10, 10, SWING_HIGH);
   Put(points, 1, 20, 20, SWING_HIGH);
   Put(points, 2, 20, -5, SWING_LOW);
   Put(points, 3, 30, 11, SWING_HIGH);
   Put(points, 4, 40, -1, SWING_LOW);
   Check(structure.Update(points) && structure.Count() == 3, "Outside candle skipped");
   Check(structure.GetPoint(1, point) && point.label == STRUCTURE_HH, "Ambiguous high is not reference");
   Check(structure.GetPoint(2, point) && point.label == STRUCTURE_L, "Ambiguous low is not reference");
   Put(points, 1, 20, -5, SWING_LOW); Put(points, 2, 20, 20, SWING_HIGH);
   Check(structure.Update(points) && structure.Count() == 3, "Both outside-candle orderings skipped");
   Check(!structure.GetPoint(-1, point) && !structure.GetPoint(3, point), "Lookup bounds");
   ArrayResize(points, 0);
   Check(structure.Update(points) && structure.Count() == 0, "Empty snapshot clears output");
   CSwingDetector detector;
   Check(structure.Update(detector) && structure.Count() == 0, "Empty detector adapter");
   MqlRates bars[];
   ArrayResize(bars, 5);
   for(int i = 0; i < 5; i++)
   { bars[i].time = 100 + i; bars[i].high = i == 2 ? 5 : 2; bars[i].low = 1; }
   Check(detector.Update(bars) && structure.Update(detector) && structure.Count() == 1,
         "Consumes confirmed detector pivots directly");
   Check(structure.GetPoint(0, point) && point.label == STRUCTURE_H && point.swing.time == 102,
         "First detector high is seed H");
   structure.Reset(); Check(structure.Count() == 0, "Reset");
   PrintFormat("MarketStructure checks: %d checks, %d failure(s)", g_checks, g_failures);
}
