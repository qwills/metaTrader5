"""Fake broker for manualFibo execution regression tests; never connects to MT5."""
TRADE_API = r'''
using uint=unsigned int;
const int CHART_HEIGHT_IN_PIXELS=6200,CONTROLS_BORDER_WIDTH=1;
const int ACCOUNT_MARGIN_FREE=20,ACCOUNT_SERVER=21,ACCOUNT_LOGIN=22,ACCOUNT_TRADE_ALLOWED=23,ACCOUNT_TRADE_EXPERT=24;
const int TERMINAL_CONNECTED=30,TERMINAL_TRADE_ALLOWED=31,MQL_TRADE_ALLOWED=32;
const int ORDER_MAGIC=40,ORDER_SYMBOL=41,ORDER_COMMENT=42,ORDER_STATE=43,ORDER_TYPE=44,ORDER_STATE_REJECTED=45;
const int TRADE_ACTION_PENDING=50,TRADE_ACTION_REMOVE=51,ORDER_FILLING_RETURN=52,ORDER_TIME_GTC=53;
const uint TRADE_RETCODE_PLACED=10008,TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,
 TRADE_RETCODE_ERROR=10011,TRADE_RETCODE_TIMEOUT=10012,TRADE_RETCODE_CONNECTION=10031,TRADE_RETCODE_LOCKED=10028,
 TRADE_RETCODE_REJECT=10006;
struct MqlTradeRequest{
 int action=0;ulong magic=0,order=0;string symbol,comment;ENUM_ORDER_TYPE type=ORDER_TYPE_BUY;
 int type_filling=0,type_time=0;double price=0,sl=0,tp=0,volume=0;
};
struct MqlTradeResult{uint retcode=0;ulong order=0;string comment;};
struct MqlTradeCheckResult{uint retcode=0;string comment;};
template<class T>void ZeroMemory(T&v){v=T{};}
struct FakeOrder{ulong ticket;MqlTradeRequest request;int state=0;};
std::vector<FakeOrder> broker_orders,broker_history;
std::vector<MqlTradeRequest> sent_requests;
std::vector<uint> send_codes;
std::map<string,double> terminal_globals;
int order_selected=-1,send_index=0,check_calls=0,check_fail_at=0;
bool trading_allowed=true,history_allowed=true,margin_failure=false,marker_failure=false,send_return=true;
double free_margin=100000,margin_per_order=100;
ulong next_ticket=100;
long AccountInfoInteger(int prop){return prop==ACCOUNT_LOGIN?12345:trading_allowed;}
long TerminalInfoInteger(int){return trading_allowed;}
long MQLInfoInteger(int){return trading_allowed;}
datetime TimeCurrent(){return 1800000000;}
bool GlobalVariableTemp(const string&key){terminal_globals.emplace(key,0);return true;}
bool GlobalVariableSetOnCondition(const string&key,double v,double previous){if(!terminal_globals.count(key)||terminal_globals[key]!=previous)return false;terminal_globals[key]=v;return true;}
datetime GlobalVariableSet(const string&key,double v){if(marker_failure&&key.find("MF:")!=string::npos)return 0;terminal_globals[key]=v;return 1800000000;}
bool GlobalVariableCheck(const string&key){return terminal_globals.count(key);}
bool GlobalVariableDel(const string&key){return terminal_globals.erase(key)>0;}
void GlobalVariablesFlush(){}
int OrdersTotal(){return broker_orders.size();}
ulong OrderGetTicket(int i){order_selected=i;return broker_orders.at(i).ticket;}
long OrderGetInteger(int prop){auto&o=broker_orders.at(order_selected);if(prop==ORDER_MAGIC)return o.request.magic;if(prop==ORDER_TYPE)return o.request.type;return o.state;}
string OrderGetString(int prop){auto&o=broker_orders.at(order_selected);return prop==ORDER_SYMBOL?o.request.symbol:o.request.comment;}
bool HistorySelect(datetime,datetime){return history_allowed;}
int HistoryOrdersTotal(){return broker_history.size();}
ulong HistoryOrderGetTicket(int i){return broker_history.at(i).ticket;}
FakeOrder&HistoryFind(ulong ticket){for(auto&o:broker_history)if(o.ticket==ticket)return o;std::abort();}
long HistoryOrderGetInteger(ulong ticket,int prop){auto&o=HistoryFind(ticket);return prop==ORDER_MAGIC?static_cast<long>(o.request.magic):o.state;}
string HistoryOrderGetString(ulong ticket,int prop){auto&o=HistoryFind(ticket);return prop==ORDER_SYMBOL?o.request.symbol:o.request.comment;}
bool OrderCalcMargin(ENUM_ORDER_TYPE side,const string&,double,double,double&margin){assert(side==ORDER_TYPE_BUY||side==ORDER_TYPE_SELL);margin=margin_per_order;return !margin_failure;}
bool OrderCheck(MqlTradeRequest&r,MqlTradeCheckResult&result){
 ++check_calls;assert(r.action==TRADE_ACTION_PENDING);assert(r.type==ORDER_TYPE_BUY_LIMIT||r.type==ORDER_TYPE_SELL_LIMIT);
 result.retcode=check_calls==check_fail_at?TRADE_RETCODE_REJECT:0;result.comment="fake check";return check_calls!=check_fail_at;
}
bool OrderSend(MqlTradeRequest&r,MqlTradeResult&result){
 sent_requests.push_back(r);result.retcode=send_index<static_cast<int>(send_codes.size())?send_codes[send_index]:TRADE_RETCODE_DONE;++send_index;
 if(r.action==TRADE_ACTION_PENDING){
  assert(r.type==ORDER_TYPE_BUY_LIMIT||r.type==ORDER_TYPE_SELL_LIMIT);
  assert(r.type_filling==ORDER_FILLING_RETURN&&r.type_time==ORDER_TIME_GTC&&r.comment.size()<=31);
  if(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_PLACED||result.retcode==TRADE_RETCODE_DONE_PARTIAL){result.order=next_ticket++;broker_orders.push_back({result.order,r,0});}
 }else{
  assert(r.action==TRADE_ACTION_REMOVE);
  if(result.retcode==TRADE_RETCODE_DONE){for(auto it=broker_orders.begin();it!=broker_orders.end();++it)if(it->ticket==r.order){broker_history.push_back(*it);broker_orders.erase(it);break;}}
 }
 result.comment="fake result";return send_return;
}
'''

