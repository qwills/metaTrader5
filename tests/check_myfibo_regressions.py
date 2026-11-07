#!/usr/bin/env python3
"""Validate the corrected review findings, streaming continuity and manual selection.

Regression assertions run against actual source through the shared fake-MT5 platform.
Uses the existing fake MT5/C++ harness; no Windows/native rendering is exercised.
"""
from pathlib import Path
import re,sys,tempfile,subprocess,shutil
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
import check_myfibo_modes as suite
from check_swing_detector import SHIM,adapt
source=adapt((ROOT/'Experts/myFibo/myFibo.mq5').read_text()).replace('string fields[];', 'MqlArray<string> fields;').replace('const color FIBO_COLOR','const int FIBO_COLOR')
signatures=re.findall(r'^(?:bool|void|int|string)\s+\w+\([^{};]*\)\s*\{',source,flags=re.M)
prototypes='\n'.join(re.sub(r'=\s*(true|false)','',sig[:-1].strip())+';' for sig in signatures)
types=adapt((ROOT/'Experts/myFibo/MyFiboTypes.mqh').read_text())
libraries='\n'.join(adapt((ROOT/name).read_text()) for name in ['Include/Swing/SwingTypes.mqh','Include/Swing/SwingDetector.mqh','Include/Structure/MarketStructure.mqh','Include/Fibo/Fibonacci.mqh','Experts/myFibo/MyFiboAuto.mqh','Experts/myFibo/MyFiboChart.mqh','Experts/myFibo/MyFiboState.mqh'])
helper=suite.TESTS[:suite.TESTS.index('int main(){')]
native=(ROOT/"Scripts/Structure/MarketStructureExample.mq5").read_text()
break_fixture=adapt(native[native.index("void BreakFixture("):native.index("void RunBreakChecks(")])
audit=r'''

void BuildLong(MqlArray<MqlRates>&bars,int count){
 ArrayResize(bars,count);ArraySetAsSeries(bars,false);
 double h[]={10,12,11,13},l[]={8,9,7,10};
 for(int i=0;i<count;i++){bars[i]={};bars[i].time=1700000000+i*60;bars[i].high=h[i%4]+4*(i/4);bars[i].low=l[i%4]+4*(i/4);bars[i].close=(bars[i].high+bars[i].low)/2;}
}
void Window(const MqlArray<MqlRates>&all,int begin,int end,MqlArray<MqlRates>&out){
 ArraySetAsSeries(out,false);ArrayResize(out,end-begin);for(int i=begin;i<end;i++)out[i-begin]=all[i];
}
int main(){
 Fixture(9);Check(OnInit()==INIT_SUCCEEDED,"regression init");
 g_dialog.mode=FIBO_AUTO;fail_structure=true;Action(PANEL_SETTINGS);
 Check(g_has_swing&&g_labels_pending&&g_auto_retry_after==0,"label failure cannot block valid Fibo or schedule a data retry");
 int calls=copy_calls;clock_value+=6000;OnTimer();
 Check(!g_labels_pending&&copy_calls==calls&&g_status.find("Label: retry")==string::npos,"label recovery is independent and clears warning");
 for(const auto &entry:Objects())if(entry.second.type==OBJ_TEXT)
  Check(entry.second.ints.at({OBJPROP_BACK,0})==1&&entry.second.ints.at({OBJPROP_SELECTABLE,0})==0,"structure labels draw behind GUI without selection");
 Check(Objects()["myFibo.Swing.Fibo"].ints[{OBJPROP_BACK,0}]==1&&Objects()["myFibo.Swing.Fibo"].ints[{OBJPROP_SELECTABLE,0}]==1,"background Fibo retains native editing");
 // Updating retained foreground labels must apply layering without replacing them.
 auto label_time=Objects()["myFibo.Structure.0"].times[0];
 Objects()["myFibo.Structure.0"].ints[{OBJPROP_BACK,0}]=0;
 g_chart.ResetCache();Check(DrawStructureLabels(),"retained label refresh");
 Check(Objects()["myFibo.Structure.0"].times[0]==label_time&&Objects()["myFibo.Structure.0"].ints[{OBJPROP_BACK,0}]==1,"existing label moves to background without anchor changes");
 int writes=object_writes,moves=object_moves,deletes=object_deletes;
 DrawStructureLabels();DrawStructureLabels();
 Check(object_writes==writes&&object_moves==moves&&object_deletes==deletes,"unchanged label snapshots cause no chart writes/moves/deletions");
 Objects()["myFibo.Swing.Fibo"].prices[1]=6.5;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,"myFibo.Swing.Fibo");
 Check(g_anchor_edited&&g_dialog.anchor_source=="Pivot (edit)","edited anchor provenance displayed");
 Fixture(10);g_chart.ResetCache();fail_structure=true;OnTimer();
 Check(g_labels_pending&&g_end_price==6.5,"label failure keeps edited anchors");
 calls=copy_calls;clock_value+=6000;OnTimer();
 Check(!g_labels_pending&&copy_calls==calls&&g_end_price==6.5&&g_status.find("Fibo diperbarui")!=string::npos,"recovery preserves manual edit message and anchor");
 // A transient data error must also clear when recovery returns the same pair.
 Fixture(11);history[10].close=100;calls=copy_calls;OnTimer();
 Check(g_analysis_transient&&g_auto_retry_after>0,"analysis error is explicit and retriable");
 history[10].close=4;clock_value+=6000;OnTimer();
 Check(!g_analysis_transient&&copy_calls==calls+2&&g_status.find("tidak valid")==string::npos,"successful data retry clears stale error");
 OnDeinit(REASON_REMOVE);
 BuildLong(history,500);Check(OnInit()==INIT_SUCCEEDED,"full-window regression init");
 history[100].close=history[100].high+10;g_dialog.mode=FIBO_AUTO;Action(PANEL_SETTINGS);
 Check(g_last_auto_bar==0&&g_auto_retry_after>0&&g_analysis_transient,"invalid full window is not cached as no pair");
 calls=copy_calls;history[100].close=(history[100].high+history[100].low)/2;clock_value+=6000;OnTimer();
 Check(copy_calls==calls+1&&g_last_auto_bar==history.data.back().time&&!g_analysis_transient,"corrected full window retries before next candle");
 OnDeinit(REASON_REMOVE);
 // Exercise actual candle snapping and manual controller flow with screen mocks.
 Fixture(9);Check(OnInit()==INIT_SUCCEEDED,"manual regression init");geometry_enabled=true;
 g_start_time=history[1].time;g_start_price=2;g_anchor_source=ANCHOR_MANUAL;
 Check(DrawSwing(history[2].time,7),"initial manual fibo");
 Action(PANEL_DRAW);Check(g_has_swing&&g_state==SELECT_START,"manual reselection retains completed object");
 OnChartEvent(CHARTEVENT_CLICK,140,985,"");
 Check(Objects()["myFibo.Start"].ints[{OBJPROP_BACK,0}]==1,"manual preview marker stays behind GUI");
 Check(g_state==SELECT_END&&g_pick_time==history[4].time&&g_pick_price==3,"manual midpoint snaps to selected candle high");
 OnChartEvent(CHARTEVENT_KEYDOWN,27,0,"");
 Check(g_state==IDLE&&g_has_swing&&g_start_price==2&&g_end_price==7&&g_dialog.end==7,"Esc restores completed model/GUI");
 Check(ChartGetInteger(0,CHART_MOUSE_SCROLL)==1,"selection cancellation restores chart scrolling");
 Action(PANEL_DRAW);clock_value+=1000;OnChartEvent(CHARTEVENT_CLICK,140,985,"");
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H3;Check(OnInit()==INIT_SUCCEEDED,"manual pending handoff");
 Check(g_has_swing&&g_state==SELECT_END&&g_pick_price==3&&g_end_price==7&&g_dialog.start==3&&g_analysis_tf==PERIOD_H3,"preview and completed result both survive timeframe handoff");
 clock_value+=1000;OnChartEvent(CHARTEVENT_CLICK,160,940,"");
 Check(g_state==IDLE&&g_has_swing&&g_start_time==history[4].time&&g_end_time==history[6].time&&g_end_price==6,"valid replacement commits only after second click");
 datetime time=0;double price=0;
 Check(!CandleAnchor(220,950,time,price),"click in future empty chart space rejected");
 geometry_enabled=false;OnDeinit(REASON_REMOVE);
 // Normal rolling windows must agree with a fixed-origin replay.
 MqlArray<MqlRates> all,window;BuildLong(all,700);
 CMyFiboAuto rolling;rolling.Configure(1,1);SwingPoint start{},end{};
 Window(all,0,500,window);
 Check(rolling.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY,"stream bootstrap");
 for(int size=501;size<=700;size++){
  Window(all,size-500,size,window);
  Check(rolling.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY,"rolling analysis remains ready");
  CMarketStructure full;MqlArray<MqlRates> prefix;Window(all,0,size,prefix);Check(full.Analyze(prefix,1,1),"fixed-origin reference");
  StructureBreak actual,expected;rolling.GetBreak(rolling.BreakCount()-1,actual);full.GetBreak(full.BreakCount()-1,expected);
  Check(rolling.Trend()==full.Trend()&&actual.time==expected.time&&actual.origin.time==expected.origin.time,"rolling checkpoint matches fixed-origin direction and origin");
 }
 CMyFiboState persistence;Check(persistence.SaveCheckpoint(rolling,"stream-test"),"checkpoint write");
 CMyFiboAuto resumed;resumed.Configure(1,1);
 Check(persistence.LoadCheckpoint(resumed,"stream-test"),"checkpoint roundtrip");
 Check(resumed.Analyze(window,start,end,FIBO_MARKET_STRUCTURE)==FIBO_PAIR_READY&&resumed.Trend()==rolling.Trend(),"restored stream does not replay old bars");
 string saved=ObjectGetString(0,"myFibo.Checkpoint.Runtime",OBJPROP_TEXT);
 ObjectSetString(0,"myFibo.Checkpoint.Runtime",OBJPROP_TEXT,"broken");
 Check(!persistence.LoadCheckpoint(resumed,"stream-test"),"malformed checkpoint rejected");
 ObjectSetString(0,"myFibo.Checkpoint.Runtime",OBJPROP_TEXT,saved);persistence.ClearCheckpoint();
 // A quiet regime outlives the entire 500-candle display window.
 CMyFiboAuto quiet;quiet.Configure(1,1);BreakFixture(all,10);
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
 // Chart timeframe changes rebuild only the analysis, preserving settings/anchors
 // until the deferred result is ready. Locked anchors remain frozen.
 Fixture(9);_Period=PERIOD_M15;Check(OnInit()==INIT_SUCCEEDED,"follow-chart init");
 g_dialog.mode=FIBO_AUTO;Action(PANEL_SETTINGS);
 Objects()["myFibo.Swing.Fibo"].prices[1]=6.5;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,"myFibo.Swing.Fibo");
 g_dialog.x=170;g_dialog.y=120;
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H2;Fixture(13);calls=copy_calls;
 Check(OnInit()==INIT_SUCCEEDED,"follow H2 reinit");
 Check(g_analysis_tf==PERIOD_H2&&copy_calls==calls&&g_auto_force_pending,"new TF follows chart and defers CopyRates");
 StructureCheckpoint active;g_auto.GetCheckpoint(active);
 Check(active.last_bar==0&&ObjectFind(0,"myFibo.Structure.0")<0&&g_structure_trend==STRUCTURE_UNCLEAR,"old timeframe checkpoint and labels are discarded");
 Check(g_end_price==6.5&&g_dialog.x==170&&g_dialog.y==120&&g_left_bars==2&&g_right_bars==2,"settings geometry and prior drawing survive until update");
 OnTimer();Check(last_copy_tf==PERIOD_H2&&g_start_price==-1&&g_end_price==5&&!g_anchor_edited,"unlocked Auto updates using new TF candles");
 g_dialog.locked=true;Action(PANEL_LOCK);double held_start=g_start_price,held_end=g_end_price;
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_M2;Fixture(9);calls=copy_calls;
 Check(OnInit()==INIT_SUCCEEDED,"locked follow M2 reinit");OnTimer();
 Check(g_analysis_tf==PERIOD_M2&&g_anchor_locked&&g_start_price==held_start&&g_end_price==held_end&&copy_calls==calls&&!g_auto_force_pending,"locked TF change keeps anchors and performs no analysis");
 g_dialog.locked=false;Action(PANEL_LOCK);
 Check(last_copy_tf==PERIOD_M2&&g_end_price==6,"unlock resumes new chart timeframe");
 // An older snapshot with an independently selected TF cannot pin the new EA.
 OnDeinit(REASON_CHARTCHANGE);MyFiboSnapshot prior;
 Check(ReadChartSnapshot(prior),"prior snapshot available");prior.timeframe=PERIOD_H1;
 Check(g_storage.Write(prior,_Symbol),"legacy selected TF snapshot");
 _Period=PERIOD_M20;calls=copy_calls;
 Check(OnInit()==INIT_SUCCEEDED&&g_analysis_tf==PERIOD_M20&&g_auto_force_pending&&copy_calls==calls,"legacy fixed TF ignored in favor of chart");
 OnTimer();Check(last_copy_tf==PERIOD_M20,"legacy migration analyzes chart TF");
 OnDeinit(REASON_REMOVE);
 BreakFixture(history,16);_Period=PERIOD_H12;Check(OnInit()==INIT_SUCCEEDED,"structure chart TF init");
 g_dialog.mode=FIBO_AUTO;g_dialog.method=FIBO_MARKET_STRUCTURE;g_dialog.left=1;g_dialog.right=1;Action(PANEL_SETTINGS);
 Check(last_copy_tf==PERIOD_H12&&g_start_price==13&&g_end_price==5,"Market Structure also follows chart TF");
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_M3;BreakFixture(history,10);
 Check(OnInit()==INIT_SUCCEEDED&&g_auto_method==FIBO_MARKET_STRUCTURE&&g_left_bars==1&&g_right_bars==1,"method and pivot sensitivity retained across TF");
 OnTimer();Check(last_copy_tf==PERIOD_M3&&g_start_price==11&&g_end_price==17,"Market Structure rebuilds BOS on new TF");
 OnDeinit(REASON_REMOVE);
 int chart_periods[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,
  PERIOD_M15,PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
 for(int tf:chart_periods)Check(IsValidMyFiboSettings(FIBO_AUTO,tf,2,2)&&!MyFiboTimeframeName(tf).empty(),"every native chart timeframe is supported");
 Check(!IsMyFiboTimeframe(123456),"invalid timeframe rejected");
 std::cout<<"PASS: review regressions, independent label retries/cache, error recovery, provenance, manual geometry/cancel, sliding windows, checkpoint persistence, gap handling and chart-timeframe following.\n";
}
'''

code=SHIM+suite.PLATFORM+types+libraries+suite.DIALOG+'\nstruct MyFiboSnapshot;\n'+prototypes+source+helper+break_fixture+audit
with tempfile.TemporaryDirectory(prefix='myfibo-review-') as folder:
 cpp=Path(folder)/'review.cpp';binary=Path(folder)/'review';cpp.write_text(code)
 subprocess.run([shutil.which('clang++') or shutil.which('g++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined','-fno-sanitize-recover=all',str(cpp),'-o',str(binary)],check=True)
 subprocess.run([str(binary)],check=True)
