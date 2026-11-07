// Development-only CSwingDetector checks; not an installable script.

#include <Swing\SwingDetector.mqh>

int g_failures = 0;
int g_checks = 0;

void Check(const bool condition, const string description)
{
   g_checks++;
   if(condition)
      return;
   g_failures++;
   Print("FAIL: ", description);
}

void BuildBars(const double &highs[], const double &lows[], MqlRates &bars[])
{
   ArraySetAsSeries(bars, false);
   int count = ArraySize(highs);
   ArrayResize(bars, count);
   for(int i = 0; i < count; i++)
   {
      bars[i].time = (datetime)(1700000000 + i * 60);
      bars[i].high = highs[i];
      bars[i].low = lows[i];
      bars[i].open = (highs[i] + lows[i]) / 2.0;
      bars[i].close = bars[i].open;
      bars[i].tick_volume = 0;
      bars[i].real_volume = 0;
      bars[i].spread = 0;
   }
}

void RunChecks(void)
{
   CSwingDetector detector;
   SwingPoint point;
   point.price = 123.0;
   Check(detector.LeftBars() == 2 && detector.RightBars() == 2, "Default pivot 2/2");
   Check(detector.Count() == 0, "Starts empty");
   Check(!detector.LastHigh(point) && !detector.LastLow(point), "Empty lookups fail");
   Check(point.price == 123.0, "Failed lookup preserves output");
   Check(!detector.Configure(0, 2), "Reject zero left bars");
   Check(!detector.Configure(2, -1), "Reject negative right bars");
   Check(!detector.Configure(INT_MAX, 1), "Reject overflowing pivot width");
   Check(!detector.Configure(2, 2, (ENUM_SWING_EQUAL_POLICY)99), "Reject invalid tie policy");

   double highs[] = {2, 3, 7, 4, 3, 4, 6, 4, 3};
   double lows[] = {1, 2, 3, 2, 0, 2, 3, 2, 1};
   MqlRates bars[];
   BuildBars(highs, lows, bars);
   Check(detector.Update(bars), "Process chronological closed bars");
   Check(detector.Count() == 3, "Two highs and one low");
   Check(detector.GetSwing(0, point) && point.time == bars[2].time
         && point.price == 7 && point.type == SWING_HIGH && point.confirmed, "First high");
   Check(detector.GetSwing(1, point) && point.time == bars[4].time
         && point.price == 0 && point.type == SWING_LOW, "Middle low");
   Check(detector.LastHigh(point) && point.time == bars[6].time, "Most recent high");
   Check(detector.LastLow(point) && point.time == bars[4].time, "Most recent low");
   Check(!detector.GetSwing(-1, point) && !detector.GetSwing(3, point), "Index bounds");
   Check(detector.Update(bars) && detector.Count() == 3, "Repeated snapshot has no duplicates");
   Check(detector.Configure(2, 2) && detector.Count() == 3, "Same config retains results");
   Check(!detector.Configure(-1, 1) && detector.Count() == 3, "Invalid config is atomic");

   ArraySetAsSeries(bars, true);
   Check(detector.Update(bars) && detector.Count() == 3, "AS_SERIES produces same results");
   Check(detector.GetSwing(0, point) && point.price == 7, "AS_SERIES oldest swing first");
   Check(ArrayGetAsSeries(bars), "Detector does not change input indexing");
   ArraySetAsSeries(bars, false);
   datetime saved_time = bars[1].time;
   bars[1].time = bars[0].time;
   Check(!detector.Update(bars) && detector.Count() == 3, "Reject duplicate time atomically");
   bars[1].time = saved_time;
   double saved_high = bars[1].high;
   bars[1].high = EMPTY_VALUE;
   Check(!detector.Update(bars) && detector.Count() == 3, "Reject sentinel atomically");
   bars[1].high = bars[1].low - 1;
   Check(!detector.Update(bars) && detector.Count() == 3, "Reject high below low");
   bars[1].high = saved_high;
   bars[1].time = bars[0].time - 1;
   Check(!detector.Update(bars), "Reject reversed chronological times");

   // Pivot 2 is still unconfirmed with only one closed candle on its right.
   BuildBars(highs, lows, bars);
   ArrayResize(bars, 4);
   Check(detector.Update(bars) && detector.Count() == 0, "Wait for right-side confirmation");
   BuildBars(highs, lows, bars);
   ArrayResize(bars, 5);
   Check(detector.Update(bars) && detector.Count() == 1, "Confirm after second right candle closes");

   double tie_highs[] = {1, 5, 5, 1};
   double tie_lows[] = {0, 1, 1, 0};
   BuildBars(tie_highs, tie_lows, bars);
   Check(detector.Configure(1, 1) && detector.Count() == 0, "Changed config clears results");
   Check(detector.Update(bars) && !detector.LastHigh(point), "Strict ties rejected");
   Check(detector.Configure(1, 1, SWING_EQUAL_FIRST) && detector.Update(bars)
         && detector.LastHigh(point) && point.time == bars[1].time, "Earliest equal high");
   Check(detector.Configure(1, 1, SWING_EQUAL_LAST) && detector.Update(bars)
         && detector.LastHigh(point) && point.time == bars[2].time, "Latest equal high");
   double low_highs[] = {6, 5, 5, 6};
   double low_lows[] = {2, 0, 0, 2};
   BuildBars(low_highs, low_lows, bars);
   Check(detector.Configure(1, 1, SWING_EQUAL_FIRST) && detector.Update(bars)
         && detector.LastLow(point) && point.time == bars[1].time, "Earliest equal low");
   Check(detector.Configure(1, 1, SWING_EQUAL_LAST) && detector.Update(bars)
         && detector.LastLow(point) && point.time == bars[2].time, "Latest equal low");

   double outside_highs[] = {2, 5, 2};
   double outside_lows[] = {1, -1, 1};
   BuildBars(outside_highs, outside_lows, bars);
   detector.Configure(1, 1);
   Check(detector.Update(bars) && detector.Count() == 2, "Outside candle emits high and low");
   Check(detector.GetSwing(0, point) && point.type == SWING_HIGH, "Outside candle high first");
   Check(detector.GetSwing(1, point) && point.type == SWING_LOW && point.price == -1, "Outside candle low second");

   double consecutive_highs[] = {2, 5, 3, 6, 4};
   double consecutive_lows[] = {0, 1, 2, 3, 4};
   BuildBars(consecutive_highs, consecutive_lows, bars);
   Check(detector.Update(bars) && detector.Count() == 2, "Keep consecutive high pivots");
   Check(detector.GetSwing(0, point) && point.type == SWING_HIGH && point.price == 5,
         "First consecutive high retained");
   Check(detector.GetSwing(1, point) && point.type == SWING_HIGH && point.price == 6,
         "Second consecutive high retained");
   Check(!detector.LastLow(point), "Do not invent alternating lows");
   bars[0].time = 0;
   Check(!detector.Update(bars) && detector.Count() == 2, "Reject zero timestamp atomically");

   double flat_highs[] = {3, 3, 3, 3, 3};
   double flat_lows[] = {3, 3, 3, 3, 3};
   BuildBars(flat_highs, flat_lows, bars);
   Check(detector.Update(bars) && detector.Count() == 0, "Flat bars have no strict pivot");

   double monotonic_highs[] = {1, 2, 3, 4, 5};
   double monotonic_lows[] = {-1, 0, 1, 2, 3};
   BuildBars(monotonic_highs, monotonic_lows, bars);
   Check(detector.Update(bars) && detector.Count() == 0, "Monotonic window has no pivots");
   BuildBars(highs, lows, bars);
   Check(detector.Configure(1, 2) && detector.Update(bars)
         && detector.LastHigh(point) && point.time == bars[6].time, "Asymmetric left/right settings");
   detector.Reset();
   Check(detector.Count() == 0 && detector.RightBars() == 2, "Reset retains configuration");
   MqlRates empty[];
   Check(detector.Update(empty) && detector.Count() == 0, "Empty snapshot is valid empty result");
   PrintFormat("SwingDetector checks: %d checks, %d failure(s)", g_checks, g_failures);
}

void RunSwingDetectorChecks(void)
{
   RunChecks();
}
