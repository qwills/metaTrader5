"""Shared fake MT5/Standard Library APIs for C++ adapter checks only."""

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
 if(fail_structure&&name.find(".Structure.")!=string::npos){fail_structure=false;return false;}
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
 bool AddItem(const string&,long value){value=value?value:static_cast<long>(items.size());items.push_back(value);if(selected==-1)selected=value;return true;}
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

