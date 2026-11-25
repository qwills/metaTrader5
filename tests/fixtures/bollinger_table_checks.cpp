// Development-only fixture. The entire production indicator is compiled above this file.
void Reset()
{
    Flush(); objects.clear(); commands.clear(); live_handles.clear(); temporary_globals.clear(); reject_claims=false;
    reject_commands=false; drop_next_write=false; drop_all_writes=false; fail_create=false;
    fail_bands=false; fail_timer=false; fail_plot=false; fail_buffer_bind=-1;
    calculated=-1; failed_copy_index=-1; connected=true; rates_ready=true;
    synchronized=true; rollover=false; partial_rates=-1; timer_running=false;
    rates_calls=0; bands_calls=0; released=0; redraws=0; object_writes=0; dropped_writes=0;
    object_reads=0; log_messages=0; delete_all_calls=0; delete_calls=0;
    copy_counts.clear(); plots.clear(); histories.clear();
    wall_time=1700000000; _Symbol="EURUSD"; _Period=PERIOD_M15;
    InpPeriod=20; InpDeviation=2; InpAppliedPrice=PRICE_CLOSE;
    InpUpperColor=clrRed; InpMiddleColor=clrDodgerBlue; InpLowerColor=clrGreen;
    InpTableX=20; InpTableY=125; InpFontSize=10;
    InpShowM1=false; InpShowM5=false; InpShowM15=true; InpShowM30=true;
    InpShowH1=true; InpShowH4=true; InpShowD1=false; InpShowW1=false; InpShowMN1=false;
    for(int tf:Timeframes)
    {
        for(int i=0;i<40;++i)
        {
            MqlRates bar; bar.time=1000+i*100; bar.open=100; bar.high=103; bar.low=97;
            bar.close=i==39 ? 102 : 100; histories[tf].push_back(bar);
        }
    }
    for(int index=0;index<3;++index)
    {
        chart_values[index].clear();
        for(int i=0;i<40;++i) chart_values[index].push_back(100+index*10+i);
    }
}
void Tick(int seconds=0)
{
    wall_time+=seconds;
    OnTimer();
    Flush(); // the terminal processes queued chart commands between events
}
void Stop(int reason)
{
    OnDeinit(reason);
    Flush();
}
int Start()
{
    int result=OnInit();
    if(result==INIT_SUCCEEDED) { Tick(); Flush(); }
    return result;
}
string ValueName(int i=2) { return Prefix+"Value"+IntegerToString(i); }
string Display(int i=2) { return ObjectGetString(0,ValueName(i),OBJPROP_TEXT); }
long Tint(int i=2) { return ObjectGetInteger(0,ValueName(i),OBJPROP_COLOR); }
void ResizePlots(int size) { for(auto *buffer:bound_buffers) buffer->data.resize(size,0); }
int Calculate(int size,int previous)
{
    ResizePlots(size);
    MqlArray<datetime> times; MqlArray<double> values; MqlArray<long> volumes; MqlArray<int> spreads;
    return OnCalculate(size,previous,times,values,values,values,values,volumes,volumes,spreads);
}
void CheckSignals()
{
    assert(BollingerSignal(102,100,103,101)==BB_ABOVE);
    assert(BollingerSignal(98,100,99,101)==BB_BELOW);
    assert(BollingerSignal(99,100,102,101)==BB_GOLDEN_CROSS);
    assert(BollingerSignal(101,100,100,101)==BB_DEAD_CROSS);
    assert(BollingerSignal(100,100,102,101)==BB_GOLDEN_CROSS);
    assert(BollingerSignal(100,100,100,101)==BB_DEAD_CROSS);
    assert(BollingerSignal(99,100,101,101)==BB_EQUAL);
    assert(BollingerSignal(102,100,101,101)==BB_EQUAL);
    assert(BollingerSignal(100,100,101,101)==BB_EQUAL);
    assert(BollingerSignal(100,101,100,99)==BB_GOLDEN_CROSS);
    assert(BollingerSignal(100,99,100,101)==BB_DEAD_CROSS);
    assert(BollingerSignal(102,101,103,102)==BB_ABOVE);
    assert(BollingerSignal(100,101,99,100)==BB_BELOW);
    assert(BollingerSignal(.99999,1,1.00001,1)==BB_GOLDEN_CROSS);
}
void CheckLiveTable()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    assert(SelectedCount==4 && bands_calls==1 && live_handles.size()==1 && timer_running);
    assert(rates_calls==4 && last_rates_count==21);
    assert(ObjectGetString(0,Prefix+"Title",OBJPROP_TEXT)=="BB");
    assert(ObjectGetInteger(0,Prefix+"Background",OBJPROP_YSIZE)==156);
    assert(ObjectFind(0,Prefix+"Value0")==-1 && ObjectFind(0,Prefix+"Value8")==-1);
    assert(ObjectGetInteger(0,Prefix+"Cache2",OBJPROP_TIMEFRAMES)==OBJ_NO_PERIODS);
    assert(Display()=="100.10000" && Tint()==clrDodgerBlue);
    assert(plots[std::make_pair(0,PLOT_LINE_COLOR)]==clrDodgerBlue);
    assert(plots[std::make_pair(1,PLOT_LINE_COLOR)]==clrRed);
    assert(plots[std::make_pair(2,PLOT_LINE_COLOR)]==clrGreen);
    int before=redraws, writes=object_writes;
    Tick(); assert(redraws==before && object_writes==writes);
    int reads_before=object_reads;
    Tick(); assert(object_reads==reads_before); // no graphical reads on ordinary refresh
    wall_time++;
    Tick(); assert(redraws==before); // timestamps/tooltips do not force redraw
    histories[PERIOD_M15].back().close=99;
    Tick(); assert(Display()=="99.95000" && Tint()==clrOrange);
    histories[PERIOD_M15].back().close=100;
    Tick(); assert(Display()=="100.00000" && Tint()==clrSilver);
    // Validate snapshot rejection for rollover, partial data, NaN and disconnected terminal.
    string cached=LastValidText[2]; datetime updated=LastValidTime[2];
    rollover=true; Tick(); assert(!RowFresh[2] && LastValidTime[2]==updated);
    rollover=false; partial_rates=20; Tick(); assert(!RowFresh[2]);
    partial_rates=-1; synchronized=false; Tick(); assert(!RowFresh[2]);
    synchronized=true; histories[PERIOD_M15].back().close=std::nan("");
    Tick(); assert(!RowFresh[2] && LastValidText[2]==cached);
    histories[PERIOD_M15].back().close=101; connected=false;
    wall_time+=4; Tick(); assert(Display()==cached+" *");
    assert(ObjectGetString(0,ValueName(),OBJPROP_TOOLTIP).find(IntegerToString(updated))!=string::npos);
    before=redraws; Tick(); assert(redraws==before);
    connected=true; Tick(); assert(Display()=="100.05000" && RowFresh[2]);
    // Missing value, background, metadata, header, or wrong type repairs without losing cache.
    for(const string suffix:{"Value2","Background","Cache2","State","TF"})
    {
        ObjectDelete(0,Prefix+suffix); Flush(); Tick(5);
        assert(TableObjectsReady() && Display()=="100.05000");
    }
    objects[ValueName()].number[OBJPROP_TYPE]=OBJ_RECTANGLE_LABEL;
    Tick(5); assert(ObjectGetInteger(0,ValueName(),OBJPROP_TYPE)==OBJ_LABEL);
    objects[Prefix+"Cache2"].number[OBJPROP_TIMEFRAMES]=0x1FFFFF;
    Tick(5); assert(ObjectGetInteger(0,Prefix+"Cache2",OBJPROP_TIMEFRAMES)==OBJ_NO_PERIODS);
    Stop(REASON_REMOVE); assert(objects.empty() && live_handles.empty() && !timer_running);
}
void CheckPrices()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    for(auto &entry:histories) for(auto &bar:entry.second)
    { bar.open=10; bar.high=16; bar.low=8; bar.close=14; }
    const double expected[]={14,10,16,8,12,38.0/3,13};
    for(int mode=PRICE_CLOSE;mode<=PRICE_WEIGHTED;++mode)
    {
        InpAppliedPrice=mode; Tick();
        assert(std::abs(StringToDouble(LastValidText[2])-expected[mode])<0.000006);
    }
    InpAppliedPrice=PRICE_CLOSE;
    for(double price:{0.1,1.0,14.0,100.0})
    {
        for(auto &entry:histories) for(auto &bar:entry.second) bar.close=price;
        Tick(); assert(Tint()==clrSilver); // no false cross for a flat series
    }
    Stop(REASON_REMOVE);
}
void CheckQueuedCommands()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    string name=ValueName(), old=Display();
    histories[PERIOD_M15].back().close=106;
    drop_next_write=true; Tick();
    // Accepted-but-dropped writes are detected from actual properties on the next timer.
    assert(dropped_writes==1 && Display()==old && LastValidText[2]=="100.30000");
    Tick(5); assert(Display()=="100.30000");
    histories[PERIOD_M15].back().close=107;
    reject_commands=true; Tick(); assert(Display()=="100.30000" && LastValidText[2]=="100.35000");
    reject_commands=false; rates_ready=false; Tick(); assert(Display()=="100.35000");
    // Accepted-but-unexecuted color update also retries; no implicit object creation.
    drop_next_write=true; assert(SetNumber(name,OBJPROP_COLOR,clrRed));
    assert(Tint()!=clrRed);
    assert(SetNumber(name,OBJPROP_COLOR,clrRed));
    ObjectDelete(0,name); Flush();
    drop_next_write=true; Tick(5); // repair is audited within five seconds
    drop_next_write=false; Tick(); assert(TableObjectsReady());
    ObjectDelete(0,name); Flush(); drop_all_writes=true;
    Tick(5); assert(LayoutCheckPending && !TableLayoutReady());
    drop_all_writes=false; Tick(); Tick(); assert(!TableNeedsRepair && TableObjectsReady());
    Stop(REASON_REMOVE); assert(objects.empty());
}
void CheckReload()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    string prefix=Prefix, value=Display(); datetime last=LastValidTime[2];
    int reads=rates_calls, redraw_count=redraws;
    Stop(REASON_CHARTCHANGE);
    assert(live_handles.empty() && !objects.empty() && redraws==redraw_count);
    _Period=PERIOD_H4; rates_ready=false;
    assert(OnInit()==INIT_SUCCEEDED && Prefix.empty() && rates_calls==reads);
    Tick(); assert(Prefix==prefix);
    assert(LastValidTime[2]==last && LastValidText[2]==value && Display()==value);
    Tick(); assert(Display()==value && redraws==redraw_count);
    wall_time+=4; Tick(); assert(Display()==value+" *");
    Stop(REASON_CHARTCHANGE);
    assert(Start()==INIT_SUCCEEDED && LastValidText[2]==value); // '*' never enters numeric cache
    rates_ready=true; Tick(); assert(Display()==value);
    // Visual text is not used as numerical state, even if externally tampered.
    SetText(ValueName(),OBJPROP_TEXT,"not-a-number");
    Stop(REASON_CHARTCHANGE); assert(Start()==INIT_SUCCEEDED);
    assert(LastValidText[2]==value); Tick(); assert(Display()==value);
    // Changing symbol discards old cache but retains no orphaned table.
    Stop(REASON_CHARTCHANGE); _Symbol="GBPUSD";
    assert(Start()==INIT_SUCCEEDED && Prefix!=prefix);
    assert(ObjectFind(0,prefix+"State")==-1);
    Stop(REASON_REMOVE); assert(objects.empty());
}
void CheckCandidatesAndValidation()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    string valid=Prefix;
    Stop(REASON_CHARTCHANGE);
    // Add a later-sorted invalid candidate so backward traversal examines it first.
    string invalid="BBT_z_invalid_";
    ObjectCreate(0,invalid+"State",OBJ_LABEL,0,0,0);
    assert(SetText(invalid+"State",OBJPROP_TEXT,"pending|"+TableKey+_Symbol));
    assert(Start()==INIT_SUCCEEDED && Prefix==valid);
    assert(ObjectFind(0,invalid+"State")==-1);
    // A missing visual label is repaired using independent numerical cache.
    Stop(REASON_CHARTCHANGE); ObjectDelete(0,valid+"Value2"); Flush();
    assert(Start()==INIT_SUCCEEDED && Prefix==valid);
    Tick(); assert(Display()=="100.10000");
    string number; color tint; datetime updated;
    for(const string bad:{"", "nan", "1abc", "--1", "1.2.3", "-", ".", "1e300", "1,2"})
        assert(!ValidNumberText(bad));
    for(const string good:{"0", "-1.25", "100.00000"}) assert(ValidNumberText(good));
    for(const string bad:{"1|1|255|nan", "1|-1|255|1", "1|1|99999999999|1", "1|1|255|1|extra",
                          "1|1|256|1", "2|1|255|1", "1|1x|255|1"})
        assert(!DecodeRow(bad,number,tint,updated));
    Stop(REASON_CHARTCHANGE);
    assert(SetText(valid+"Cache2",OBJPROP_TEXT,"1|1|255|not-a-number"));
    assert(Start()==INIT_SUCCEEDED && Prefix!=valid);
    assert(ObjectFind(0,valid+"State")==-1);
    Stop(REASON_REMOVE);
}
void CheckMultipleInstances()
{
    Reset(); assert(Start()==INIT_SUCCEEDED);
    string first=Prefix; Stop(REASON_CHARTCHANGE);
    // Clone a same-settings pending instance; each claim must be independent.
    auto snapshot=objects;
    string second="BBT_z_second_";
    for(const auto &entry:snapshot)
        objects[second+entry.first.substr(first.size())]=entry.second;
    assert(SetLease(second,1));
    assert(Start()==INIT_SUCCEEDED);
    string claimed=Prefix;
    Stop(REASON_REMOVE);
    assert(Start()==INIT_SUCCEEDED && Prefix!=claimed);
    Stop(REASON_REMOVE); assert(objects.empty());
    Reset(); assert(Start()==INIT_SUCCEEDED);
    first=Prefix; Stop(REASON_CHARTCHANGE);
    InpTableX=300; assert(Start()==INIT_SUCCEEDED && Prefix!=first);
    second=Prefix; Stop(REASON_CHARTCHANGE);
    InpTableX=20; assert(Start()==INIT_SUCCEEDED && Prefix==first);
    Stop(REASON_REMOVE); assert(ObjectFind(0,second+"State")>=0);
    InpTableX=300; assert(Start()==INIT_SUCCEEDED && Prefix==second);
    Stop(REASON_REMOVE); assert(objects.empty());
}
void CheckSelectionAndFailures()
{
    Reset(); InpShowM15=false; InpShowM30=false; InpShowH1=false; InpShowH4=false;
    assert(OnInit()==INIT_SUCCEEDED && SelectedCount==0 && !timer_running && objects.empty());
    Tick(); assert(rates_calls==0); Stop(REASON_REMOVE);
    Reset(); InpShowM1=true; InpShowM15=false; InpShowM30=false; InpShowH1=false; InpShowH4=false; InpShowMN1=true;
    assert(Start()==INIT_SUCCEEDED && SelectedCount==2 && rates_calls==2);
    assert(ObjectGetInteger(0,Prefix+"Background",OBJPROP_YSIZE)==108);
    assert(ObjectFind(0,Prefix+"Value2")==-1 && ObjectFind(0,Prefix+"Value8")>=0);
    Stop(REASON_REMOVE);
    for(int failure=0;failure<7;++failure)
    {
        Reset();
        if(failure==0) InpPeriod=1;
        if(failure==1) fail_buffer_bind=1;
        if(failure==2) fail_plot=true;
        if(failure==3) fail_bands=true;
        if(failure==4) fail_create=true;
        if(failure==5) fail_timer=true;
        if(failure==6) drop_all_writes=true;
        if(failure==4 || failure==6)
        {
            assert(OnInit()==INIT_SUCCEEDED); // GUI failures cannot disable line buffers
            assert(Calculate(40,0)==40 && MiddleBuffer[39]==chart_values[0][39]);
            int messages_before=log_messages;
            Tick(); Tick();
            assert(log_messages>messages_before);
        }
        else { assert(OnInit()!=INIT_SUCCEEDED); assert(log_messages>=1); }
        Stop(REASON_INITFAILED);
        assert(objects.empty() && live_handles.empty() && !timer_running);
    }
    Reset(); rates_ready=false; assert(Start()==INIT_SUCCEEDED && Display()=="Loading...");
    rates_ready=true; Tick(); assert(Display()=="100.10000");
    Stop(REASON_CHARTCHANGE); fail_bands=true;
    assert(OnInit()==INIT_FAILED); Stop(REASON_INITFAILED);
    assert(objects.empty() && live_handles.empty());
}
void CheckLightInitAndDeferredLayout()
{
    Reset();
    // A chart with many drawing objects must not be enumerated one object at a time.
    for(int i=0;i<1000;++i)
        objects["OTHER_"+IntegerToString(i)].number[OBJPROP_TYPE]=OBJ_RECTANGLE_LABEL;
    int reads=object_reads;
    assert(OnInit()==INIT_SUCCEEDED);
    assert(object_reads-reads<=8 && object_writes==0 && rates_calls==0);
    assert(Calculate(40,0)==40); // BB is available before any table work
    int builds_before=object_writes;
    Tick(); Flush();
    assert(object_writes>builds_before && TableObjectsReady() && TableLayoutReady());
    int reads_before=object_reads;
    Stop(REASON_CHARTCHANGE);
    assert(object_reads==reads_before && delete_all_calls==0); // no graphical barriers on handoff
    reads_before=object_reads;
    assert(OnInit()==INIT_SUCCEEDED);
    assert(object_reads==reads_before); // restoration is deferred to the timer
    Stop(REASON_REMOVE);
    assert(objects.size()==1000);
    Reset();
    assert(OnInit()==INIT_SUCCEEDED);
    // An accepted but dropped layout setter is reconciled on a later timer.
    drop_all_writes=true; Tick();
    assert(LayoutCheckPending && !TableLayoutReady());
    drop_all_writes=false; Tick(); Tick();
    assert(TableLayoutReady() && Display()=="100.10000");
    Stop(REASON_REMOVE);
}
void CheckNonblockingHandoffAndAudit()
{
    Reset(); assert(Start()==INIT_SUCCEEDED); Tick();
    string prefix=Prefix, value=Display();
    for(int i=0;i<4;++i)
    {
        int reads=object_reads, writes=object_writes, deletes=delete_calls, paints=redraws;
        OnDeinit(REASON_CHARTCHANGE); // deliberately do not flush chart commands yet
        assert(object_reads==reads && object_writes==writes && delete_calls==deletes && redraws==paints);
        assert(delete_all_calls==0 && GlobalVariableGet(LeaseKey(prefix))==1);
        _Period=i%2 ? PERIOD_M15 : PERIOD_H4;
        assert(OnInit()==INIT_SUCCEEDED && object_reads==reads && object_writes==writes && Prefix.empty());
        assert(Calculate(40,0)==40); // plotting does not wait for table restoration
        Tick(); assert(Prefix==prefix && Display()==value && GlobalVariableGet(LeaseKey(prefix))==0);
        assert(temporary_globals.size()==1);
    }
    // Multiple chart changes before the first timer preserve the released checkpoint.
    Stop(REASON_CHARTCHANGE);
    assert(OnInit()==INIT_SUCCEEDED); Stop(REASON_CHARTCHANGE);
    assert(OnInit()==INIT_SUCCEEDED); Stop(REASON_CHARTCHANGE);
    assert(Start()==INIT_SUCCEEDED && Prefix==prefix);
    // Retry a rejected claim without deleting the last visible valid table.
    Stop(REASON_CHARTCHANGE); assert(OnInit()==INIT_SUCCEEDED);
    reject_claims=true; Tick();
    assert(RestorePending && Prefix.empty() && ObjectFind(0,prefix+"State")>=0);
    reject_claims=false; Tick(); assert(Prefix==prefix && Display()==value);
    // An accepted write can be lost; ordinary refresh stays cheap until the audit.
    histories[PERIOD_M15].back().close=108;
    drop_next_write=true; Tick(); assert(Display()==value && LastValidText[2]=="100.40000");
    int reads=object_reads;
    Tick(1); assert(object_reads==reads);
    assert(Display()==value);
    Tick(4); assert(Display()=="100.40000");
    Stop(REASON_REMOVE);
    assert(objects.empty() && temporary_globals.empty() && delete_all_calls==0);
    std::puts("Performance contracts passed: zero graphical reads in init/ordinary refresh, zero graphical calls in TF deinit.");
}
void CheckPlotBuffers()
{
    Reset(); assert(OnInit()==INIT_SUCCEEDED);
    assert(Calculate(40,0)==40);
    assert(copy_counts==std::vector<int>({40,40,40}));
    for(int i=0;i<40;++i) assert(MiddleBuffer[i]==chart_values[0][i]);
    copy_counts.clear(); chart_values[0].back()=500;
    assert(Calculate(40,40)==40 && copy_counts==std::vector<int>({1,1,1}));
    assert(MiddleBuffer[39]==500 && MiddleBuffer[38]==chart_values[0][38]);
    for(auto &values:chart_values) values.push_back(600);
    copy_counts.clear(); assert(Calculate(41,40)==41);
    assert(copy_counts==std::vector<int>({2,2,2}) && MiddleBuffer[40]==600);
    for(auto &values:chart_values) values.push_back(700);
    failed_copy_index=1; assert(Calculate(42,41)==41);
    assert(MiddleBuffer[41]==EMPTY_VALUE && MiddleBuffer[40]==600); // no partial commits
    failed_copy_index=-1; assert(Calculate(42,41)==42 && MiddleBuffer[41]==700);
    calculated=0; assert(Calculate(42,0)==0 && MiddleBuffer[0]==EMPTY_VALUE);
    calculated=-1; assert(Calculate(42,0)==42);
    for(auto &values:chart_values) values.resize(25);
    assert(Calculate(25,42)==25); // shrinking/reset histories cannot return invalid progress
    Stop(REASON_REMOVE);
}
int main()
{
    CheckSignals(); CheckLiveTable(); CheckPrices(); CheckQueuedCommands();
    CheckReload(); CheckCandidatesAndValidation(); CheckMultipleInstances();
    CheckSelectionAndFailures(); CheckPlotBuffers(); CheckLightInitAndDeferredLayout();
    CheckNonblockingHandoffAndAudit();
    std::puts("BollingerTable full-source lifecycle, async objects, snapshot/SMA, cache and buffer checks passed.");
}
