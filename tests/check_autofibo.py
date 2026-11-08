#!/usr/bin/env python3
"""Check the automatic-only controller and real GUI declarations via fake MT5 APIs."""
from pathlib import Path
import re, shutil, subprocess, tempfile
from check_swing_detector import SHIM, adapt
from mt5_adapter import PLATFORM
from check_manualfibo import EXTRA, UI

ROOT = Path(__file__).resolve().parents[1]

LAYOUT_EXTRA = r'''
const int CHART_HEIGHT_IN_PIXELS=6200,CONTROLS_BORDER_WIDTH=1;
int child_layout_events=0;
'''
# Model the native documented resize/minimize branch, without changing the
# shared manualFibo test platform. This remains a fake, not native rendering.
AUTO_UI = UI.replace('name=n;m_rect=', 'visible=true;name=n;m_rect=')
AUTO_UI = AUTO_UI.replace('struct CDialog:CWnd{bool OnDialogDragEnd()',
    'struct CDialog:CWnd{virtual bool OnEvent(int id,const long&,const double&,const string&){if(id==CHARTEVENT_CHART_CHANGE)++child_layout_events;return false;}bool OnDialogDragEnd()')
_start=AUTO_UI.index('struct CAppDialog:')
_end=AUTO_UI.index('\n};',_start)+3
_app=AUTO_UI[_start:_end]
_app=_app.replace('OnEvent(int id,const long&,const double&,const string&)', 'OnEvent(int id,const long&l,const double&d,const string&s)')
_app=_app.replace('return false;}', 'return CDialog::OnEvent(id,l,d,s);}',1)
_app=_app.replace('static inline std::map<int,Rect> saved;', 'static inline std::map<int,Rect> saved;static inline std::map<int,bool> saved_min;\n void SubwinOff(){}')
_app=_app.replace('saved[chart_context]=m_rect;', 'saved[chart_context]=m_minimized?m_norm_rect:m_rect;saved_min[chart_context]=m_minimized;')
_app=_app.replace('if(saved.count(chart_context))m_rect=saved[chart_context];', 'if(saved.count(chart_context)){m_rect=saved[chart_context];m_norm_rect=m_rect;if(saved_min[chart_context])OnEvent(TEST_MINIMIZE,0,0,"");}')
_app=_app.replace('++native_calls;OnEvent(id,l,d,s);', '++native_calls;if(id==CHARTEVENT_CHART_CHANGE&&ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)<Height()+CONTROLS_BORDER_WIDTH){OnEvent(TEST_MINIMIZE,l,d,s);return;}OnEvent(id,l,d,s);')
AUTO_UI=AUTO_UI[:_start]+_app+AUTO_UI[_end:]
TESTS = r'''
void Check(bool ok,const char*label){if(!ok){std::cerr<<"FAIL: "<<label<<'\n';std::abort();}}
void Fixture(int count){
 double h[]={2,3,7,4,3,4,6,4,3,4,5,4,3},l[]={1,2,3,2,0,2,3,2,-1,2,3,2,1};
 ArrayResize(history,count);ArraySetAsSeries(history,false);
 for(int i=0;i<count;i++){history[i]={};history[i].time=1700000000+i*60;history[i].high=100+h[i];history[i].low=100+l[i];history[i].close=(history[i].high+history[i].low)/2;}
}
void LongFixture(int count){
 double h[]={110,113,118,114,112,111},l[]={108,110,112,109,105,107};
 ArrayResize(history,count);ArraySetAsSeries(history,false);
 for(int i=0;i<count;i++){history[i]={};history[i].time=1800000000+i*60;history[i].high=h[i%6]+.1*(i/6);history[i].low=l[i%6]+.1*(i/6);history[i].close=(history[i].high+history[i].low)/2;}
}
void Action(const string&control,int event){long id=controls["AutoFibo.Panel."+control]->Id();OnChartEvent(CHARTEVENT_CUSTOM+event,id,0,"");}
void Edit(const string&control,const string&text){controls["AutoFibo.Panel."+control]->Text(text);OnChartEvent(CHARTEVENT_OBJECT_ENDEDIT,0,0,"AutoFibo.Panel."+control);}
void Lock(bool value){static_cast<CCheckBox*>(controls["AutoFibo.Panel.Lock"])->Checked(value);Action("Lock",ON_CHANGE);}
int main(){
 Fixture(9);bid=119.9;ask=120;
 Check(OnInit()==INIT_SUCCEEDED&&copy_calls==0&&g_auto_force_pending,"auto startup defers history work");
 chart_properties[chart_context][CHART_HEIGHT_IN_PIXELS]=400;
 int forwarded=native_calls,notifications=child_layout_events;
 for(int i=0;i<3;i++)OnChartEvent(CHARTEVENT_CHART_CHANGE,0,0,"");
 Check(!g_dialog.IsMinimized()&&native_calls==forwarded&&child_layout_events==notifications+3,"small-chart auto-minimize bypass keeps child notifications");
 for(auto*c:g_dialog.children)Check(c->visible,"fresh attachment stays expanded");
 chart_properties[chart_context][CHART_HEIGHT_IN_PIXELS]=0;OnChartEvent(CHARTEVENT_CHART_CHANGE,0,0,"");
 Check(!g_dialog.IsMinimized(),"zero height during repaint does not minimize");
 chart_properties[chart_context][CHART_HEIGHT_IN_PIXELS]=900;forwarded=native_calls;
 OnChartEvent(CHARTEVENT_CHART_CHANGE,0,0,"");Check(native_calls==forwarded+1&&!g_dialog.IsMinimized(),"normal resize uses native driver");
 chart_properties[chart_context][CHART_HEIGHT_IN_PIXELS]=400;
 OnChartEvent(TEST_MINIMIZE,0,0,"");OnChartEvent(CHARTEVENT_CHART_CHANGE,0,0,"");
 Check(g_dialog.IsMinimized(),"explicit user minimization still works");
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&g_dialog.IsMinimized(),"user minimization survives timeframe handoff");
 OnChartEvent(TEST_RESTORE,0,0,"");Check(!g_dialog.IsMinimized(),"native restore remains available on small chart");
 Check(controls.count("AutoFibo.Panel.Mode")==0&&controls.count("AutoFibo.Panel.Timeframe")==0,"no Manual/Auto or timeframe selector");
 Check(controls["AutoFibo.Panel.Draw"]->text=="Cari Swing"&&g_model.RiskPercent()==5&&g_dialog.RatioMask()==28,"auto search and same manualFibo risk defaults");
 Check(controls["AutoFibo.Panel.Left"]->text=="2"&&controls["AutoFibo.Panel.Right"]->text=="2","pivot defaults visibly filled");
 Check(g_dialog.children.size()==71,"grouped UI control registration");
 for(size_t i=0;i<g_dialog.children.size();i++)for(size_t j=i+1;j<g_dialog.children.size();j++)
  Check(g_dialog.children[i]->Id()!=g_dialog.children[j]->Id(),"unique control IDs");
 auto*analysis=controls["AutoFibo.Panel.AnalysisGroup.Bottom"];
 Check(analysis->m_rect.bottom<controls["AutoFibo.Panel.SwingTitle"]->m_rect.top,"analysis group above shared swing/risk groups");
 Check(controls["AutoFibo.Panel.SL0"]->m_rect.top==controls["AutoFibo.Panel.Level0"]->m_rect.top,"offset SL aligns with ratio");
 Check(controls["AutoFibo.Panel.Lot5"]->m_rect.bottom<controls["AutoFibo.Panel.FiboGroup.Bottom"]->m_rect.top,"all six rows fit Fibonacci group");
 int calls=native_calls;for(int i=0;i<1000;i++)OnChartEvent(CHARTEVENT_MOUSE_MOVE,900,700,"0");
 Check(native_calls==calls+1000&&copy_calls==0,"one native dispatch and no history on mouse movement");
 OnTimer();Check(g_model.Ready()&&g_model.StartPrice()==100&&g_model.EndPrice()==106,"automatic confirmed Pivot pair");
 Check(g_source==ANCHOR_PIVOT&&g_model.StopPrice(2)==100&&controls["AutoFibo.Panel.Lot2"]->text!="-","source, default SL and lot populated");
 calls=copy_calls;OnTimer();Check(copy_calls==calls,"same closed bar does not refetch history");
 Edit("Risk","2");Edit("SL2","101");Check(g_model.RiskPercent()==2&&g_model.StopCustom(2),"per-level SL and equity risk edits");
 auto&node=Objects()[g_chart.Name()];node.prices[1]=106.5;OnChartEvent(CHARTEVENT_OBJECT_DRAG,0,0,g_chart.Name());
 Check(g_model.EndPrice()==106.5&&g_edited,"native object edit sync");OnTimer();Check(g_model.EndPrice()==106.5,"same pair retains edit");
 static_cast<CCheckBox*>(controls["AutoFibo.Panel.Level5"])->Checked(true);Action("Level5",ON_CHANGE);
 Check(g_model.Enabled(5)&&node.ints[{OBJPROP_LEVELS,0}]==4,"88.6 selectable");
 fail_config=true;static_cast<CCheckBox*>(controls["AutoFibo.Panel.Level0"])->Checked(true);Action("Level0",ON_CHANGE);
 Check(!g_model.Enabled(0)&&g_dialog.RatioMask()==g_model.Mask(),"failed drawing restores ratio choices");
 Lock(true);calls=copy_calls;Fixture(13);OnTimer();
 Check(copy_calls==calls&&g_model.EndPrice()==106.5,"locked anchors pause auto analysis");
 equity=20000;OnTimer();Check(controls["AutoFibo.Panel.Budget"]->text=="Budget: 400.00 USD","risk remains live when anchors locked");
 OnChartEvent(TEST_MINIMIZE,0,0,"");int profits=profit_calls;OnTimer();Check(profit_calls==profits,"minimized preview pauses calculations");
 OnChartEvent(TEST_RESTORE,0,0,"");Check(profit_calls>profits,"restore refreshes risk preview");
 g_dialog.m_rect={160,100,780,708};OnDeinit(REASON_CHARTCHANGE);_Period=PERIOD_H2;calls=copy_calls;
 Check(OnInit()==INIT_SUCCEEDED&&copy_calls==calls,"timeframe handoff also defers data access");OnTimer();
 Check(g_model.Locked()&&g_model.EndPrice()==106.5&&g_model.RiskPercent()==2&&g_model.StopPrice(2)==101&&g_model.Enabled(5),"locked anchors and all risk/ratio settings survive timeframe change");
 Check(g_dialog.m_rect.left==160&&g_dialog.m_rect.top==100,"native panel position restored");
 Lock(false);OnTimer();Check(last_copy_tf==PERIOD_H2&&g_model.EndPrice()==105,"unlock resumes current-chart analysis");
 calls=copy_calls;Action("Draw",ON_CLICK);Check(copy_calls==calls&&g_auto_force_pending,"search button queues timer analysis");OnTimer();
 Edit("SL2","bad");Check(g_model.StopPrice(2)==101,"invalid SL input preserves model");
 // Invalid settings roll back without forcing market-data work in GUI callback.
 static_cast<CSpinEdit*>(controls["AutoFibo.Panel.Left"])->Value(0);Action("Left",ON_CHANGE);
 Check(g_left_bars==2&&g_dialog.LeftBars()==2,"invalid settings restored");
 static_cast<CSpinEdit*>(controls["AutoFibo.Panel.Left"])->Value(1);
 static_cast<CSpinEdit*>(controls["AutoFibo.Panel.Right"])->Value(1);
 static_cast<CComboBox*>(controls["AutoFibo.Panel.Method"])->SelectByValue(FIBO_MARKET_STRUCTURE);
 calls=copy_calls;Action("Method",ON_CHANGE);Check(copy_calls==calls&&g_auto_force_pending,"method change defers CopyRates");
 BreakFixture(history,10);bid=19.9;ask=20;OnTimer();
 Check(g_auto_method==FIBO_MARKET_STRUCTURE&&g_model.StartPrice()==11&&g_model.EndPrice()==17,"Market Structure BOS impulse");
 ObjectDelete(0,g_chart.Name());OnChartEvent(CHARTEVENT_OBJECT_DELETE,0,0,g_chart.Name());
 Check(!g_model.Ready(),"native deletion clears prices and lots");
 Action("Draw",ON_CLICK);OnTimer();Check(g_model.Ready(),"explicit search redraws after deletion");
 ObjectDelete(0,"AutoFibo.Structure.0");fail_structure=true;clock_value+=6000;g_labels_pending=true;g_labels_retry_after=0;calls=copy_calls;OnTimer();
 Check(g_labels_pending&&g_model.Ready()&&copy_calls==calls,"label failure does not block model or refetch history");
 clock_value+=6000;OnTimer();Check(!g_labels_pending&&copy_calls==calls&&Objects()["AutoFibo.Structure.0"].ints[{OBJPROP_BACK,0}]==1,"labels retry independently and restore all properties");
 Action("Reset",ON_CLICK);Check(!g_model.Ready()&&g_model.RiskPercent()==2&&!g_model.StopCustom(2),"reset clears SL overrides and drawing but retains risk");
 calls=copy_calls;OnTimer();Check(!g_model.Ready()&&copy_calls==calls,"reset does not redraw same bar");
 OnDeinit(REASON_REMOVE);Check(Objects().empty()&&!timer,"owned objects and timer cleaned up");
 LongFixture(500);Check(OnInit()==INIT_SUCCEEDED,"full-window retry init");
 double good=history[100].high;history[100].high=std::numeric_limits<double>::quiet_NaN();
 OnTimer();Check(g_analysis_transient&&g_last_auto_bar==0&&g_auto_retry_after>0,"invalid full history is retried rather than cached");
 history[100].high=good;clock_value+=6000;fail_config=true;OnTimer();
 Check(!g_model.Ready()&&g_last_auto_bar==0&&g_auto_retry_after>0,"failed Fibo draw does not commit model or bar cache");
 clock_value+=6000;OnTimer();Check(g_model.Ready()&&!g_analysis_transient&&g_last_auto_bar==history.data.back().time,"corrected history/drawing retry recovers on same closed bar");
 OnDeinit(REASON_REMOVE);
 std::cout<<"PASS: AutoFibo auto-only grouped GUI, Pivot/BOS, shared risk/SL/ratios, lock, retries, native edits and timeframe state.\n";
}
'''

