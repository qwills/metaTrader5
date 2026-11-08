#!/usr/bin/env python3
"""Exercise manualFibo source with the existing C++/fake MT5 adapters, not MetaEditor."""
from pathlib import Path
import shutil
import subprocess
import tempfile
from check_swing_detector import SHIM, adapt
from mt5_adapter import PLATFORM, UI_STUB

ROOT = Path(__file__).resolve().parents[1]
EXTRA = r'''
const int OBJ_ALL_PERIODS=0x1fffff;
const int BORDER_FLAT=0,clrSilver=0xc0c0c0;
const int CHARTEVENT_OBJECT_ENDEDIT=6100,ACCOUNT_EQUITY=1,ACCOUNT_CURRENCY=2;
const int SYMBOL_VOLUME_STEP=1,SYMBOL_VOLUME_MIN=2,SYMBOL_VOLUME_MAX=3,SYMBOL_TRADE_TICK_SIZE=4,SYMBOL_POINT=5,SYMBOL_TRADE_STOPS_LEVEL=6;
enum ENUM_ORDER_TYPE {ORDER_TYPE_BUY,ORDER_TYPE_SELL};
using ushort=unsigned short;
double equity=10000,volume_step=.01,volume_min=.01,volume_max=100,tick_size=.00001,profit_factor=100;
double bid=19.9,ask=20,point_size=.01;
long stops_level=0;bool quote_failure=false,stops_failure=false;
int quote_reads=0,stops_reads=0;
struct MqlTick {datetime time;double bid,ask;};
bool SymbolInfoTick(const string&,MqlTick&quote){++quote_reads;if(quote_failure)return false;quote={1700000000,bid,ask};return true;}
bool SymbolInfoInteger(const string&,int,long&value){++stops_reads;if(stops_failure)return false;value=stops_level;return true;}
bool profit_failure=false;int profit_calls=0,account_reads=0,symbol_reads=0;
double AccountInfoDouble(int){++account_reads;return equity;}
string AccountInfoString(int){return "USD";}
double SymbolInfoDouble(const string&,int prop){
 ++symbol_reads;
 if(prop==SYMBOL_VOLUME_STEP)return volume_step;if(prop==SYMBOL_VOLUME_MIN)return volume_min;
 if(prop==SYMBOL_VOLUME_MAX)return volume_max;if(prop==SYMBOL_POINT)return point_size;return tick_size;
}
bool OrderCalcProfit(ENUM_ORDER_TYPE side,const string&,double volume,double entry,double close,double&profit){
 if(side!=ORDER_TYPE_BUY&&side!=ORDER_TYPE_SELL)std::abort();
 ++profit_calls;if(profit_failure||volume<volume_min-1e-12||volume>volume_max+1e-12)return false;
 profit=(close-entry)*volume*profit_factor*(side==ORDER_TYPE_BUY?1:-1);return true;
}
double MathRound(double v){return std::round(v);}double MathFloor(double v){return std::floor(v);}
double MathMin(double a,double b){return std::min(a,b);}
double NormalizeDouble(double v,int digits){double scale=std::pow(10.,digits);return std::round(v*scale)/scale;}
int StringTrimLeft(string&s){auto old=s.size();s.erase(0,s.find_first_not_of(" \t\r\n"));return old-s.size();}
int StringTrimRight(string&s){auto old=s.size();auto last=s.find_last_not_of(" \t\r\n");s.erase(last==string::npos?0:last+1);return old-s.size();}
ushort StringGetCharacter(const string&s,int i){return s.at(i);}
'''
# The native GUI implementation is supplied by the user's terminal. Model only
# the documented lifecycle, forwarding and geometry needed by controller tests.
UI = UI_STUB + r'''
struct CEdit:CWnd {bool ReadOnly(bool){return true;}};
struct CPanel:CWnd {
 bool BorderType(int){return true;}
 bool ColorBackground(int){return true;}
 bool ColorBorder(int){return true;}
};
'''
UI = UI.replace('m_chart_id=chart;CWnd::Create', 'children.clear();m_chart_id=chart;CWnd::Create')
UI = UI.replace('long Id()const{return id;}', '''long Id()const{return id;}
 bool IsVisible()const{return visible;}
 bool Contains(int x,int y)const{return x>=m_rect.left&&x<m_rect.right&&y>=m_rect.top&&y<m_rect.bottom;}''')
