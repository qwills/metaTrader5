// Development-only CFibonacci checks; no script entry point or input demo.

#include <_common\Fibo\Fibonacci.mqh>


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

bool Near(const double actual, const double expected)
{
   return actual != EMPTY_VALUE && MathAbs(actual - expected) < 0.00000001;
}

void RunFibonacciChecks(void)
{
   CFibonacci fib;
   Check(!fib.IsReady(), "Starts without anchors");
   Check(fib.PriceAt(0.5) == EMPTY_VALUE, "Uninitialized price");
   Check(fib.LevelCount() == 7, "Default level count");
   Check(fib.SetAnchors(100.0, 200.0), "Upward anchors");
   Check(Near(fib.PriceAt(0.0), 200.0), "Zero is swing end");
   Check(Near(fib.PriceAt(1.0), 100.0), "One is swing start");
   Check(Near(fib.LevelPrice(4), 138.2), "Upward 61.8% retracement");
   Check(!fib.SetAnchors(100.0, 100.0), "Reject equal anchors");
   Check(!fib.SetAnchors(EMPTY_VALUE, 200.0), "Reject sentinel anchor");
   Check(Near(fib.PriceAt(0.618), 138.2), "Failed updates preserve anchors");
   Check(fib.SetAnchors(200.0, 100.0), "Downward anchors");
   Check(Near(fib.PriceAt(0.618), 161.8), "Downward 61.8% retracement");
   Check(fib.LevelPrice(-1) == EMPTY_VALUE, "Reject negative index");
   Check(fib.LevelRatio(fib.LevelCount()) == EMPTY_VALUE, "Reject high index");

   double custom[] = {-0.272, 0.5, 1.618};
   Check(fib.SetLevels(custom), "Custom levels");
   Check(fib.LevelCount() == 3, "Custom level count");
   Check(Near(fib.LevelPrice(0), 72.8), "Projection beyond swing end");
   Check(Near(fib.LevelPrice(2), 261.8), "Projection beyond swing start");
   double empty[];
   double invalid[] = {EMPTY_VALUE};
   Check(!fib.SetLevels(empty), "Reject empty levels");
   Check(!fib.SetLevels(invalid), "Reject sentinel ratio");
   Check(fib.LevelCount() == 3, "Failed updates preserve levels");
   PrintFormat("Fibonacci checks: %d checks, %d failure(s)", g_checks, g_failures);
}