SOURCES = ['Include/_common/Fibo/Fibonacci.mqh','Include/_common/Fibo/FiboModel.mqh','Include/_common/Fibo/FiboRisk.mqh',
 'Include/_common/Fibo/FiboDialog.mqh','Include/_common/Fibo/FiboChart.mqh','Include/_common/Fibo/FiboState.mqh',
 'Include/_common/Swing/SwingTypes.mqh','Include/_common/Swing/SwingDetector.mqh','Include/_common/Structure/MarketStructure.mqh',
 'Experts/AutoFibo/AutoFiboTypes.mqh','Experts/AutoFibo/AutoFiboAnalysis.mqh',
 'Experts/AutoFibo/AutoFiboDialog.mqh','Experts/AutoFibo/AutoFiboChart.mqh','Experts/AutoFibo/AutoFiboState.mqh']

def compile_run(code, prefix):
    compiler=shutil.which('clang++') or shutil.which('g++')
    if not compiler: raise SystemExit('C++17 compiler required.')
    with tempfile.TemporaryDirectory(prefix=prefix) as folder:
        cpp=Path(folder)/'checks.cpp';binary=Path(folder)/'checks';cpp.write_text(code)
        subprocess.run([compiler,'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',
                        '-fno-sanitize-recover=all',str(cpp),'-o',str(binary)],check=True)
        subprocess.run([str(binary)],check=True)