UI = UI.replace(' bool Caption(', ''' static inline std::map<int,Rect> saved;
 bool Run(){return true;}
 void Minimized(bool value){m_minimized=value;}
 void Destroy(int){saved[chart_context]=m_rect;}
 void IniFileLoad(){if(saved.count(chart_context))m_rect=saved[chart_context];}
 void ChartEvent(int id,const long&l,const double&d,const string&s){++native_calls;OnEvent(id,l,d,s);}
 bool Caption(''')
TESTS = r'''
void Check(bool ok,const char*label){if(!ok){std::cerr<<"FAIL: "<<label<<'\n';std::abort();}}
void Action(const string&control,int event){long id=controls["manualFibo.Panel."+control]->Id();OnChartEvent(CHARTEVENT_CUSTOM+event,id,0,"");}
void Tick(int index,bool enabled){static_cast<CCheckBox*>(controls["manualFibo.Panel.Level"+IntegerToString(index)])->Checked(enabled);Action("Level"+IntegerToString(index),ON_CHANGE);}
void Edit(const string&control,const string&text){
 controls["manualFibo.Panel."+control]->Text(text);
 OnChartEvent(CHARTEVENT_OBJECT_ENDEDIT,0,0,"manualFibo.Panel."+control);
}
void Click(int x,int y){OnChartEvent(CHARTEVENT_CLICK,x,y,"");}
int main(){
 Check(OnInit()==INIT_SUCCEEDED,"initialize");
 Check(g_dialog.children.size()==56&&controls.size()==57,"unique control registration");
 for(size_t i=0;i<g_dialog.children.size();i++){
  auto*a=g_dialog.children[i];
  Check(a->name.find(".Background")==string::npos,"no title background objects");
  for(size_t j=i+1;j<g_dialog.children.size();j++){
   auto*b=g_dialog.children[j];Check(a->Id()!=b->Id()&&a->name!=b->name,"unique IDs and names");
  }
 }
 for(const string &group:{string("Swing"),string("Risk"),string("Fibo")}){
  auto*title=controls["manualFibo.Panel."+group+"Title"];
  auto*left=controls["manualFibo.Panel."+group+"Group.TopLeft"];
  auto*right=controls["manualFibo.Panel."+group+"Group.TopRight"];
  Check(left->m_rect.bottom-left->m_rect.top==1&&right->m_rect.bottom-right->m_rect.top==1,"thin border edges");
  Check(left->m_rect.right<title->m_rect.left&&right->m_rect.left>title->m_rect.right,"border gap clears title");
 }
 OnChartEvent(TEST_MINIMIZE,0,0,"");
 for(auto*c:g_dialog.children)Check(!c->visible,"all controls hide when minimized");
 OnChartEvent(TEST_RESTORE,0,0,"");
 for(auto*c:g_dialog.children)Check(c->visible,"all controls restore together");
 int redraws=redraw_count;Status("Klik Pilih Swing.");Status("Klik Pilih Swing.");
 Check(redraw_count==redraws,"unchanged status does not redraw");
 Check(controls.count("manualFibo.Panel.Direction")==0,"direction control stays removed");
 Check(!g_model.Ready()&&!g_model.Locked()&&g_model.Mask()==28,"default mask/unlocked");
 Check(g_model.RiskPercent()==5&&controls["manualFibo.Panel.Risk"]->text=="5","default 5 percent equity risk");
 Check(controls.count("manualFibo.Panel.Level5")==1&&controls["manualFibo.Panel.Level5"]->text=="88.6%: -","88.6 checkbox");
 Check(controls.count("manualFibo.Panel.Mode")==0,"manual-only dialog");
 int calls=native_calls,writes=object_writes,profits=profit_calls;
 for(int i=0;i<1000;i++)OnChartEvent(CHARTEVENT_MOUSE_MOVE,550,700,"0");
 Check(native_calls==calls+1000&&copy_calls==0&&object_writes==writes&&profit_calls==profits,"mouse dispatch has no redraw/data work");
 geometry_enabled=true;ArrayResize(history,12);
 for(int i=0;i<12;i++){history[i]={};history[i].time=1700000000+i*60;history[i].high=10+i;history[i].low=1+i;}
 Action("Draw",ON_CLICK);Check(g_selection==MANUAL_START,"start selection");
 Click(30,60);Check(g_selection==MANUAL_START,"panel click cannot become anchor");
 Click(110,890);Check(g_selection==MANUAL_END&&g_pick_price==11,"first candle high");
 Click(110,890);Check(g_selection==MANUAL_END&&!g_model.Ready(),"equal endpoint rejected");
 int finishing_profits=profit_calls;
 Click(190,810);Check(g_model.Ready()&&g_model.StartPrice()==11&&g_model.EndPrice()==19,"manual candle anchors");
 Check(g_selection==MANUAL_IDLE&&!g_scroll_locked,"selection restores scrolling");
 Check(profit_calls-finishing_profits==6,"completing selection calculates each checked level only once");
 int reads=account_reads,metadata=symbol_reads,quotes=quote_reads,stops=stops_reads;OnTimer();
 Check(account_reads-reads==1&&symbol_reads-metadata==5&&quote_reads-quotes==1&&stops_reads-stops==1,"one account/symbol/quote snapshot per full refresh");
 Check(controls.count("manualFibo.Panel.OrderHeader")==0,"no per-level order column");
 int idle_profits=profit_calls;OnChartEvent(TEST_MINIMIZE,0,0,"");equity=20000;
 reads=account_reads;metadata=symbol_reads;OnTimer();
 Check(profit_calls==idle_profits&&account_reads==reads&&symbol_reads==metadata,"no broker work while minimized");
 OnChartEvent(TEST_RESTORE,0,0,"");
 Check(controls["manualFibo.Panel.Lot2"]->text=="2.50","restore refreshes changed equity immediately");
 equity=10000;OnTimer();
 bid=14;ask=14.1;OnTimer();
 Check(controls["manualFibo.Panel.Lot2"]->text=="SL invalid"&&controls["manualFibo.Panel.Loss2"]->text=="-","live quote crossing clears stale BUY preview");
 Edit("SL2","17");Check(controls["manualFibo.Panel.Lot2"]->text=="2.50","SELL preview uses edited SL above entry");
 bid=19.9;ask=20;Edit("SL2","");
 for(int i=0;i<6;i++)Check(g_model.StopPrice(i)==11&&!g_model.StopCustom(i),"SL defaults to swing start");
 Check(controls["manualFibo.Panel.SL2"]->text=="11.00000","SL price displayed");
 Edit("SL2","11.00000");Check(!g_model.StopCustom(2),"focus without change does not freeze default SL");
 Check(controls["manualFibo.Panel.Lot2"]->text=="1.25"&&controls["manualFibo.Panel.Loss2"]->text=="500.00","5 percent lot preview at 50 percent entry");
 controls["manualFibo.Panel.SL5"]->Text("draft-stop");
 int risk_profits=profit_calls;Edit("Risk","5.0");
 Check(profit_calls==risk_profits&&controls["manualFibo.Panel.Risk"]->text=="5","unchanged risk canonicalizes without recalculation");
 Edit("Risk","bad");
 Check(controls["manualFibo.Panel.SL5"]->text=="draft-stop","invalid risk restores only its own field");
 Edit("SL5","");
 Edit("Risk","2");Check(g_model.RiskPercent()==2&&controls["manualFibo.Panel.Lot2"]->text=="0.50","risk edit recalculates lots");
 Edit("SL2","13");Check(g_model.StopCustom(2)&&g_model.StopPrice(2)==13&&controls["manualFibo.Panel.Lot2"]->text=="1.00","custom SL recalculates only that row");
 Edit("Risk","2oops");Check(g_model.RiskPercent()==2&&controls["manualFibo.Panel.Risk"]->text=="2","malformed risk restored");
 Edit("SL2","0");Check(g_model.StopPrice(2)==13&&controls["manualFibo.Panel.SL2"]->text=="13.00000","invalid SL text restored");
 Edit("SL2","15");Check(controls["manualFibo.Panel.Lot2"]->text=="SL invalid","SL equal to entry has no lot");
 Edit("SL2","");Check(!g_model.StopCustom(2)&&g_model.StopPrice(2)==11,"cleared SL resumes default");
 Edit("SL5","12");Check(g_model.StopCustom(5)&&controls["manualFibo.Panel.Lot5"]->text=="-","disabled row can keep a custom SL");
 controls["manualFibo.Panel.SL2"]->Text("draft");equity=20000;OnTimer();
 Check(controls["manualFibo.Panel.Lot2"]->text=="1.00"&&controls["manualFibo.Panel.SL2"]->text=="draft","timer updates equity without overwriting unfinished edits");
 equity=10000;Edit("SL2","");
 string name=g_chart.Name();auto &node=Objects()[name];
 Check(node.ints[{OBJPROP_LEVELS,0}]==3&&node.ints[{OBJPROP_BACK,0}]==1,"default black background object levels");
 Tick(5,true);Check(g_model.Enabled(5)&&node.ints[{OBJPROP_LEVELS,0}]==4,"enable 88.6");
 Check(std::abs(node.doubles[{OBJPROP_LEVELVALUE,3}]-.886)<1e-12,"88.6 ratio mapping");
 Check(std::abs(g_model.Price(5)-(19-8*.886))<1e-12,"88.6 calculation");
 Check(controls.count("manualFibo.Panel.Level6")==0&&controls.count("manualFibo.Panel.Level7")==0,"only six checkboxes");
 Check(FiboRatio(0)==.236&&FiboRatio(5)==.886,"no 0 or 100 percent ratios");
 for(int i=0;i<6;i++)Tick(i,true);
 Check(node.ints[{OBJPROP_LEVELS,0}]==6&&g_model.Mask()==63,"all six levels enabled");
 for(int i=0;i<6;i++)Tick(i,false);
 Check(g_model.Mask()==0&&node.ints[{OBJPROP_TIMEFRAMES,0}]==OBJ_NO_PERIODS&&g_model.Ready(),"all unchecked hides drawing but keeps anchors");
 int hidden_profits=profit_calls,hidden_metadata=symbol_reads;OnTimer();
 Check(profit_calls==hidden_profits&&symbol_reads==hidden_metadata,"no symbol/profit work with no checked levels");
 Tick(5,true);Check(node.ints[{OBJPROP_TIMEFRAMES,0}]==OBJ_ALL_PERIODS,"re-enable restores drawing");
 bid=9.9;ask=10;node.prices[0]=25;node.prices[1]=10;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,name);
 Check(g_model.StartPrice()==25&&g_model.EndPrice()==10&&std::abs(g_model.Price(5)-23.29)<1e-12,"native bearish edit recalculates");
 Check(g_model.StopPrice(2)==25&&g_model.StopPrice(5)==12&&controls["manualFibo.Panel.Lot5"]->text=="SL invalid","default SL follows anchors, custom remains fixed with direction validation");
 Edit("SL5","");Check(g_model.StopPrice(5)==25&&!g_model.StopCustom(5),"restore bearish default");
 node.prices[1]=25;OnChartEvent(CHARTEVENT_OBJECT_CHANGE,0,0,name);
 Check(g_model.EndPrice()==10&&Objects()[name].prices[1]==10,"invalid native edit restored");
 auto *lock=static_cast<CCheckBox*>(controls["manualFibo.Panel.Lock"]);
 lock->Checked(true);Action("Lock",ON_CHANGE);
 Check(g_model.Locked()&&node.ints[{OBJPROP_SELECTABLE,0}]==0,"explicit anchor lock");
 Action("Draw",ON_CLICK);Check(g_selection==MANUAL_IDLE,"locked cannot replace swing");
 Tick(2,true);Check(g_model.Enabled(2)&&g_model.StartPrice()==25,"levels remain editable while anchors locked");
 fail_config=true;Tick(3,true);Check(!g_model.Enabled(3)&&g_dialog.RatioMask()==g_model.Mask(),"failed ratio write rolls back GUI/model");
 lock->Checked(false);Action("Lock",ON_CHANGE);
 Action("Draw",ON_CLICK);Click(120,880);
 OnChartEvent(CHARTEVENT_KEYDOWN,27,0,"");
 Check(g_model.StartPrice()==25&&g_model.EndPrice()==10&&g_selection==MANUAL_IDLE&&!g_scroll_locked,"cancel keeps previous drawing");
 lock->Checked(true);Action("Lock",ON_CHANGE);
 Edit("SL3","30");
 g_dialog.m_rect={50,70,670,554};int mask=g_model.Mask();
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H4;
 Check(OnInit()==INIT_SUCCEEDED&&g_model.StartPrice()==25&&g_model.EndPrice()==10&&g_model.Mask()==mask,"timeframe handoff retains anchors/ratios");
 Check(g_model.Locked()&&g_dialog.AnchorLocked(),"lock survives timeframe change");
 Check(g_model.RiskPercent()==2&&g_model.StopCustom(3)&&g_model.StopPrice(3)==30,"risk and SL override survive timeframe change");
 Check(g_dialog.m_rect.left==50&&g_dialog.m_rect.top==70,"native GUI position loaded");
 Check(g_storage.Save(g_model,_Symbol),"create legacy handoff fixture");
 CFiboModel legacy;
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"1|EURUSD|255|0|1|100|25|200|10");
 Check(g_storage.Load(legacy,_Symbol)&&legacy.Mask()==63&&legacy.StartPrice()==25&&legacy.RiskPercent()==5&&legacy.CustomStops()==0,"legacy mask migration drops endpoint bits");
 CFiboModel loaded;Check(g_storage.Save(g_model,_Symbol),"save state");
 Check(!g_storage.Load(loaded,"GBPUSD"),"symbol mismatch rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"2|EURUSD|64|0|0|0|0|0|0");
 Check(!g_storage.Load(loaded,_Symbol),"invalid mask rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"2|EURUSD|28|0|1|100|bad|200|10");
 Check(!g_storage.Load(loaded,_Symbol),"malformed numeric state rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"3|EURUSD|28|0|1|100|100|200|200|101|0|0|0|0|0|0|0");
 Check(!g_storage.Load(loaded,_Symbol),"invalid saved risk rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"2|EURUSD|28|0|0|100|bad|200|10");
 Check(!g_storage.Load(loaded,_Symbol),"empty state rejects stale anchors");
 string tiny_risk=StringFormat("%.17g",.000000001);
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"3|EURUSD|28|0|1|100|100|200|200|"+tiny_risk+"|0|0|0|0|0|0|0");
 Check(g_storage.Load(loaded,_Symbol)&&loaded.Ready()&&loaded.StartPrice()==100&&loaded.RiskPercent()==0,"legacy subprecision risk migrates without losing drawing");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"4|EURUSD|28|0|1|100|100|200|200|"+tiny_risk+"|0|0|0|0|0|0|0");
 Check(!g_storage.Load(loaded,_Symbol)&&loaded.StartPrice()==100,"new state rejects invalid precision atomically");g_storage.Consume();
 ObjectDelete(0,name);OnChartEvent(CHARTEVENT_OBJECT_DELETE,0,0,name);
 Check(!g_model.Ready(),"native deletion clears display/model");
 Action("Reset",ON_CLICK);Check(g_model.Mask()==mask&&!g_model.Ready(),"reset retains ratio choices");
 OnDeinit(REASON_CHARTCHANGE);_Symbol="GBPUSD";
 Check(OnInit()==INIT_SUCCEEDED&&!g_model.Ready()&&g_model.Mask()==28,"symbol change starts fresh");
 ChartSetInteger(0,CHART_MOUSE_SCROLL,false);g_init_scroll=false;
 Action("Draw",ON_CLICK);Check(g_selection==MANUAL_START,"fresh selection");
 OnChartEvent(CHARTEVENT_KEYDOWN,27,0,"");Check(!ChartGetInteger(0,CHART_MOUSE_SCROLL),"preexisting disabled scrolling restored");
 OnDeinit(REASON_REMOVE);Check(Objects().empty(),"removal clears owned objects");
 Check(CFibonacci().LevelCount()==7,"shared Fibonacci defaults unchanged");
 bid=209.9;ask=210;
 CFiboModel risk_model;risk_model.SetAnchors(100,100,200,200);risk_model.SetMask(63);
 CFiboRisk calculator;FiboLot result;
 Check(calculator.Calculate(risk_model,2,result)&&result.volume==.1&&result.loss<=500,"risk estimate respects budget");
 equity=1;Check(!calculator.Calculate(risk_model,2,result)&&result.volume==0&&result.error=="Min lot","minimum lot is never rounded up");
 equity=10000;profit_factor=1;volume_step=.25;volume_min=.25;volume_max=10;risk_model.SetRiskPercent(.3);
 Check(calculator.Calculate(risk_model,2,result)&&result.volume==.5&&result.loss==25,"nondecimal volume step rounds down");
 volume_max=.4;Check(calculator.Calculate(risk_model,2,result)&&result.volume==.25,"maximum volume cap respects step");
 tick_size=.25;risk_model.SetStop(2,100.14);
 Check(calculator.Calculate(risk_model,2,result)&&result.stop==100.25,"prices normalized to symbol tick");
 profit_failure=true;Check(!calculator.Calculate(risk_model,2,result)&&result.volume==0&&result.error=="Data?","calculation failure clears preview");
 profit_failure=false;volume_step=0;Check(!calculator.Calculate(risk_model,2,result)&&result.volume==0,"invalid symbol metadata rejected");
 double parsed=99;Check(!FiboParseNumber("1,5",parsed)&&parsed==99&&!FiboParseNumber("nan",parsed),"strict decimal parser");
 Check(!risk_model.SetRiskPercent(101)&&!risk_model.SetRiskPercent(-1),"risk percentage bounds");
 double previous=risk_model.RiskPercent();
 Check(!risk_model.SetRiskPercent(.000000001)&&risk_model.RiskPercent()==previous,"invisible subprecision risk rejected without changing model");
 Check(risk_model.SetRiskPercent(.00000001),"eight-decimal risk remains supported");
 volume_step=.00000001;volume_min=volume_step;volume_max=10;
 FiboRiskContext context;calculator.ReadContext(risk_model,context);
 Check(context.valid&&context.volume_digits==8,"eight-decimal lot step is recognized");
 volume_step=.000000001;calculator.ReadContext(risk_model,context);
 Check(!context.valid,"unsupported volume precision is rejected");
 equity=10000;profit_factor=100;volume_step=.01;volume_min=.01;volume_max=100;tick_size=.01;
 CFiboModel limits;limits.SetAnchors(100,100,200,200);limits.SetMask(63);
 bid=160;ask=161;stops_level=0;
 Check(calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_BUY,"entry below quote is BUY LIMIT");
 bid=140;ask=141;
 Check(!calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_SELL&&result.error=="SL invalid"&&result.volume==0,"direction follows quote even for bullish anchors");
 limits.SetStop(2,180);
 Check(calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_SELL,"custom SL allows SELL LIMIT on bullish swing");
 bid=149;ask=151;int spread_profits=profit_calls;
 Check(!calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_NONE&&result.error=="Spread"&&result.volume==0&&profit_calls==spread_profits,"spread rejected without any fallback order");
 bid=150;ask=151;Check(!calculator.Calculate(limits,2,result)&&result.error=="Spread","entry at Bid is unavailable");
 bid=149;ask=150;Check(!calculator.Calculate(limits,2,result)&&result.error=="Spread","entry at Ask is unavailable");
 stops_level=100;bid=149;ask=149.5;
 Check(calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_SELL,"SELL market distance boundary accepted");
 stops_level=101;Check(!calculator.Calculate(limits,2,result)&&result.error=="Near market"&&result.volume==0,"SELL too near market blocked");
 limits.ResetStop(2);stops_level=100;bid=150.5;ask=151;
 Check(calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_BUY,"BUY market distance boundary accepted");
 stops_level=101;Check(!calculator.Calculate(limits,2,result)&&result.error=="Near market","BUY too near market blocked");
 stops_level=100;limits.SetStop(2,149.5);
 Check(!calculator.Calculate(limits,2,result)&&result.error=="SL too close","minimum SL distance enforced");
 limits.SetStop(2,149);Check(calculator.Calculate(limits,2,result),"SL distance boundary accepted");
 quote_failure=true;Check(!calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_NONE&&result.error=="Quotes?"&&result.volume==0,"missing quote clears preview");
 quote_failure=false;bid=152;ask=151;
 Check(!calculator.Calculate(limits,2,result)&&result.error=="Quotes?","crossed quote rejected");
 bid=150.5;ask=151;stops_failure=true;
 Check(!calculator.Calculate(limits,2,result)&&result.error=="Data?","missing broker stops data rejected");
 stops_failure=false;stops_level=0;limits.SetAnchors(100,200,200,100);limits.SetStop(2,100);bid=160;ask=161;
 Check(calculator.Calculate(limits,2,result)&&result.kind==FIBO_LIMIT_BUY,"BUY LIMIT also independent of bearish swing direction");
 tick_size=1;limits.SetAnchors(100,100,200,200.98);bid=149.9;ask=150.3;
 Check(!calculator.Calculate(limits,2,result)&&result.error=="Spread","classify normalized entry rather than raw Fibonacci price");
 Check(!timer,"timer stopped on removal");
 std::cout<<"PASS: limit-only direction, quote/spread/stops validation, equity risk/SL/lots, native geometry/GUI, timer and timeframe persistence.\n";
}
'''


