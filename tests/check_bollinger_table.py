#!/usr/bin/env python3
"""Exercise production BB signals and live table updates with fake MT5 APIs."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

TABLE_ADAPTER = r"""
#include <string>
#include <cstdio>
#include <cmath>
#include <map>
using string = std::string;
using color = int;
using datetime = long;
const color clrSilver=0, clrLimeGreen=1, clrRed=2, clrDodgerBlue=3, clrOrange=4;
const int SERIES_LASTBAR_DATE=1, SERIES_SYNCHRONIZED=2;
const int OBJPROP_TEXT=1, OBJPROP_COLOR=2;
const int REASON_CHARTCHANGE=3, INVALID_HANDLE=-1;
const double EMPTY_VALUE=1e308;
int InpPeriod=20, _Digits=5;
string _Symbol="EURUSD";
double InpDeviation=2;
int InpAppliedPrice=0, InpTableX=12, InpTableY=28, InpFontSize=10;
int InpUpperColor=2, InpMiddleColor=3, InpLowerColor=1;
int ChartHandle=100;
int Timeframes[9]={}, TableHandles[9]={};
bool TimeframeEnabled[9];
int SelectedCount=0;
string Prefix="test_", DisplayedText[9];
string TableKey="";
color DisplayedColor[9];
struct MqlRates { datetime time; double close; };
double previous_close=99, current_close=102, previous_middle=100, current_middle=101;
datetime current_time=200;
bool ready=true, synchronized=true, rollover=false, reject_commands=false;
int text_commands=0, color_commands=0, redraws=0, rates_calls=0, buffer_calls=0;
string IntegerToString(int value) { return std::to_string(value); }
string DoubleToString(double value, int digits)
{
    char text[64]; std::snprintf(text, sizeof(text), "%.*f", digits, value); return text;
}
bool MathIsValidNumber(double value) { return std::isfinite(value); }
long SeriesInfoInteger(const string &, int, int property)
{ return property == SERIES_LASTBAR_DATE ? current_time : synchronized; }
int BarsCalculated(int) { return ready ? 100 : 0; }
int CopyRates(const string &, int, int shift, int count, MqlRates (&rates)[2])
{
    assert(shift == 0 && count == 2); ++rates_calls;
    rates[0] = {current_time-100, previous_close};
    rates[1] = {current_time, current_close}; return 2;
}
int CopyBuffer(int, int index, int shift, int count, double (&middle)[2])
{
    assert(index == 0 && shift == 0 && count == 2); ++buffer_calls;
    middle[0]=previous_middle; middle[1]=current_middle;
    if(rollover) ++current_time;
    return 2;
}
struct FakeObject { std::map<int,string> text; color tint=0; };
std::map<string,FakeObject> objects;
bool ObjectSetString(int, const string &name, int property, const string &value)
{
    ++text_commands;
    if(reject_commands) return false;
    objects[name].text[property]=value; return true;
}
bool ObjectSetInteger(int, const string &, int, color)
{ ++color_commands; return !reject_commands; }
void ChartRedraw(int) { ++redraws; }
int StringLen(const string &text) { return static_cast<int>(text.size()); }
int StringFind(const string &text, const string &part)
{ auto pos=text.find(part); return pos==string::npos ? -1 : static_cast<int>(pos); }
string StringSubstr(const string &text, int start, int length=-1)
{ return text.substr(start, length<0 ? string::npos : static_cast<size_t>(length)); }
int ObjectsTotal(int,int,int) { return static_cast<int>(objects.size()); }
string ObjectName(int,int index,int,int)
{ auto it=objects.begin(); std::advance(it,index); return it->first; }
int ObjectFind(int,const string &name) { return objects.count(name) ? 0 : -1; }
string ObjectGetString(int,const string &name,int prop) { return objects[name].text[prop]; }
long ObjectGetInteger(int,const string &name,int) { return objects[name].tint; }
void ObjectsDeleteAll(int,const string &prefix)
{
    for(auto it=objects.begin(); it!=objects.end();)
        if(it->first.find(prefix)==0) it=objects.erase(it); else ++it;
}
int released=0;
void IndicatorRelease(int) { ++released; }
void EventKillTimer() {}
"""

RELOAD_CHECKS = r"""
void SeedTable(const string &prefix, const string &symbol)
{
    objects[prefix+"State"].text[OBJPROP_TEXT]="pending|"+TableKey+symbol;
    objects[prefix+"Background"]={};
    objects[prefix+"Title"]={}; objects[prefix+"TF"]={}; objects[prefix+"Middle"]={};
    for(int i=0;i<9;++i)
        if(TimeframeEnabled[i])
        {
            objects[prefix+"TF"+IntegerToString(i)]={};
            auto &obj=objects[prefix+"Value"+IntegerToString(i)];
            obj.text[OBJPROP_TEXT]="101.00000"; obj.tint=clrDodgerBlue;
        }
}
void RunReloadChecks()
{
    objects.clear();
    InpShowM15=true; InpShowM30=true; InpShowH1=true; InpShowH4=true;
    ConfigureTimeframes(); TableKey=TableSettingsKey();
    SeedTable("BBT_first_", _Symbol); SeedTable("BBT_second_", _Symbol);
    // Restore without invoking rates or indicator copies, keeping exact display.
    int before_rates=rates_calls, before_buffers=buffer_calls;
    assert(RestoreTable());
    string first=Prefix;
    assert(DisplayedText[2]=="101.00000" && DisplayedColor[2]==clrDodgerBlue);
    assert(RestoreTable() && Prefix!=first); // each pending instance claimed once
    assert(!RestoreTable());
    assert(rates_calls==before_rates && buffer_calls==before_buffers);
    Prefix=first;
    OnDeinit(REASON_CHARTCHANGE);
    assert(ObjectFind(0,first+"Background")>=0);
    assert(RestoreTable() && Prefix==first);
    OnDeinit(1); // remove only this instance
    assert(ObjectFind(0,first+"Background")==-1 && !objects.empty());
    objects.clear(); SeedTable("BBT_oldsymbol_", "GBPUSD");
    assert(!RestoreTable() && objects.empty());
    SeedTable("BBT_incomplete_", _Symbol);
    objects.erase("BBT_incomplete_Value2");
    assert(!RestoreTable() && objects.empty());
    SeedTable("BBT_other_", _Symbol);
    InpPeriod=21; TableKey=TableSettingsKey();
    assert(!RestoreTable() && !objects.empty()); // mismatched config untouched
    InpPeriod=20;
}
"""

TABLE_CHECKS = r"""
void RunTableChecks()
{
    ConfigureTimeframes();
    assert(SelectedCount == 4);
    for(int i=0; i<9; ++i)
        assert(TimeframeEnabled[i] == (i>=2 && i<=5));
    // Exercise the full table first, then restrict it to the default selection.
    for(int i=0; i<9; ++i) TimeframeEnabled[i]=true;
    RefreshTable();
    assert(rates_calls == 9 && buffer_calls == 9);
    assert(text_commands == 9 && color_commands == 9 && redraws == 1);
    assert(DisplayedText[0] == "101.00000" && DisplayedColor[0] == clrDodgerBlue);
    RefreshTable();
    // Repeated snapshots must not enqueue object updates or force redraws.
    assert(text_commands == 9 && color_commands == 9 && redraws == 1);
    // Same current candle: price retreats below middle; color follows immediately.
    current_close=100;
    RefreshTable();
    assert(DisplayedColor[0] == clrRed && color_commands == 18 && redraws == 2);
    previous_close=102;
    RefreshTable();
    assert(DisplayedColor[0] == clrOrange);
    current_close=103;
    RefreshTable();
    assert(DisplayedColor[0] == clrLimeGreen);
    current_middle=101.5;
    RefreshTable();
    assert(DisplayedText[0] == "101.50000");
    rollover=true;
    RefreshTable();
    assert(DisplayedText[0] == "Loading..." && DisplayedColor[0] == clrSilver);
    rollover=false;
    RefreshTable();
    assert(DisplayedText[0] == "101.50000");
    ready=false;
    RefreshTable();
    assert(DisplayedText[0] == "Loading...");
    int before=redraws;
    RefreshTable();
    assert(redraws == before);
    ready=true; synchronized=false;
    RefreshTable();
    assert(DisplayedText[0] == "Loading...");
    synchronized=true; current_middle=EMPTY_VALUE;
    RefreshTable();
    assert(DisplayedText[0] == "Loading...");
    current_middle=101;
    reject_commands=true;
    RefreshTable();
    assert(DisplayedText[0] == "Loading...");
    reject_commands=false;
    RefreshTable();
    assert(DisplayedText[0] == "101.00000");
    ConfigureTimeframes();
    DisplayedText[0]="disabled";
    int before_rates=rates_calls, before_buffers=buffer_calls;
    RefreshTable();
    assert(rates_calls-before_rates == 4 && buffer_calls-before_buffers == 4);
    assert(DisplayedText[0] == "disabled");
    // Non-contiguous custom selection must skip all other rows and reads.
    InpShowM1=true; InpShowM15=false; InpShowM30=false;
    InpShowH1=false; InpShowH4=false; InpShowMN1=true;
    ConfigureTimeframes();
    assert(SelectedCount == 2 && TimeframeEnabled[0] && TimeframeEnabled[8]);
    before_rates=rates_calls; before_buffers=buffer_calls;
    RefreshTable();
    assert(rates_calls-before_rates == 2 && buffer_calls-before_buffers == 2);
    InpShowM1=false; InpShowMN1=false;
    ConfigureTimeframes();
    assert(SelectedCount == 0);
    before_rates=rates_calls; before_buffers=buffer_calls; before=redraws;
    RefreshTable();
    assert(rates_calls == before_rates && buffer_calls == before_buffers && redraws == before);
}
"""


def main():
    compiler = shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("C++17 compiler required.")
    header = ROOT / "Indicators/BollingerTable/BollingerSignal.mqh"
    code = '#include <cassert>\n#include "' + str(header) + '"\n' + r"""