def shared_code():
    platform=PLATFORM.replace('void ChartRedraw(int=0){}','int redraw_count=0;void ChartRedraw(int=0){++redraw_count;}')
    return SHIM+platform+EXTRA+LAYOUT_EXTRA+AUTO_UI+'\n'.join(adapt((ROOT/name).read_text().replace('CPanel &edges[]','CPanel (&edges)[5]')) for name in SOURCES)

def main():
    source=adapt((ROOT/'Experts/AutoFibo/AutoFibo.mq5').read_text())
    signatures=re.findall(r'^(?:bool|void|int|string)\s+\w+\([^{};]*\)\s*\{',source,re.M)
    prototypes='\n'.join(sig[:-1].strip()+';' for sig in signatures)
    fixtures=(ROOT/'tests/fixtures/market_structure_checks.mqh').read_text()
    fixture=adapt(fixtures[fixtures.index('void BreakFixture('):fixtures.index('void RunBreakChecks(')])
    assert 'FIBO_MANUAL' not in source and 'CHARTEVENT_CLICK' not in source
    assert source.count('g_dialog.DispatchEvent(id, lparam, dparam, sparam);')==1
    compile_run(shared_code()+prototypes+source+fixture+TESTS,'autofibo-checks-')
    print('C++ adapters only; F7, native GUI and broker validation remain Windows checks.')

if __name__=='__main__': main()
