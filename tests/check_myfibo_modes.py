#!/usr/bin/env python3
"""Exercise actual EA/controller and detector code with fake MT5/UI APIs.

No GUI rendering, native CAppDialog implementation, or MQL5 compilation is tested.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from check_swing_detector import SHIM, adapt

ROOT = Path(__file__).resolve().parents[1]
PLATFORM = r'''
#include <cassert>
#include <map>
#include <cstdlib>
#include <cfloat>
using ulong=unsigned long;
using ENUM_OBJECT_PROPERTY_INTEGER=int;
enum ENUM_TIMEFRAMES : int { PERIOD_CURRENT=0, PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,PERIOD_M4=4,
 PERIOD_M5=5,PERIOD_M6=6,PERIOD_M10=10,PERIOD_M12=12,PERIOD_M15=15,PERIOD_M20=20,PERIOD_M30=30,
 PERIOD_H1=16385,PERIOD_H2=16386,PERIOD_H3=16387,PERIOD_H4=16388,PERIOD_H6=16390,PERIOD_H8=16392,
 PERIOD_H12=16396,PERIOD_D1=16408,PERIOD_W1=32769,PERIOD_MN1=49153 };
enum : int { clrBlack=0, STYLE_SOLID=0, OBJ_LABEL=1, OBJ_FIBO, OBJ_ARROW, OBJ_TEXT,
 OBJPROP_TIMEFRAMES=100,OBJPROP_HIDDEN,OBJPROP_SELECTABLE,OBJPROP_SELECTED,OBJPROP_TEXT,OBJPROP_TOOLTIP,
 OBJPROP_TIME,OBJPROP_PRICE,OBJPROP_COLOR,OBJPROP_LEVELS,OBJPROP_LEVELVALUE,OBJPROP_LEVELCOLOR,
 OBJPROP_LEVELSTYLE,OBJPROP_LEVELWIDTH,OBJPROP_LEVELTEXT,OBJPROP_STYLE,OBJPROP_WIDTH,
 OBJPROP_RAY_LEFT,OBJPROP_RAY_RIGHT,OBJPROP_BACK,OBJPROP_ARROWCODE,
 OBJPROP_FONTSIZE,OBJPROP_ANCHOR,OBJPROP_ZORDER,ANCHOR_LOWER,ANCHOR_UPPER,
 OBJ_NO_PERIODS=0,CHART_EVENT_MOUSE_MOVE=200,CHART_EVENT_OBJECT_CREATE,CHART_EVENT_OBJECT_DELETE,
 CHART_MOUSE_SCROLL,CHARTEVENT_CUSTOM=1000,ON_CLICK=1,ON_CHANGE=2,
 CHARTEVENT_MOUSE_MOVE=300,CHARTEVENT_CHART_CHANGE,CHARTEVENT_OBJECT_DRAG,CHARTEVENT_OBJECT_CHANGE,
 CHARTEVENT_KEYDOWN,CHARTEVENT_CLICK,CHARTEVENT_OBJECT_DELETE,REASON_CHARTCHANGE=3,REASON_REMOVE=1,
 INIT_SUCCEEDED=0,INIT_FAILED=1 };
string _Symbol="EURUSD";
const int _Digits=5;
bool stopped=false,timer=false,fail_config=false,fail_structure=false;
int object_writes=0,object_moves=0,object_deletes=0;
bool geometry_enabled=false;
std::map<int,std::map<int,long>> chart_properties;
int chart_context=1,copy_calls=0,native_calls=0,loads=0,last_copy_tf=0;
ulong clock_value=1000;
MqlArray<MqlRates> history;
struct Node { int type; datetime times[2]; double prices[2]; std::map<std::pair<int,int>,long> ints;
 std::map<std::pair<int,int>,double> doubles; std::map<std::pair<int,int>,string> strings; };
std::map<int,std::map<string,Node>> charts;
auto &Objects(){return charts[chart_context];}
int ObjectFind(int,const string&name){return Objects().count(name)?0:-1;}
bool ObjectCreate(int,const string&name,int type,int,datetime a,double p,datetime b=0,double q=0){
 if(Objects().count(name))return false;
 Node n{};n.type=type;n.times[0]=a;n.times[1]=b;n.prices[0]=p;n.prices[1]=q;Objects()[name]=n;return true;}
bool ObjectDelete(int,const string&name){++object_deletes;return Objects().erase(name)>0;}
void ObjectsDeleteAll(int,const string&prefix){for(auto i=Objects().begin();i!=Objects().end();)if(i->first.rfind(prefix,0)==0)i=Objects().erase(i);else ++i;}
bool ObjectSetInteger(int,const string&name,int prop,int index,long v){
 ++object_writes;
 if(fail_structure&&name.rfind("myFibo.Structure.",0)==0){fail_structure=false;return false;}
 if(fail_config&&Objects().count(name)&&Objects()[name].type==OBJ_FIBO){fail_config=false;return false;}if(!Objects().count(name))return false;Objects()[name].ints[{prop,index}]=v;return true;}
bool ObjectSetInteger(int chart,const string&name,int prop,long v){return ObjectSetInteger(chart,name,prop,0,v);}
bool ObjectSetDouble(int,const string&name,int prop,int index,double v){++object_writes;if(!Objects().count(name))return false;Objects()[name].doubles[{prop,index}]=v;return true;}
bool ObjectSetString(int,const string&name,int prop,int index,const string&v){++object_writes;if(!Objects().count(name))return false;Objects()[name].strings[{prop,index}]=v;return true;}
bool ObjectSetString(int chart,const string&name,int prop,const string&v){return ObjectSetString(chart,name,prop,0,v);}
bool ObjectGetInteger(int,const string&name,int prop,int index,long&v){if(!Objects().count(name))return false;v=prop==OBJPROP_TIME?Objects()[name].times[index]:Objects()[name].ints[{prop,index}];return true;}
bool ObjectGetDouble(int,const string&name,int prop,int index,double&v){if(!Objects().count(name))return false;v=prop==OBJPROP_PRICE?Objects()[name].prices[index]:Objects()[name].doubles[{prop,index}];return true;}
bool ObjectGetString(int,const string&name,int prop,int index,string&v){if(!Objects().count(name))return false;v=Objects()[name].strings[{prop,index}];return true;}
string ObjectGetString(int chart,const string&name,int prop){string v;ObjectGetString(chart,name,prop,0,v);return v;}
bool ObjectMove(int,const string&name,int index,datetime t,double p){++object_moves;if(!Objects().count(name))return false;Objects()[name].times[index]=t;Objects()[name].prices[index]=p;return true;}
long StringToInteger(const string&s){return std::strtol(s.c_str(),nullptr,10);}
double StringToDouble(const string&s){return std::strtod(s.c_str(),nullptr);}
string IntegerToString(long long v){return std::to_string(v);}
string StringFormat(const string&f,double v){char b[200];snprintf(b,sizeof(b),f.c_str(),v);return b;}
string DoubleToString(double v,int digits){char b[200];snprintf(b,sizeof(b),"%.*f",digits,v);return b;}
int StringLen(const string&s){return static_cast<int>(s.size());}
string StringSubstr(const string&s,int start,int count=-1){return s.substr(start,count<0?string::npos:static_cast<size_t>(count));}
int StringSplit(const string&s,char delim,MqlArray<string>&out){out.data.clear();size_t a=0,b;while((b=s.find(delim,a))!=string::npos){out.data.push_back(s.substr(a,b-a));a=b+1;}out.data.push_back(s.substr(a));return ArraySize(out);}
long ChartGetInteger(int,int prop,int=0){return chart_properties[chart_context].count(prop)?chart_properties[chart_context][prop]:1;}
bool ChartSetInteger(int,int prop,bool value){chart_properties[chart_context][prop]=value;return true;}
void ChartRedraw(int=0){}
long ChartID(){return chart_context;}
bool IsStopped(){return stopped;}
ulong GetTickCount64(){return clock_value++;}
void ResetLastError(){}
int GetLastError(){return 0;}
bool EventSetTimer(int){timer=true;return true;}
void EventKillTimer(){timer=false;}
datetime iTime(const string&,ENUM_TIMEFRAMES,int shift){if(geometry_enabled)return shift>=0&&shift<ArraySize(history)?history[ArraySize(history)-1-shift].time:0;return history.data.empty()?0:history.data.back().time+(shift==0?60:0);}
int CopyRates(const string&,ENUM_TIMEFRAMES tf,int shift,int,MqlArray<MqlRates>&out){assert(shift==1);last_copy_tf=tf;++copy_calls;out.data=history.data;return ArraySize(out);}
template<size_t N> int CopyRates(const string&,ENUM_TIMEFRAMES,int shift,int,MqlRates (&out)[N]){
 if(history.data.empty()||N==0)return 0;out[0]=geometry_enabled?history[ArraySize(history)-1-shift]:history.data.back();return 1;}
bool ChartXYToTimePrice(int,int x,int y,int&window,datetime&time,double&price){
 if(!geometry_enabled||history.data.empty())return false;
 window=0;time=history[0].time+(x-100)*6;price=(1000-y)/10.0;return true;}
 bool ChartTimePriceToXY(int,int,datetime time,double price,int&x,int&y){
 if(!geometry_enabled||history.data.empty())return false;
 x=100+(time-history[0].time)/6;y=1000-price*10;return true;}
 int iBarShift(const string&,int,datetime time,bool){
 if(!geometry_enabled||history.data.empty())return -1;
 int index=(time-history[0].time)/60;index=index<0?0:(index>=ArraySize(history)?ArraySize(history)-1:index);
 return ArraySize(history)-1-index;}
 int Bars(const string&,int){return geometry_enabled?ArraySize(history):0;}
ENUM_TIMEFRAMES _Period=PERIOD_M15;
double MathAbs(double v){return std::abs(v);}
double MathMax(double a,double b){return a>b?a:b;}
'''
DIALOG = r'''
enum MyFiboPanelAction{PANEL_NONE,PANEL_DRAW,PANEL_RESET,PANEL_SETTINGS,PANEL_LOCK};
class CMyFiboDialog {
public:
 MyFiboMode mode=FIBO_MANUAL;MyFiboAutoMethod method=FIBO_PIVOT;ENUM_TIMEFRAMES tf=PERIOD_H1;int left=2,right=2;
 bool locked=false,dragging=false;MyFiboPanelAction next=PANEL_NONE;
 double start=0,end=0,a=0,b=0,c=0;int x=12,y=24;string message,structure_trend,anchor_source;
 static inline std::map<int,std::pair<int,int>> geometry;
 bool Create(int,const string&,int,int,int,int,int){return true;}
 bool Run(){return true;}void Minimized(bool){}
 void Destroy(int){geometry[chart_context]={x,y};}
 void IniFileLoad(){++loads;if(geometry.count(chart_context)){x=geometry[chart_context].first;y=geometry[chart_context].second;}}
 void ChartEvent(int,const long&,const double&,const string&){++native_calls;}
 bool Dragging()const{return dragging;}bool IsVisible()const{return true;}
 bool Contains(int a,int b)const{return a>=x&&a<x+580&&b>=y&&b<y+524;}
 void CancelDrag(){dragging=false;}
 MyFiboPanelAction TakeAction(){auto action=next;next=PANEL_NONE;return action;}
 MyFiboAutoMethod AutoMethod(){return method;}
 MyFiboMode Mode()const{return mode;}
 int LeftBars()const{return left;}int RightBars()const{return right;}bool AnchorLocked()const{return locked;}
 void SetSettings(MyFiboMode m,ENUM_TIMEFRAMES t,int l,int r,bool k,MyFiboAutoMethod a=FIBO_PIVOT){mode=m;tf=t;left=l;right=r;locked=k;method=a;}
 void SetAnchorSource(const string&s){anchor_source=s;}
 void SetStructureTrend(const string&t){structure_trend=t;}
 void SetStatus(const string&m,bool){message=m;}
 void ClearSwing(){start=end=a=b=c=0;}
 void SetSwingStart(double p){start=p;}void SetSwingEnd(double p){end=p;}
 void SetDirection(bool){}
 void SetLevels(double p,double q,double r){a=p;b=q;c=r;}
};
'''
TESTS = r'''
void Check(bool value,const char*label){if(!value){std::cerr<<"FAIL: "<<label<<'\n';std::abort();}}
void Fixture(int count){
 double highs[]={2,3,7,4,3,4,6,4,3,4,5,4,3};
 double lows[]={1,2,3,2,0,2,3,2,-1,2,3,2,1};
 ArrayResize(history,count);ArraySetAsSeries(history,false);
 for(int i=0;i<count;i++){history[i]={};history[i].time=1700000000+i*60;history[i].high=highs[i];history[i].low=lows[i];history[i].close=(highs[i]+lows[i])/2;}
}
void Action(MyFiboPanelAction action){g_dialog.next=action;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");OnTimer();}
int main(){
 Fixture(9);Check(OnInit()==INIT_SUCCEEDED,"initialization");
 Check(g_mode==FIBO_MANUAL&&!g_anchor_locked&&!g_dialog.locked,"manual/unlocked defaults");
 int before=native_calls;for(int i=0;i<1000;i++)OnChartEvent(CHARTEVENT_MOUSE_MOVE,900+i,0,"0");
 Check(native_calls==before+1000&&copy_calls==0,"native event routing without history calls");
 // Two ambiguous extremes in one candle never become an ordered pair.
 CMyFiboAuto selector;selector.Configure(1,1);
 MqlArray<MqlRates> outside;ArrayResize(outside,3);
 for(int i=0;i<3;i++){outside[i]={};outside[i].time=100+i;outside[i].high=i==1?5:2;outside[i].low=i==1?-1:1;outside[i].close=(outside[i].high+outside[i].low)/2;}
 SwingPoint a{},b{};a.price=123;
 Check(!selector.FindPair(outside,a,b)&&a.price==123,"outside candle ambiguity/output atomicity");
 selector.Configure(2,2);
 Check(selector.FindPair(history,a,b)&&a.price==0&&b.price==6,"unambiguous latest opposite pair");
 ArraySetAsSeries(history,true);
 Check(selector.FindPair(history,a,b)&&a.price==0&&b.price==6,"pair selection supports timeseries");
 ArraySetAsSeries(history,false);
 g_dialog.mode=FIBO_AUTO;Action(PANEL_SETTINGS);
 Check(g_mode==FIBO_AUTO&&g_has_swing&&g_start_price==0&&g_end_price==6,"automatic confirmed pair");
 Check(ObjectFind(0,"myFibo.Structure.0")>=0&&Objects()["myFibo.Structure.0"].type==OBJ_TEXT,"auto renders structure labels");
 Check(Objects()["myFibo.Structure.0"].strings[{OBJPROP_TEXT,0}]=="H"&&Objects()["myFibo.Structure.2"].strings[{OBJPROP_TEXT,0}]=="LH","seed and LH chart labels");
 Check(Objects()["myFibo.Structure.2"].ints[{OBJPROP_SELECTABLE,0}]==0,"structure label is not draggable");
 Check(g_analysis_tf==_Period&&last_copy_tf==PERIOD_M15,"Auto follows M15 chart");
 Check(Objects()["myFibo.Swing.Fibo"].ints[{OBJPROP_SELECTABLE,0}]==1,"unlocked object is editable");
 Check(Objects()["myFibo.Swing.Fibo"].ints[{OBJPROP_LEVELS,0}]==3,"exactly three levels");
 int copies=copy_calls;OnTimer();Check(copy_calls==copies,"no rescan within same closed bar");
 Objects()["myFibo.Swing.Fibo"].prices[1]=6.5;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,"myFibo.Swing.Fibo");
 Check(g_end_price==6.5&&!g_anchor_locked&&!g_dialog.locked,"manual edit never locks checkbox");
 Fixture(10);copies=copy_calls;g_dialog.dragging=true;OnTimer();
 Check(copy_calls==copies,"no history work during GUI drag");
 g_dialog.dragging=false;OnTimer();Check(g_end_price==6.5,"same auto pair preserves manual edit");
 g_dialog.locked=true;Action(PANEL_LOCK);copies=copy_calls;
 Check(g_anchor_locked&&Objects()["myFibo.Swing.Fibo"].ints[{OBJPROP_SELECTABLE,0}]==0,"checked lock disables dragging");
 Fixture(11);OnTimer();Check(copy_calls==copies&&g_end_price==6.5,"locked automatic updates stop");
 Objects()["myFibo.Swing.Fibo"].prices[1]=500;
 OnChartEvent(CHARTEVENT_OBJECT_CHANGE,0,0,"myFibo.Swing.Fibo");
 Check(g_end_price==6.5&&Objects()["myFibo.Swing.Fibo"].prices[1]==6.5,"locked property edit restored");
 g_dialog.locked=false;Action(PANEL_LOCK);
 Check(!g_anchor_locked&&g_start_price==6&&g_end_price==-1,"unlock resumes new automatic pair");
 // A failed redraw must restore the previous cached model and existing native object.
 Fixture(13);fail_config=true;
 Check(!RefreshAutoSwing(true)&&g_start_price==6&&g_end_price==-1,"failed redraw restores cached anchors");
 Check(Objects()["myFibo.Swing.Fibo"].prices[0]==6&&Objects()["myFibo.Swing.Fibo"].prices[1]==-1,"failed redraw restores object anchors");
 Fixture(11);
 // Timeframe reinit restores mode/TF/pivot settings, explicit lock, geometry and actual object.
 g_dialog.locked=true;Action(PANEL_LOCK);g_dialog.x=170;g_dialog.y=120;
 copies=copy_calls;g_dialog.left=1;Action(PANEL_SETTINGS);
 Check(copy_calls==copies&&g_analysis_tf==_Period&&g_left_bars==1,"locked settings changes do not search or replace anchors");
 string key=g_auto_pair_key;OnDeinit(REASON_CHARTCHANGE);Check(!timer&&ObjectFind(0,"myFibo.Swing.Fibo")>=0,"handoff retains fibo");
 Check(OnInit()==INIT_SUCCEEDED,"timeframe reinitialization");
 Check(g_mode==FIBO_AUTO&&g_anchor_locked&&g_dialog.locked&&g_dialog.x==170&&g_dialog.y==120,"mode/lock/geometry persistence");
 Check(g_auto_pair_key==key&&g_start_price==6&&g_end_price==-1,"candidate key and edited model persistence");
 Check(g_analysis_tf==_Period&&g_left_bars==1&&g_right_bars==2,"analysis timeframe and pivot settings persist");
 // Lock does not prevent Reset, and Reset does not silently untick the user's checkbox.
 Action(PANEL_RESET);Check(!g_has_swing&&g_anchor_locked&&g_dialog.locked,"reset retains explicit checkbox");
 Check(ObjectFind(0,"myFibo.Structure.0")<0,"reset clears structure labels");
 g_dialog.locked=false;Action(PANEL_LOCK);Action(PANEL_DRAW);
 Check(g_has_swing&&g_start_price==6,"explicit search regenerates same pair");
 g_dialog.mode=FIBO_MANUAL;g_dialog.left=2;Action(PANEL_SETTINGS);
 Check(g_mode==FIBO_MANUAL&&g_has_swing,"mode switch retains completed fibo");
 Check(ObjectFind(0,"myFibo.Structure.0")<0,"manual mode clears auto labels");
 copies=copy_calls;OnTimer();Check(copy_calls==copies,"manual mode never scans history");
 Action(PANEL_DRAW);Check(g_state==SELECT_START&&g_has_swing,"manual selection starts");
 // A partial manual selection and checkbox false survive timeframe switch too.
 g_state=SELECT_END;g_pick_time=12345;g_pick_price=20;
 ObjectCreate(0,"myFibo.Start",OBJ_ARROW,0,g_pick_time,g_pick_price);
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED,"pending timeframe reinit");
 Check(g_state==SELECT_END&&g_pick_price==20&&!g_anchor_locked,"pending selection restored");
 g_dialog.locked=true;Action(PANEL_LOCK);Check(g_state==IDLE&&g_anchor_locked,"locking cancels incomplete selection");
 // Invalid GUI configuration is rejected; same settings are idempotent.
 g_dialog.left=0;Action(PANEL_SETTINGS);Check(g_left_bars==2&&g_dialog.left==2,"invalid settings restored");
 copies=copy_calls;Action(PANEL_SETTINGS);Check(copy_calls==copies,"programmatic settings events are idempotent");
 OnDeinit(REASON_REMOVE);Check(ObjectFind(0,"myFibo.State")<0&&ObjectFind(0,"myFibo.Swing.Fibo")<0,"remove clears owned state");
 std::cout<<"PASS: Auto pairing, manual edits, explicit lock/unlock, mode switching, timer gating, settings validation, native event forwarding, and timeframe persistence.\n";
}
'''

REVIEW_TESTS = r'''
int main(){
 int failures=0;
 auto Expect=[&](bool ok,const char*label){if(!ok){++failures;std::cerr<<"REVIEW FAIL: "<<label<<'\n';}};
 Fixture(9);Check(OnInit()==INIT_SUCCEEDED,"review init");
 g_dialog.mode=FIBO_AUTO;g_dialog.next=PANEL_SETTINGS;
 int before=copy_calls;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 Expect(copy_calls==before,"GUI settings handler must defer CopyRates to timer");
 OnDeinit(REASON_CHARTCHANGE);Expect(OnInit()==INIT_SUCCEEDED,"queued request timeframe reinit");
 Expect(g_auto_force_pending&&copy_calls==before,"queued force request survives timeframe change without data access in init");
 OnTimer();Expect(g_has_swing,"queued automatic search executes on timer");
 ObjectDelete(0,"myFibo.Swing.Fibo");OnChartEvent(CHARTEVENT_OBJECT_DELETE,0,0,"myFibo.Swing.Fibo");
 Expect(!g_has_swing&&g_dialog.end==0,"native object deletion must clear model and GUI");
 g_dialog.next=PANEL_DRAW;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 Expect(g_auto_force_pending,"explicit search queued");
 g_dialog.next=PANEL_RESET;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");OnTimer();
 Expect(!g_auto_force_pending&&!g_has_swing,"Reset cancels queued search without recreating the same pair");
 RefreshAutoSwing(true);g_dialog.locked=true;g_dialog.next=PANEL_LOCK;fail_config=true;
 OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 Expect(!g_anchor_locked&&!g_dialog.locked,"failed lock property write must roll back checkbox and model");
 g_dialog.locked=false;g_dialog.next=PANEL_LOCK;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 OnDeinit(REASON_REMOVE);
 Fixture(9);for(int i=0;i<9;i++){history[i].high=i+2;history[i].low=i+1;history[i].close=i+1.5;}
 Check(OnInit()==INIT_SUCCEEDED,"history review init");
 g_dialog.mode=FIBO_AUTO;g_dialog.next=PANEL_SETTINGS;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 OnTimer();Expect(!g_has_swing,"partial history initially has no pivot pair");
 int attempts=copy_calls;OnTimer();Expect(copy_calls==attempts,"partial history retry has a backoff");
 Fixture(9);clock_value+=6000;OnTimer();
 Expect(g_has_swing,"partial history retry must not wait for next H1 close");
 OnDeinit(REASON_REMOVE);
 if(failures){std::cerr<<failures<<" review regression(s) reproduced.\n";return 1;}
 std::cout<<"PASS: deferred GUI data access, native deletion cleanup, lock failure rollback and partial-history retry.\n";
}
'''

STRUCTURE_TESTS = r'''
int main(){
 ArrayResize(history,500);ArraySetAsSeries(history,false);
 for(int i=0;i<500;i++){
  history[i]={};history[i].time=1700000000+i*60;
  history[i].high=i%4==2?6:2;history[i].low=1;history[i].close=1.5;
 }
 Check(OnInit()==INIT_SUCCEEDED,"structure init");
 g_dialog.mode=FIBO_AUTO;Action(PANEL_SETTINGS);
 Check(!g_has_swing&&g_auto.StructureCount()>30,"structure exists without a fibo pair");
 int labels=0;for(const auto &entry:Objects())if(entry.second.type==OBJ_TEXT)++labels;
 Check(labels==30&&ObjectFind(0,"myFibo.Structure.30")<0,"chart label count is capped at thirty");
 Check(Objects()["myFibo.Structure.29"].strings[{OBJPROP_TEXT,0}]=="EH","equal high chart classification");
 auto label_time=Objects()["myFibo.Structure.29"].times[0];
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED,"structure timeframe reinit");
 Check(Objects()["myFibo.Structure.29"].times[0]==label_time,"chart labels survive timeframe handoff");
 Fixture(9);RefreshAutoSwing(true);
 labels=0;for(const auto &entry:Objects())if(entry.second.type==OBJ_TEXT)++labels;
 Check(labels==3&&ObjectFind(0,"myFibo.Structure.3")<0,"shrinking snapshot deletes obsolete label slots");
 Check(Objects()["myFibo.Structure.2"].strings[{OBJPROP_TEXT,0}]=="LH","reused slot gets new classification");
 Objects()["myFibo.Swing.Fibo"].prices[1]=6.5;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,"myFibo.Swing.Fibo");
 Fixture(10);g_chart.ResetCache();fail_structure=true;OnTimer();
 Check(g_labels_pending&&!g_auto_force_pending,"label failure schedules independent render retry");
 clock_value+=6000;OnTimer();
 Check(g_end_price==6.5,"label retry preserves manual fibo edits on same pair");
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H4;
 Check(OnInit()==INIT_SUCCEEDED,"chart timeframe change reinit");
 Check(ObjectFind(0,"myFibo.Structure.0")<0,"analysis timeframe change clears stale labels immediately");
 OnTimer();Check(ObjectFind(0,"myFibo.Structure.0")>=0,"new analysis repopulates labels");
 OnDeinit(REASON_REMOVE);
 Check(ObjectFind(0,"myFibo.Structure.0")<0,"EA removal clears labels");
 BreakFixture(history,16);
 Check(OnInit()==INIT_SUCCEEDED,"break chart init");
 g_dialog.mode=FIBO_AUTO;g_dialog.left=1;g_dialog.right=1;Action(PANEL_SETTINGS);
 for(const auto &entry:Objects())if(entry.second.type==OBJ_TEXT)
  Check(entry.second.ints.at({OBJPROP_BACK,0})==1&&entry.second.ints.at({OBJPROP_ZORDER,0})==0,"pivot and BOS/CHoCH labels are behind GUI with low click priority");
 Check(g_auto.BreakCount()==4&&g_structure_trend==STRUCTURE_BEARISH&&g_dialog.structure_trend=="Bearish","GUI displays replayed direction");
 Check(Objects()["myFibo.Structure.Break.0"].strings[{OBJPROP_TEXT,0}]=="BOS Bullish","BOS chart text");
 Check(Objects()["myFibo.Structure.Break.2"].strings[{OBJPROP_TEXT,0}]=="CHoCH Bearish","CHoCH chart text");
 Check(Objects()["myFibo.Structure.Break.2"].times[0]==history[10].time,"break label uses breaking candle");
 g_dialog.locked=true;Action(PANEL_LOCK);
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED,"break timeframe handoff");
 Check(g_structure_trend==STRUCTURE_BEARISH&&g_dialog.structure_trend=="Bearish"&&ObjectFind(0,"myFibo.Structure.Break.2")>=0,"locked direction and break labels survive chart timeframe change");
 Action(PANEL_RESET);
 Check(g_structure_trend==STRUCTURE_UNCLEAR&&g_dialog.structure_trend=="Belum jelas"&&ObjectFind(0,"myFibo.Structure.Break.0")<0,"reset clears break objects and displayed direction");
 OnDeinit(REASON_REMOVE);
 ArrayResize(history,500);
 double cyc_high[]={10,12,11,13},cyc_low[]={8,9,7,10};
 for(int i=0;i<500;i++){
  history[i]={};history[i].time=1700000000+i*60;
  history[i].high=cyc_high[i%4]+4*(i/4);history[i].low=cyc_low[i%4]+4*(i/4);
  history[i].close=(history[i].high+history[i].low)/2;
 }
 Check(OnInit()==INIT_SUCCEEDED,"long break history init");
 g_dialog.mode=FIBO_AUTO;g_dialog.left=1;g_dialog.right=1;Action(PANEL_SETTINGS);
 Check(g_auto.BreakCount()>20,"long snapshot contains many BOS events");
 labels=0;for(const auto &entry:Objects())if(entry.second.type==OBJ_TEXT)++labels;
 Check(labels==50&&ObjectFind(0,"myFibo.Structure.Break.20")<0,"thirty pivot plus twenty break label limit");
 OnDeinit(REASON_REMOVE);
 CMyFiboAuto chooser;Check(chooser.Configure(1,1),"method chooser configuration");
 SwingPoint start{},end{};
 BreakFixture(history,8);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==9&&end.price==16&&end.time==history[7].time,"bullish structure anchors at pre-BOS low and break candle high");
 Check(start.confirmed&&!end.confirmed,"structure endpoint is a closed extreme, not a confirmed pivot");
 BreakFixture(history,9);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==9&&end.price==16,"future pivot confirmation does not rewrite BOS origin");
 BreakFixture(history,10);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==11&&end.price==17,"new BOS selects next impulse");
 ArraySetAsSeries(history,true);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==11&&end.price==17,"structure method accepts series indexing");
 ArraySetAsSeries(history,false);
 BreakFixture(history,11);start.price=123;end.price=456;
 Check(!chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==123&&end.price==456,"CHoCH pauses selection without output mutation");
 Check(chooser.FindPair(history,start,end,FIBO_PIVOT),"pivot method remains available during unclear structure");
 BreakFixture(history,16);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==13&&end.price==5,"bearish structure anchors at pre-BOS high and break candle low");
 BreakFixture(history,16,true);
 Check(chooser.FindPair(history,start,end,FIBO_MARKET_STRUCTURE)&&start.price==17&&end.price==25,"mirrored bullish impulse");
 Check(!chooser.FindPair(history,start,end,(MyFiboAutoMethod)99),"invalid method rejected");
 BreakFixture(history,10);Check(OnInit()==INIT_SUCCEEDED,"method controller init");
 g_dialog.mode=FIBO_AUTO;g_dialog.left=1;g_dialog.right=1;Action(PANEL_SETTINGS);
 Check(g_auto_method==FIBO_PIVOT,"existing pivot method remains default");
 g_dialog.method=FIBO_MARKET_STRUCTURE;g_dialog.next=PANEL_SETTINGS;
 int method_copies=copy_calls;OnChartEvent(CHARTEVENT_CUSTOM+ON_CHANGE,0,0,"");
 Check(copy_calls==method_copies&&g_auto_force_pending,"method switch defers history work to timer");
 OnTimer();Check(g_auto_method==FIBO_MARKET_STRUCTURE&&g_start_price==11&&g_end_price==17,"method switch redraws using structure anchors");
 Objects()["myFibo.Swing.Fibo"].prices[1]=17.5;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,"myFibo.Swing.Fibo");
 BreakFixture(history,11);RefreshAutoSwing(false);
 Check(g_end_price==17.5&&g_has_swing&&g_status.find("menunggu BOS")!=string::npos,"CHoCH retains prior edited drawing with waiting status");
 g_dialog.locked=true;Action(PANEL_LOCK);
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED,"method timeframe reinit");
 Check(g_auto_method==FIBO_MARKET_STRUCTURE&&g_dialog.method==FIBO_MARKET_STRUCTURE&&g_anchor_locked&&g_end_price==17.5,"method lock and edited anchors survive timeframe change");
 // Previous schema 5 remains readable; older schemas are retired.
 Check(SaveChartSnapshot(),"method snapshot save");
 string encoded=ObjectGetString(0,"myFibo.State",OBJPROP_TEXT);
 MyFiboSnapshot legacy;
 MqlArray<string> old_fields;StringSplit(encoded,'|',old_fields);
 string old="5";for(int i=1;i<18;i++)old+="|"+old_fields[i];
 ObjectSetString(0,"myFibo.State",OBJPROP_TEXT,old);
 Check(ReadChartSnapshot(legacy)&&legacy.auto_method==FIBO_MARKET_STRUCTURE,"schema 5 upgrade compatibility");
 ObjectSetString(0,"myFibo.State",OBJPROP_TEXT,"4"+StringSubstr(old,1,StringLen(old)-3));
 Check(!ReadChartSnapshot(legacy),"retired schema rejected explicitly");
 ObjectSetString(0,"myFibo.State",OBJPROP_TEXT,old.substr(0,old.size()-1)+"9");
 Check(!ReadChartSnapshot(legacy),"invalid snapshot method rejected");
 ObjectDelete(0,"myFibo.State");
 g_dialog.locked=false;Action(PANEL_LOCK);
 BreakFixture(history,16);clock_value+=6000;RefreshAutoSwing(false);
 Check(g_start_price==13&&g_end_price==5,"new bearish BOS resumes structure selection");
 g_dialog.method=(MyFiboAutoMethod)99;Action(PANEL_SETTINGS);
 Check(g_auto_method==FIBO_MARKET_STRUCTURE&&g_dialog.method==FIBO_MARKET_STRUCTURE,"invalid GUI method restored");
 g_dialog.locked=true;Action(PANEL_LOCK);g_dialog.method=FIBO_PIVOT;Action(PANEL_SETTINGS);
 Check(g_auto_method==FIBO_PIVOT&&g_start_price==13&&g_end_price==5,"locked method changes never redraw anchors");
 g_dialog.locked=false;Action(PANEL_LOCK);
 Check(g_auto_method==FIBO_PIVOT&&g_start_price!=13,"unlock resumes selected Pivot method");
 OnDeinit(REASON_REMOVE);
 std::cout<<"PASS: structure labels, object limits, causal Pivot/Market Structure selection, CHoCH pause, method lock/persistence and schema compatibility.\n";
}
'''

UI_STUB = r'''
struct Rect {
 int left=0,top=0,right=0,bottom=0;
 void SetBound(const Rect&r){*this=r;}
};
struct CWnd;
std::map<string,CWnd*>controls;
int next_id=1;
struct CWnd {
 Rect m_rect; bool visible=true; long id=0; string text,name;
 virtual ~CWnd()=default;
 virtual bool Create(long,const string n,int,int x1,int y1,int x2,int y2){name=n;m_rect={x1,y1,x2,y2};id=next_id++;controls[n]=this;return true;}
 bool Shift(int x,int y){m_rect.left+=x;m_rect.right+=x;m_rect.top+=y;m_rect.bottom+=y;return true;}
 bool Visible(bool v){visible=v;return true;}
 long Id()const{return id;}
 bool Text(const string&s){text=s;return true;}string Text()const{return text;}
};
struct CLabel:CWnd{};struct CButton:CWnd{};
struct CComboBox:CWnd {
 std::vector<long>items;long selected=-1;
 bool AddItem(const string&,long value){items.push_back(value);if(selected==-1)selected=value;return true;}
 bool SelectByValue(long value){for(auto v:items)if(v==value){selected=v;return true;}return false;}
 long Value(){return selected;}void ListViewItems(int){}
};
struct CCheckBox:CWnd{bool checked=false;bool Checked(){return checked;}bool Checked(bool v){checked=v;return true;}};
struct CSpinEdit:CWnd{
 int value=0;
 virtual bool Create(long chart,const string name,int sub,int x1,int y1,int x2,int y2){
  if(!CWnd::Create(chart,name,sub,x1,y1,x2,y2))return false;
  text="";return true;
 }
 void MinValue(int){}void MaxValue(int){}int Value(){return value;}
 void Value(int v){if(value!=v){value=v;OnChangeValue();}}
protected:
 virtual bool OnChangeValue(){return Text(IntegerToString(value));}
};
struct CDialog:CWnd{bool OnDialogDragEnd(){return true;}};
const int TEST_MINIMIZE=4000,TEST_RESTORE=4001;
struct CAppDialog:CDialog {
 long m_chart_id=0;bool m_minimized=false;CWnd*m_drag_object=nullptr;Rect m_norm_rect;
 std::vector<CWnd*>children;
 virtual bool Create(long chart,const string name,int sub,int x1,int y1,int x2,int y2){
  m_chart_id=chart;CWnd::Create(chart,name,sub,x1,y1,x2,y2);m_norm_rect=m_rect;return true;}
 virtual bool OnEvent(int id,const long&,const double&,const string&){
  if(id==TEST_MINIMIZE){m_minimized=true;m_rect.bottom=m_rect.top+24;for(auto*c:children)c->Visible(false);return true;}
  if(id==TEST_RESTORE){m_minimized=false;m_rect=m_norm_rect;for(auto*c:children)c->Visible(true);return true;}return false;}
 bool Caption(const string&){return true;}
 bool Add(CWnd&control){control.Shift(m_rect.left,m_rect.top+30);children.push_back(&control);return true;}
 int Height()const{return m_rect.bottom-m_rect.top;}
 bool Height(int h){m_rect.bottom=m_rect.top+h;return true;}
 void MouseFocusKill(){}
 virtual string IniFileName()const{return "default";}
};
'''
UI_TESTS = r'''
void CheckUI(bool value,const char*label){if(!value){std::cerr<<"FAIL UI: "<<label<<'\n';std::abort();}}
int main(){
 CMyFiboDialog panel;CheckUI(panel.Create(0,"ui",0,12,24,592,464),"create");
 CheckUI(panel.Mode()==FIBO_MANUAL&&!panel.AnchorLocked()&&panel.AutoMethod()==FIBO_PIVOT,"default manual and unchecked");
 CheckUI(controls["ui.Timeframe"]->text=="Chart: M15","chart timeframe shown read-only");
 CheckUI(!controls["ui.Method"]->visible&&!controls["ui.Left"]->visible,"manual hides pivot controls");
 int original=controls["ui.SwingTitle"]->m_rect.top;
 panel.SetSwingStart(1.2345);panel.SetSwingEnd(1.4567);
 CheckUI(controls["ui.Start"]->text=="Awal : 1.23450"&&controls["ui.End"]->text=="Akhir : 1.45670","prices only");
 panel.SetSettings(FIBO_AUTO,PERIOD_H1,2,2,false);
 CheckUI(controls["ui.Timeframe"]->text=="Chart: H1","read-only timeframe display updates");
 CheckUI(panel.Height()==524&&controls["ui.SwingTitle"]->m_rect.top==original+84,"automatic layout height and offset");
 CheckUI(controls["ui.Method"]->visible&&controls["ui.Left"]->visible&&controls["ui.AutoMethod"]->visible,"auto shows method selector and pivots");
 CheckUI(controls["ui.Draw"]->text=="Cari Swing","auto caption");
 panel.SetStructureTrend("Bullish");
 CheckUI(controls["ui.Method"]->text=="Struktur: Bullish","structure direction is distinct from fibo direction");
 CheckUI(controls["ui.Left"]->text=="2"&&controls["ui.Right"]->text=="2","auto displays default numeric values");
 // Reproduce an empty edit with unchanged stored values, as after recreation.
 controls["ui.Left"]->text="";controls["ui.Right"]->text="";
 panel.SetSettings(FIBO_AUTO,PERIOD_H1,2,2,false);
 CheckUI(controls["ui.SwingTitle"]->m_rect.top==original+84,"idempotent layout");
 CheckUI(controls["ui.Left"]->text=="2"&&controls["ui.Right"]->text=="2","same values refresh empty edit text");
 panel.SetSettings(FIBO_MANUAL,PERIOD_H4,3,4,true);
 CheckUI(panel.Height()==440&&controls["ui.SwingTitle"]->m_rect.top==original,"manual restores compact layout");
 CheckUI(panel.AnchorLocked()&&!controls["ui.Method"]->visible,"checkbox independent of mode");
 long zero=0;double real=0;string empty;
 panel.OnEvent(TEST_MINIMIZE,zero,real,empty);panel.OnEvent(TEST_RESTORE,zero,real,empty);
 CheckUI(!controls["ui.Method"]->visible&&controls["ui.Start"]->visible,"restore keeps manual settings hidden");
 panel.OnEvent(TEST_MINIMIZE,zero,real,empty);
 panel.SetSettings(FIBO_AUTO,PERIOD_H4,3,4,true);
 CheckUI(!controls["ui.Method"]->visible,"hidden while minimized");
 panel.OnEvent(TEST_RESTORE,zero,real,empty);
 CheckUI(panel.Height()==524&&controls["ui.Method"]->visible,"restore honors automatic normal geometry");
 CheckUI(panel.LeftBars()==3&&panel.RightBars()==4&&controls["ui.Left"]->text=="3"&&controls["ui.Right"]->text=="4","mode switches preserve custom pivot values");
 CMyFiboSpinEdit recreated;
 CheckUI(recreated.Create(0,"recreated",0,0,0,80,22),"spin first creation");
 recreated.SetDisplayedValue(2);
 CheckUI(recreated.Create(0,"recreated",0,0,0,80,22),"spin recreation");
 CheckUI(recreated.Value()==2&&recreated.text.empty(),"native recreation retains value but clears text");
 recreated.SetDisplayedValue(2);
 CheckUI(recreated.text=="2","recreation refreshes unchanged default");
 panel.SetStatus("Select end",true);CheckUI(controls["ui.Draw"]->text=="Batal","selection caption");
 long lock_id=controls["ui.Lock"]->Id();panel.OnEvent(CHARTEVENT_CUSTOM+ON_CHANGE,lock_id,real,empty);
 CheckUI(panel.TakeAction()==PANEL_LOCK&&panel.TakeAction()==PANEL_NONE,"checkbox event consumed once");
 long mode_id=controls["ui.Mode"]->Id();panel.OnEvent(CHARTEVENT_CUSTOM+ON_CHANGE,mode_id,real,empty);
 CheckUI(panel.TakeAction()==PANEL_SETTINGS,"combo settings event");
 panel.SetSettings(FIBO_AUTO,PERIOD_H4,3,4,true,FIBO_MARKET_STRUCTURE);
 CheckUI(panel.AutoMethod()==FIBO_MARKET_STRUCTURE&&panel.AnchorLocked()&&panel.Height()==524,"method selector does not change geometry or lock");
 long method_id=controls["ui.AutoMethod"]->Id();panel.OnEvent(CHARTEVENT_CUSTOM+ON_CHANGE,method_id,real,empty);
 CheckUI(panel.TakeAction()==PANEL_SETTINGS,"auto method change routes to settings");
 panel.OnEvent(TEST_MINIMIZE,zero,real,empty);
 CheckUI(!controls["ui.AutoMethod"]->visible,"method selector hidden when minimized");
 panel.OnEvent(TEST_RESTORE,zero,real,empty);
 CheckUI(controls["ui.AutoMethod"]->visible&&panel.AutoMethod()==FIBO_MARKET_STRUCTURE,"method survives minimize/restore");
 std::cout<<"PASS: GUI class default controls, price-only labels, Manual/Auto layout, idempotence, minimize/restore, checkbox and combo event mapping (fake control APIs).\n";
}
'''

def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('C++17 compiler required.')
    types = adapt((ROOT/'Experts/myFibo/MyFiboTypes.mqh').read_text())
    libraries = '\n'.join(adapt((ROOT/name).read_text()) for name in (
        'Include/Swing/SwingTypes.mqh', 'Include/Swing/SwingDetector.mqh',
        'Include/Structure/MarketStructure.mqh',
        'Include/Fibo/Fibonacci.mqh', 'Experts/myFibo/MyFiboAuto.mqh',
        'Experts/myFibo/MyFiboChart.mqh', 'Experts/myFibo/MyFiboState.mqh'))
    source = adapt((ROOT/'Experts/myFibo/myFibo.mq5').read_text())
    source = source.replace('string fields[];', 'MqlArray<string> fields;')
    source = source.replace('const color FIBO_COLOR', 'const int FIBO_COLOR')
    signatures = re.findall(r'^(?:bool|void|int|string)\s+\w+\([^{};]*\)\s*\{', source, flags=re.M)
    prototypes = '\n'.join(re.sub(r'=\s*(true|false)', '', sig[:-1].strip())+';' for sig in signatures)
    code = SHIM + PLATFORM + types + libraries + DIALOG + '\nstruct MyFiboSnapshot;\n' + prototypes + source + TESTS
    with tempfile.TemporaryDirectory(prefix='myfibo-modes-') as folder:
        cpp = Path(folder)/'checks.cpp';binary = Path(folder)/'checks';cpp.write_text(code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined','-fno-sanitize-recover=all', str(cpp), '-o',str(binary)],check=True)
        subprocess.run([str(binary)],check=True)
        helper = TESTS[:TESTS.index('int main(){')]
        review_code = SHIM + PLATFORM + types + libraries + DIALOG + '\nstruct MyFiboSnapshot;\n' + prototypes + source + helper + REVIEW_TESTS
        cpp.write_text(review_code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined','-fno-sanitize-recover=all',str(cpp),'-o',str(binary)],check=True)
        subprocess.run([str(binary)],check=True)
        ui_platform = PLATFORM.replace('const ENUM_TIMEFRAMES _Period', '[[maybe_unused]] const ENUM_TIMEFRAMES _Period')
        native_checks = (ROOT/'Scripts/Structure/MarketStructureExample.mq5').read_text()
        break_fixture = adapt(native_checks[native_checks.index('void BreakFixture('):native_checks.index('void RunBreakChecks(')])
        structure_code = SHIM + PLATFORM + types + libraries + DIALOG + '\nstruct MyFiboSnapshot;\n' + prototypes + source + helper + break_fixture + STRUCTURE_TESTS
        cpp.write_text(structure_code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                        str(cpp), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
        ui_header = adapt((ROOT/'Experts/myFibo/MyFiboDialog.mqh').read_text())
        ui_code = SHIM + ui_platform + types + libraries + UI_STUB + ui_header + UI_TESTS
        cpp.write_text(ui_code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined','-fno-sanitize-recover=all',str(cpp),'-o',str(binary)],check=True)
        subprocess.run([str(binary)],check=True)
    header = (ROOT/'Experts/myFibo/MyFiboDialog.mqh').read_text()
    assert 'TimeToString' not in header and 'TimeToString' not in source
    assert 'CPanel' not in header
    assert 'CComboBox m_mode' in header and 'CCheckBox m_lock' in header
    assert 'm_lock.Checked(false)' in header and 'return CAppDialog' not in source
    assert '.OnMouseEvent(' not in source and 'ShouldDispatch' not in source
    assert "CComboBox m_timeframe" not in header and "g_dialog.Timeframe()" not in source
    assert source.count('g_dialog.ChartEvent(id, lparam, dparam, sparam);')==1
    print('Source contracts checked; native GUI rendering and Windows compilation remain untested.')


if __name__ == '__main__':
    main()