int main()
{
    assert(BollingerSignal(102, 100, 103, 101) == BB_ABOVE);
    assert(BollingerSignal(98, 100, 99, 101) == BB_BELOW);
    assert(BollingerSignal(99, 100, 102, 101) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(101, 100, 100, 101) == BB_DEAD_CROSS);
    // Touching the middle precedes a cross; landing on it remains neutral.
    assert(BollingerSignal(100, 100, 102, 101) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(100, 100, 100, 101) == BB_DEAD_CROSS);
    assert(BollingerSignal(99, 100, 101, 101) == BB_EQUAL);
    assert(BollingerSignal(102, 100, 101, 101) == BB_EQUAL);
    assert(BollingerSignal(100, 100, 101, 101) == BB_EQUAL);
    // Compare each close with its own middle, even when only the middle moves.
    assert(BollingerSignal(100, 101, 100, 99) == BB_GOLDEN_CROSS);
    assert(BollingerSignal(100, 99, 100, 101) == BB_DEAD_CROSS);
    // A cross expires on the next bar if price stays on that side.
    assert(BollingerSignal(102, 101, 103, 102) == BB_ABOVE);
    assert(BollingerSignal(100, 101, 99, 100) == BB_BELOW);
    // Small prices must not be rounded before signal classification.
    assert(BollingerSignal(0.99999, 1, 1.00001, 1) == BB_GOLDEN_CROSS);
}
"""
    source = (ROOT / "Indicators/BollingerTable/BollingerTable.mq5").read_text()
    restore = source.split("string TableSettingsKey()", 1)[1].split("void ConfigureTimeframes()", 1)[0]
    deinit = source.split("void OnDeinit(", 1)[1]
    selection_inputs = "\n".join(re.findall(r"input (bool\s+InpShow\w+\s*=\s*(?:true|false);)", source))
    configure = source.split("void ConfigureTimeframes()", 1)[1].split("color SignalColor(", 1)[0]
    signal_color = source.split("color SignalColor(", 1)[1].split("bool CreateLabel(", 1)[0]
    table = source.split("bool ValidBandValue(", 1)[1].split("int OnInit()", 1)[0]
    adapter = (TABLE_ADAPTER + selection_inputs + "\nvoid ConfigureTimeframes()" + configure +
               "\ncolor SignalColor(" + signal_color +
               "\nbool ValidBandValue(" + table + TABLE_CHECKS +
               "\nstring TableSettingsKey()" + restore + "\nvoid OnDeinit(" + deinit + RELOAD_CHECKS)
    code = code.replace("int main()", adapter + "\nint main()")
    code = code.replace("int main()\n{", "int main()\n{\n    RunTableChecks();\n    RunReloadChecks();")
    with tempfile.TemporaryDirectory(prefix="bollinger-checks-") as folder:
        cpp = Path(folder) / "checks.cpp"
        binary = Path(folder) / "checks"
        cpp.write_text(code)
        subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                        "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
                        str(cpp), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
    print("14 BB signal checks and timeframe-selection/live-table/cache/reload/recovery checks passed; "
          "Windows F7 and GUI validation remain required.")


if __name__ == "__main__":
    main()
