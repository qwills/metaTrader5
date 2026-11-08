#!/usr/bin/env python3
"""Preserve automatic-engine regressions from the former myFibo controller tests."""
from check_autofibo import ROOT, shared_code, compile_run
from check_swing_detector import adapt

TESTS = r'''
void Check(bool ok,const char*label){if(!ok){std::cerr<<"FAIL: "<<label<<'\n';std::abort();}}


void BuildLong(MqlArray<MqlRates>&bars,int count){
 ArrayResize(bars,count);ArraySetAsSeries(bars,false);
 double h[]={10,12,11,13},l[]={8,9,7,10};
 for(int i=0;i<count;i++){bars[i]={};bars[i].time=1700000000+i*60;bars[i].high=h[i%4]+4*(i/4);bars[i].low=l[i%4]+4*(i/4);bars[i].close=(bars[i].high+bars[i].low)/2;}
}
void Window(const MqlArray<MqlRates>&all,int begin,int end,MqlArray<MqlRates>&out){
 ArraySetAsSeries(out,false);ArrayResize(out,end-begin);for(int i=begin;i<end;i++)out[i-begin]=all[i];
}
void Fixture(int count){
 double highs[]={2,3,7,4,3,4,6,4,3,4,5,4,3};
 double lows[]={1,2,3,2,0,2,3,2,-1,2,3,2,1};
 ArrayResize(history,count);ArraySetAsSeries(history,false);
 for(int i=0;i<count;i++){history[i]={};history[i].time=1700000000+i*60;history[i].high=highs[i];history[i].low=lows[i];history[i].close=(highs[i]+lows[i])/2;}
}
int main(){Fixture(9); // Two ambiguous extremes in one candle never become an ordered pair.
 CAutoFiboAnalysis selector;selector.Configure(1,1);
 MqlArray<MqlRates> outside;ArrayResize(outside,3);
 for(int i=0;i<3;i++){outside[i]={};outside[i].time=100+i;outside[i].high=i==1?5:2;outside[i].low=i==1?-1:1;outside[i].close=(outside[i].high+outside[i].low)/2;}
 SwingPoint a{},b{};a.price=123;
 Check(!selector.FindPair(outside,a,b)&&a.price==123,"outside candle ambiguity/output atomicity");
 selector.Configure(2,2);
 Check(selector.FindPair(history,a,b)&&a.price==0&&b.price==6,"unambiguous latest opposite pair");
 ArraySetAsSeries(history,true);
 Check(selector.FindPair(history,a,b)&&a.price==0&&b.price==6,"pair selection supports timeseries");
 ArraySetAsSeries(history,false);
 // Normal rolling windows must agree with a fixed-origin replay.
 MqlArray<MqlRates> all,window;BuildLong(all,700);
 CAutoFiboAnalysis rolling;rolling.Configure(1,1);SwingPoint start{},end{};
 Window(all,0,500,window);
 Check(rolling.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY,"stream bootstrap");
 for(int size=501;size<=700;size++){
  Window(all,size-500,size,window);
  Check(rolling.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY,"rolling analysis remains ready");
  CMarketStructure full;MqlArray<MqlRates> prefix;Window(all,0,size,prefix);Check(full.Analyze(prefix,1,1),"fixed-origin reference");
  StructureBreak actual,expected;rolling.GetBreak(rolling.BreakCount()-1,actual);full.GetBreak(full.BreakCount()-1,expected);
  Check(rolling.Trend()==full.Trend()&&actual.time==expected.time&&actual.origin.time==expected.origin.time,"rolling checkpoint matches fixed-origin direction and origin");
 }
 CAutoFiboState persistence;Check(persistence.SaveCheckpoint(rolling,"stream-test"),"checkpoint write");
 CAutoFiboAnalysis resumed;resumed.Configure(1,1);
 Check(persistence.LoadCheckpoint(resumed,"stream-test"),"checkpoint roundtrip");
 Check(resumed.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY&&resumed.Trend()==rolling.Trend(),"restored stream does not replay old bars");
 string saved=ObjectGetString(0,"AutoFibo.Checkpoint.Runtime",OBJPROP_TEXT);
 ObjectSetString(0,"AutoFibo.Checkpoint.Runtime",OBJPROP_TEXT,"broken");
 Check(!persistence.LoadCheckpoint(resumed,"stream-test"),"malformed checkpoint rejected");
 ObjectSetString(0,"AutoFibo.Checkpoint.Runtime",OBJPROP_TEXT,saved);persistence.ClearCheckpoint();
 // A quiet regime outlives the entire 500-candle display window.
 CAutoFiboAnalysis quiet;quiet.Configure(1,1);BreakFixture(all,10);
 Check(quiet.Analyze(all,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY,"quiet regime bootstrap");
 ArrayResize(all,610);for(int i=10;i<610;i++){all[i]={};all[i].time=1000+i*60;all[i].high=15;all[i].low=14;all[i].close=14.5;}
 for(int size=11;size<=610;size++){
  Window(all,size>500?size-500:0,size,window);
  Check(quiet.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY&&start.price==11&&end.price==17,"old BOS impulse survives left-window expiry without synthetic reversal");
 }
 // Missed history must not silently start a new regime.
 Window(all,110,610,window);for(int i=0;i<ArraySize(window);i++)window[i].time+=100000;
 Check(quiet.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_ANALYSIS_ERROR,"non-overlapping history gap is explicit");
 Check(quiet.Analyze(window,start,end,FIBO_MARKET_STRUCTURE,true)==FIBO_WAITING_PAIR&&quiet.Reseeded(),"explicit search can reseed a gap");

 std::cout<<"PASS: Pivot ambiguity, causal BOS, 500-bar rolling checkpoint continuity, persistence and explicit gap reseeding.\n";
}
'''

def main():
    text=(ROOT/'tests/fixtures/market_structure_checks.mqh').read_text()
    fixture=adapt(text[text.index('void BreakFixture('):text.index('void RunBreakChecks(')])
    compile_run(shared_code()+fixture+TESTS,'autofibo-analysis-')
    print('C++ compatibility checks only; native MQL5 compilation remains separate.')

if __name__=='__main__': main()