TRADE_TESTS = r'''
void RunOrderChecks(){
 auto reset=[](){broker_orders.clear();broker_history.clear();sent_requests.clear();send_codes.clear();terminal_globals.clear();send_index=0;check_calls=0;check_fail_at=0;trading_allowed=true;history_allowed=true;margin_failure=false;marker_failure=false;send_return=true;free_margin=100000;bid=199;ask=200;point_size=.01;tick_size=.01;stops_level=0;equity=10000;volume_step=.01;volume_min=.01;volume_max=100;profit_failure=false;quote_failure=false;stops_failure=false;};
 reset();CFiboModel model;model.SetAnchors(100,100,200,200);CManualFiboOrders orders;Check(orders.Configure(11600101),"configure order identity");
 orders.Send(model,true);Check(sent_requests.size()==3&&broker_orders.size()==3,"single batch sends selected levels");
 for(auto&r:sent_requests)Check(r.type==ORDER_TYPE_BUY_LIMIT&&r.sl==100&&r.tp==200&&r.magic==11600101,"buy limit entry SL TP magic");
 orders.Send(model,true);Check(sent_requests.size()==3,"repeated click cannot duplicate");
 model.SetRiskPercent(2);model.SetStop(2,90);orders.Send(model,false);Check(sent_requests.size()==3,"risk SL TP edits do not reset identity");
 CManualFiboOrders reloaded;reloaded.Configure(11600101);reloaded.Send(model,true);Check(sent_requests.size()==3,"new engine retains ledger");
 orders.Delete();Check(broker_orders.empty()&&sent_requests.size()==6,"delete all owned pending limits");
 orders.Send(model,true);Check(sent_requests.size()==6,"deletion does not rearm same setup");
 terminal_globals.clear();orders.Send(model,true);Check(sent_requests.size()==6,"history prevents resending cancelled setup after ledger loss");
 reset();bid=50;ask=51;model.SetAnchors(101,200,201,100);model.ResetStop(2);orders.Send(model,false);Check(sent_requests.size()==3,"sell batch");
 for(auto&r:sent_requests)Check(r.type==ORDER_TYPE_SELL_LIMIT&&r.sl==200&&r.tp==0,"sell limit no TP");
 reset();model.SetAnchors(100,100,200,200);model.SetStop(4,199);orders.Send(model,true);Check(sent_requests.empty(),"invalid later level blocks all sends");model.ResetStop(4);
 reset();free_margin=250;orders.Send(model,true);Check(sent_requests.empty(),"aggregate margin checked before sending");
 reset();check_fail_at=3;orders.Send(model,true);Check(sent_requests.empty(),"broker rejection during full preflight sends nothing");
 reset();send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT,TRADE_RETCODE_PLACED};orders.Send(model,true);Check(sent_requests.size()==3&&broker_orders.size()==2,"partial failure retains successes");orders.Send(model,true);Check(sent_requests.size()==4&&broker_orders.size()==3,"retry sends only failed level");
 reset();send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,true);orders.Send(model,true);Check(sent_requests.size()==3,"ambiguous timeout cannot be blindly retried");
 reset();marker_failure=true;orders.Send(model,true);Check(sent_requests.empty(),"ledger failure blocks sending");
 reset();trading_allowed=false;orders.Send(model,true);Check(sent_requests.empty(),"trading permissions checked");
 reset();history_allowed=false;orders.Send(model,true);Check(sent_requests.empty(),"history failure fails closed");
 reset();bid=149;ask=151;orders.Send(model,true);Check(sent_requests.empty(),"spread entry blocks batch");
 reset();bid=50;ask=51;for(int i=0;i<FIBO_RATIOS;i++)model.SetStop(i,220);orders.Send(model,true);Check(sent_requests.empty(),"TP on wrong side blocks batch");for(int i=0;i<FIBO_RATIOS;i++)model.ResetStop(i);
 reset();orders.Send(model,true);auto foreign=broker_orders.front();foreign.ticket=999;foreign.request.magic=7;broker_orders.push_back(foreign);foreign.ticket=998;foreign.request.magic=11600101;foreign.request.symbol="OTHER";broker_orders.push_back(foreign);foreign.ticket=997;foreign.request.symbol=_Symbol;foreign.request.comment="other EA";broker_orders.push_back(foreign);foreign.ticket=996;foreign.request.comment="MF:foreign-stop";foreign.request.type=ORDER_TYPE_BUY_STOP;broker_orders.push_back(foreign);
 orders.Delete();Check(broker_orders.size()==4,"delete excludes other magic symbol comment and stops");
 reset();orders.Send(model,true);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT};orders.Delete();Check(broker_orders.size()==1,"failed deletion leaves order available for retry");orders.Delete();Check(broker_orders.empty(),"retry failed deletion");
 reset();
 // Actual GUI path, including a text edit whose end-edit event has not fired.
 Check(OnInit()==INIT_SUCCEEDED,"restart GUI for execution");g_model.CopyFrom(model);g_dialog.Refresh(g_model);g_chart.Draw(g_model);
 controls["manualFibo.Panel.Risk"]->Text("2");Action("Send",ON_CLICK);
 Check(sent_requests.size()==3&&g_model.RiskPercent()==2,"send button commits current risk text before submitting");
 Action("Delete",ON_CLICK);Check(broker_orders.empty(),"delete button routes to scoped deletion");
 double listed=0;for(int i=2;i<=4;i++)listed+=StringToDouble(controls["manualFibo.Panel.Loss"+IntegerToString(i)]->text);
 Check(listed>0&&listed<=600&&controls["manualFibo.Panel.Total"]->text.find(DoubleToString(listed,2)+" USD")!=string::npos,"combined loss follows displayed rows and downward rounding");
 g_dialog.UseTP(false);OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&!g_dialog.UseTP(),"TP choice survives timeframe change");
 size_t before=sent_requests.size();Action("Send",ON_CLICK);Check(sent_requests.size()==before,"timeframe reinitialization does not resend setup");
 // Input validation must not erase unsaved edits on a send click.
 g_model.SetAnchors(300,100,400,200);g_chart.Draw(g_model);g_dialog.Refresh(g_model);
 controls["manualFibo.Panel.Risk"]->Text("bad");Action("Send",ON_CLICK);Check(sent_requests.size()==before,"invalid live risk input blocks sending");
 controls["manualFibo.Panel.Risk"]->Text("2");controls["manualFibo.Panel.SL2"]->Text("90");Action("Send",ON_CLICK);
 Check(sent_requests.size()==before+3&&sent_requests[before].sl==90,"live custom SL is captured without end-edit event");
 Action("Delete",ON_CLICK);
 // A different chart sharing account/symbol/magic cannot race an in-flight batch.
 reset();orders.Configure(11600101);string lock_key=terminal_globals.empty()?"":terminal_globals.begin()->first;
 orders.Send(model,true);for(auto &entry:terminal_globals)if(entry.first.find("Lock")!=string::npos)lock_key=entry.first;
 terminal_globals[lock_key]=1;before=sent_requests.size();orders.Delete();Check(sent_requests.size()==before,"busy terminal mutex blocks a competing command");terminal_globals[lock_key]=0;
 reset();check_fail_at=5;orders.Send(model,true);Check(sent_requests.size()==2&&broker_orders.size()==2,"per-request recheck can fail safely after preflight");
 reset();orders.Send(model,true);broker_history=broker_orders;broker_orders.clear();terminal_globals.clear();before=sent_requests.size();orders.Send(model,true);Check(sent_requests.size()==before,"filled history blocks repeat even without terminal records");
 OnDeinit(0);
 std::cout<<"PASS: manualFibo batch limit execution, preflight, TP, duplicate/retry ledger, scoped deletion and GUI actions.\n";
}
'''
