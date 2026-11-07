#!/usr/bin/env python3
"""Exercise manualFibo source with the existing C++/fake MT5 adapters, not MetaEditor."""
from pathlib import Path
import shutil
import subprocess
import tempfile
from check_swing_detector import SHIM, adapt
from check_myfibo_modes import PLATFORM, UI_STUB

ROOT = Path(__file__).resolve().parents[1]
EXTRA = r'''
const int OBJ_ALL_PERIODS=0x1fffff;
const int BORDER_FLAT=0,CONTROLS_DIALOG_COLOR_BG=0xf0f0f0,clrSilver=0xc0c0c0;
'''
# The native GUI implementation is supplied by the user's terminal. Model only
# the documented lifecycle, forwarding and geometry needed by controller tests.
UI = UI_STUB + r'''
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
void Click(int x,int y){OnChartEvent(CHARTEVENT_CLICK,x,y,"");}
int main(){
 Check(OnInit()==INIT_SUCCEEDED,"initialize");
 Check(!g_model.Ready()&&!g_model.Locked()&&g_model.Mask()==28,"default mask/unlocked");
 Check(controls.count("manualFibo.Panel.Level5")==1&&controls["manualFibo.Panel.Level5"]->text=="88.6%: -","88.6 checkbox");
 Check(controls.count("manualFibo.Panel.Mode")==0,"manual-only dialog");
 int calls=native_calls,writes=object_writes;
 for(int i=0;i<1000;i++)OnChartEvent(CHARTEVENT_MOUSE_MOVE,550,700,"0");
 Check(native_calls==calls+1000&&copy_calls==0&&object_writes==writes,"mouse dispatch has no redraw/data work");
 geometry_enabled=true;ArrayResize(history,12);
 for(int i=0;i<12;i++){history[i]={};history[i].time=1700000000+i*60;history[i].high=10+i;history[i].low=1+i;}
 Action("Draw",ON_CLICK);Check(g_selection==MANUAL_START,"start selection");
 Click(30,60);Check(g_selection==MANUAL_START,"panel click cannot become anchor");
 Click(110,890);Check(g_selection==MANUAL_END&&g_pick_price==11,"first candle high");
 Click(110,890);Check(g_selection==MANUAL_END&&!g_model.Ready(),"equal endpoint rejected");
 Click(190,810);Check(g_model.Ready()&&g_model.StartPrice()==11&&g_model.EndPrice()==19,"manual candle anchors");
 Check(g_selection==MANUAL_IDLE&&!g_scroll_locked,"selection restores scrolling");
 string name=g_chart.Name();auto &node=Objects()[name];
 Check(node.ints[{OBJPROP_LEVELS,0}]==3&&node.ints[{OBJPROP_BACK,0}]==1,"default black background object levels");
 Tick(5,true);Check(g_model.Enabled(5)&&node.ints[{OBJPROP_LEVELS,0}]==4,"enable 88.6");
 Check(std::abs(node.doubles[{OBJPROP_LEVELVALUE,3}]-.886)<1e-12,"88.6 ratio mapping");
 Check(std::abs(g_model.Price(5)-(19-8*.886))<1e-12,"88.6 calculation");
 Check(controls.count("manualFibo.Panel.Level6")==0&&controls.count("manualFibo.Panel.Level7")==0,"only six checkboxes");
 Check(ManualFiboRatio(0)==.236&&ManualFiboRatio(5)==.886,"no 0 or 100 percent ratios");
 for(int i=0;i<6;i++)Tick(i,true);
 Check(node.ints[{OBJPROP_LEVELS,0}]==6&&g_model.Mask()==63,"all six levels enabled");
 for(int i=0;i<6;i++)Tick(i,false);
 Check(g_model.Mask()==0&&node.ints[{OBJPROP_TIMEFRAMES,0}]==OBJ_NO_PERIODS&&g_model.Ready(),"all unchecked hides drawing but keeps anchors");
 Tick(5,true);Check(node.ints[{OBJPROP_TIMEFRAMES,0}]==OBJ_ALL_PERIODS,"re-enable restores drawing");
 node.prices[0]=25;node.prices[1]=10;
 OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,name);
 Check(g_model.StartPrice()==25&&g_model.EndPrice()==10&&std::abs(g_model.Price(5)-23.29)<1e-12,"native bearish edit recalculates");
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
 g_dialog.m_rect={50,70,450,570};int mask=g_model.Mask();
 OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H4;
 Check(OnInit()==INIT_SUCCEEDED&&g_model.StartPrice()==25&&g_model.EndPrice()==10&&g_model.Mask()==mask,"timeframe handoff retains anchors/ratios");
 Check(g_model.Locked()&&g_dialog.AnchorLocked(),"lock survives timeframe change");
 Check(g_dialog.m_rect.left==50&&g_dialog.m_rect.top==70,"native GUI position loaded");
 Check(g_storage.Save(g_model,_Symbol),"create legacy handoff fixture");
 CManualFiboModel legacy;
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"1|EURUSD|255|0|1|100|25|200|10");
 Check(g_storage.Load(legacy,_Symbol)&&legacy.Mask()==63&&legacy.StartPrice()==25,"legacy mask migration drops endpoint bits");
 CManualFiboModel loaded;Check(g_storage.Save(g_model,_Symbol),"save state");
 Check(!g_storage.Load(loaded,"GBPUSD"),"symbol mismatch rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"2|EURUSD|64|0|0|0|0|0|0");
 Check(!g_storage.Load(loaded,_Symbol),"invalid mask rejected");
 ObjectSetString(0,"manualFibo.State",OBJPROP_TEXT,"2|EURUSD|28|0|1|100|bad|200|10");
 Check(!g_storage.Load(loaded,_Symbol),"malformed numeric state rejected");g_storage.Consume();
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
 std::cout<<"PASS: manual candle geometry, ratio checkboxes/88.6, native edits, lock/cancel, rollback, timeframe handoff and cleanup.\n";
}
'''


def main():
    compiler = shutil.which('clang++') or shutil.which('g++')
    if not compiler:
        raise SystemExit('C++17 compiler required.')
    names = ['Include/Fibo/Fibonacci.mqh', 'Experts/manualFibo/ManualFiboModel.mqh',
             'Experts/manualFibo/ManualFiboDialog.mqh', 'Experts/manualFibo/ManualFiboChart.mqh',
             'Experts/manualFibo/ManualFiboState.mqh', 'Experts/manualFibo/manualFibo.mq5']
    code = SHIM + PLATFORM + EXTRA + UI + '\n'.join(adapt((ROOT/name).read_text()) for name in names) + TESTS
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
