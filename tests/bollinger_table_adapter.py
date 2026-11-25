"""Fake terminal for the complete BollingerTable source, including queued objects."""
SHIM = r'''
#include <cassert>
#include <cmath>
#include <cstdio>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>
#include <limits>
#include <algorithm>
using string=std::string;
using datetime=long long;
using color=int;
using ushort=unsigned short;
using ENUM_APPLIED_PRICE=int;
using ENUM_OBJECT_PROPERTY_STRING=int;
using ENUM_OBJECT_PROPERTY_INTEGER=int;
using ENUM_OBJECT=int;
using ENUM_TIMEFRAMES=int;
enum {
 PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED,
 PERIOD_M1=101, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1,
 OBJ_LABEL=201, OBJ_RECTANGLE_LABEL,
 OBJPROP_TYPE=301, OBJPROP_TEXT, OBJPROP_COLOR, OBJPROP_TOOLTIP, OBJPROP_FONT,
 OBJPROP_CORNER, OBJPROP_ANCHOR, OBJPROP_XDISTANCE, OBJPROP_YDISTANCE, OBJPROP_FONTSIZE,
 OBJPROP_SELECTABLE, OBJPROP_HIDDEN, OBJPROP_TIMEFRAMES, OBJPROP_XSIZE, OBJPROP_YSIZE,
 OBJPROP_BGCOLOR, OBJPROP_BORDER_TYPE,
 SERIES_LASTBAR_DATE=401, SERIES_SYNCHRONIZED,
 CORNER_LEFT_UPPER=0, ANCHOR_LEFT_UPPER=0, BORDER_FLAT=0, OBJ_NO_PERIODS=0, OBJ_ALL_PERIODS=0x1FFFFF,
 PLOT_DRAW_BEGIN=501, PLOT_LINE_COLOR, INDICATOR_DIGITS, INDICATOR_SHORTNAME, INDICATOR_DATA,
 TERMINAL_CONNECTED=601, TIME_DATE=1, TIME_SECONDS=2,
 INIT_SUCCEEDED=0, INIT_FAILED=-1, INIT_PARAMETERS_INCORRECT=-2,
 INVALID_HANDLE=-1, REASON_REMOVE=1, REASON_CHARTCHANGE=3, REASON_INITFAILED=8,
 clrLimeGreen=0x32CD32, clrRed=0x0000FF, clrDodgerBlue=0xFF901E, clrOrange=0x00A5FF,
 clrSilver=0xC0C0C0, clrWhite=0xFFFFFF, clrGreen=0x008000, clrDimGray=0x696969
};
const double EMPTY_VALUE=std::numeric_limits<double>::max();
string _Symbol="EURUSD";
int _Period=PERIOD_M15, _Digits=5;
struct MqlRates {
 datetime time=0; double open=0, high=0, low=0, close=0;
 long tick_volume=0; int spread=0; long real_volume=0;
};
template<class T> struct MqlArray {
 std::vector<T> data;
 T &operator[](int i) { return data.at(i); }
 const T &operator[](int i) const { return data.at(i); }
};
template<class T> bool ArraySetAsSeries(MqlArray<T> &,bool value) { assert(!value); return true; }
template<class T,class U> void ArrayInitialize(MqlArray<T> &array,U value) {
 std::fill(array.data.begin(),array.data.end(),static_cast<T>(value));
}
template<class T,size_t N,class U> void ArrayInitialize(T (&array)[N],U value) {
 std::fill(std::begin(array),std::end(array),static_cast<T>(value));
}
template<class T,class U> void ArrayFill(MqlArray<T> &array,int start,int count,U value) {
 assert(start>=0 && start+count<=static_cast<int>(array.data.size()));
 std::fill(array.data.begin()+start,array.data.begin()+start+count,value);
}
int MathMin(int a,int b) { return std::min(a,b); }
bool MathIsValidNumber(double value) { return std::isfinite(value); }
int StringLen(const string &value) { return static_cast<int>(value.size()); }
int StringFind(const string &value,const string &part) {
 auto n=value.find(part); return n==string::npos ? -1 : static_cast<int>(n);
}
string StringSubstr(const string &value,int start,int length=-1) {
 return value.substr(start,length<0 ? string::npos : static_cast<size_t>(length));
}
ushort StringGetCharacter(const string &value,int index) { return value.at(index); }
string IntegerToString(long long value) { return std::to_string(value); }
string EnumToString(int value) { return std::to_string(value); }
string DoubleToString(double value,int digits) {
 char buffer[400]; std::snprintf(buffer,sizeof(buffer),"%.*f",digits,value); return buffer;
}
double StringToDouble(const string &value) { return std::strtod(value.c_str(),nullptr); }
long long StringToInteger(const string &value) { return std::strtoll(value.c_str(),nullptr,10); }
int StringSplit(const string &value,ushort delimiter,MqlArray<string> &out) {
 out.data.clear(); size_t start=0;
 while(true) { auto end=value.find(static_cast<char>(delimiter),start);
  out.data.push_back(value.substr(start,end==string::npos ? end : end-start));
  if(end==string::npos) break; start=end+1;
 }
 return static_cast<int>(out.data.size());
}
datetime wall_time=1700000000;
datetime TimeLocal() { return wall_time; }
string TimeToString(datetime value,int) { return IntegerToString(value); }
long ChartID() { return 123; }
long sequence=0;
long GetMicrosecondCount() { return ++sequence; }

struct FakeObject { std::map<int,string> text; std::map<int,long> number; };
std::map<string,FakeObject> objects;
std::vector<std::function<void()>> commands;
int redraws=0, object_writes=0, dropped_writes=0, object_reads=0, log_messages=0;
int GetLastError() { return 0; }
template<class... Args> void PrintFormat(const string &,Args...) { ++log_messages; }
bool reject_commands=false, drop_next_write=false, drop_all_writes=false, fail_create=false;
void Flush() { auto pending=std::move(commands); commands.clear(); for(auto &call:pending) call(); }
void ChartRedraw(int) { Flush(); ++redraws; }
int ObjectFind(int,const string &name) { ++object_reads; Flush(); return objects.count(name) ? 0 : -1; }
long ObjectGetInteger(int,const string &name,int property) {
 ++object_reads; Flush(); auto it=objects.find(name); return it==objects.end() ? 0 : it->second.number[property];
}
string ObjectGetString(int,const string &name,int property) {
 ++object_reads; Flush(); auto it=objects.find(name); return it==objects.end() ? "" : it->second.text[property];
}
bool ObjectCreate(int,const string &name,int type,int,datetime,double) {
 if(fail_create) return false;
 commands.push_back([name,type] {
  if(!objects.count(name)) {
   objects[name].number[OBJPROP_TYPE]=type;
   objects[name].number[OBJPROP_TIMEFRAMES]=0x1FFFFF;
  }
 });
 return true;
}
bool DropWrite() {
 if(!drop_next_write && !drop_all_writes) return false;
 drop_next_write=false; ++dropped_writes; return true;
}
bool ObjectSetString(int,const string &name,int property,const string &value) {
 if(reject_commands) return false;
 ++object_writes; bool drop=DropWrite();
 commands.push_back([name,property,value,drop] {
  if(!drop && objects.count(name)) objects[name].text[property]=value;
 }); return true;
}
bool ObjectSetInteger(int,const string &name,int property,long value) {
 if(reject_commands) return false;
 ++object_writes; bool drop=DropWrite();
 commands.push_back([name,property,value,drop] {
  if(!drop && objects.count(name)) objects[name].number[property]=value;
 }); return true;
}
bool ObjectDelete(int,const string &name) {
 commands.push_back([name] { objects.erase(name); }); return true;
}
int ObjectsTotal(int,int,int type) {
 ++object_reads; Flush(); int count=0;
 for(const auto &entry:objects)
  if(type<0 || entry.second.number.at(OBJPROP_TYPE)==type) ++count;
 return count;
}
string ObjectName(int,int index,int,int type) {
 ++object_reads; Flush();
 for(const auto &entry:objects) {
  if(type>=0 && entry.second.number.at(OBJPROP_TYPE)!=type) continue;
  if(index--==0) return entry.first;
 } return "";
}
int ObjectsDeleteAll(int,const string &prefix) {
 Flush(); int count=0;
 for(auto it=objects.begin();it!=objects.end();)
  if(it->first.find(prefix)==0) { it=objects.erase(it); ++count; } else ++it;
 return count;
}

bool connected=true, rates_ready=true, synchronized=true, rollover=false;
int rates_calls=0, last_rates_count=0, partial_rates=-1;
std::map<int,std::vector<MqlRates>> histories;
long TerminalInfoInteger(int) { return connected; }
long SeriesInfoInteger(const string &,int tf,int prop) {
 if(prop==SERIES_SYNCHRONIZED) return synchronized;
 return histories[tf].empty() ? 0 : histories[tf].back().time+(rollover ? 60 : 0);
}
int CopyRates(const string &,int tf,int shift,int count,MqlArray<MqlRates> &out) {
 assert(shift==0); ++rates_calls; last_rates_count=count;
 auto &history=histories[tf];
 if(!rates_ready || count>static_cast<int>(history.size())) return -1;
 out.data.assign(history.end()-count,history.end());
 return partial_rates>=0 ? partial_rates : count;
}
std::set<int> live_handles;
int next_handle=10, bands_calls=0, released=0;
bool fail_bands=false, fail_timer=false, timer_running=false, fail_plot=false;
int fail_buffer_bind=-1, calculated=-1, failed_copy_index=-1;
std::vector<double> chart_values[3];
std::vector<int> copy_counts;
MqlArray<double> *bound_buffers[3]={};
int iBands(const string &,int,int,int,double,int) {
 ++bands_calls; if(fail_bands) return INVALID_HANDLE;
 int handle=++next_handle; live_handles.insert(handle); return handle;
}
void IndicatorRelease(int handle) { assert(live_handles.erase(handle)==1); ++released; }
int BarsCalculated(int handle) {
 assert(live_handles.count(handle));
 return calculated<0 ? static_cast<int>(chart_values[0].size()) : calculated;
}
int CopyBuffer(int handle,int index,int shift,int count,MqlArray<double> &out) {
 assert(live_handles.count(handle) && shift==0); copy_counts.push_back(count);
 if(index==failed_copy_index) return -1;
 auto &values=chart_values[index];
 if(count>static_cast<int>(values.size())) return -1;
 out.data.assign(values.end()-count,values.end()); return count;
}
bool SetIndexBuffer(int index,MqlArray<double> &buffer,int) {
 if(index==fail_buffer_bind) return false;
 bound_buffers[index]=&buffer; return true;
}
std::map<std::pair<int,int>,long> plots;
bool PlotIndexSetInteger(int index,int property,long value) {
 if(fail_plot) return false; plots[{index,property}]=value; return true;
}
bool IndicatorSetInteger(int,long) { return true; }
bool IndicatorSetString(int,const string &) { return true; }
bool EventSetTimer(int seconds) { assert(seconds==1); if(fail_timer) return false; timer_running=true; return true; }
void EventKillTimer() { timer_running=false; }
'''