def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('C++17 compiler required.')
    names = ['Include/_common/Fibo/Fibonacci.mqh', 'Include/_common/Fibo/FiboModel.mqh',
             'Include/_common/Fibo/FiboRisk.mqh', 'Include/_common/Fibo/FiboDialog.mqh', 'Include/_common/Fibo/FiboChart.mqh',
             'Include/_common/Fibo/FiboState.mqh', 'Experts/manualFibo/manualFibo.mq5']
    for source in names:
        text = (ROOT/source).read_text()
        for forbidden in ('ORDER_TYPE_BUY_STOP', 'ORDER_TYPE_SELL_STOP', 'OrderSend(', 'OrderSendAsync('):
            assert forbidden not in text, (source, forbidden)
    platform = PLATFORM.replace('void ChartRedraw(int=0){}', 'int redraw_count=0;void ChartRedraw(int=0){++redraw_count;}')
    # MQL accepts fixed arrays through array references; use an equivalent fixed
    # C++ array reference for the five native CPanel edge controls.
    code = SHIM + platform + EXTRA + UI + '\n'.join(
        adapt((ROOT/name).read_text().replace('CPanel &edges[]', 'CPanel (&edges)[5]'))
        for name in names) + TESTS
    with tempfile.TemporaryDirectory(prefix='manualfibo-checks-') as folder:
        cpp = Path(folder)/'checks.cpp'
        binary = Path(folder)/'checks'
        cpp.write_text(code)
        subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                        str(cpp), '-o', str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print('C++ adapter checks passed; native MQL5/GUI and Windows installer remain untested.')


if __name__ == '__main__':
    main()
