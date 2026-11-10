"""Fake broker for manualFibo execution regression tests; never connects to MT5."""
TRADE_API = r'''
using uint=unsigned int;
const int CHART_HEIGHT_IN_PIXELS=6200,CONTROLS_BORDER_WIDTH=1;
const int ACCOUNT_MARGIN_FREE=20,ACCOUNT_SERVER=21,ACCOUNT_LOGIN=22,ACCOUNT_TRADE_ALLOWED=23,ACCOUNT_TRADE_EXPERT=24;
const int TERMINAL_CONNECTED=30,TERMINAL_TRADE_ALLOWED=31,MQL_TRADE_ALLOWED=32;
const int ORDER_MAGIC=40,ORDER_SYMBOL=41,ORDER_COMMENT=42,ORDER_STATE=43,ORDER_TYPE=44,ORDER_STATE_REJECTED=45,ORDER_STATE_CANCELED=46,ORDER_STATE_FILLED=47,ORDER_STATE_EXPIRED=48,ORDER_VOLUME_INITIAL=49,ORDER_VOLUME_CURRENT=54,ORDER_POSITION_ID=55;
const int TRADE_ACTION_PENDING=50,TRADE_ACTION_REMOVE=51,ORDER_FILLING_RETURN=52,ORDER_TIME_GTC=53;
const uint TRADE_RETCODE_PLACED=10008,TRADE_RETCODE_DONE=10009,TRADE_RETCODE_DONE_PARTIAL=10010,
 TRADE_RETCODE_ERROR=10011,TRADE_RETCODE_TIMEOUT=10012,TRADE_RETCODE_CONNECTION=10031,TRADE_RETCODE_LOCKED=10028,
 TRADE_RETCODE_REJECT=10006;
struct MqlTradeRequest{
 int action=0;ulong magic=0,order=0;string symbol,comment;ENUM_ORDER_TYPE type=ORDER_TYPE_BUY;
 int type_filling=0,type_time=0;double price=0,sl=0,tp=0,volume=0;
};
struct MqlTradeResult{uint request_id=0,retcode=0;ulong order=0;string comment;};
const uint TRADE_RETCODE_REQUOTE=10004,TRADE_RETCODE_CANCEL=10007,TRADE_RETCODE_INVALID=10013,
 TRADE_RETCODE_INVALID_EXPIRATION=10022,TRADE_RETCODE_TOO_MANY_REQUESTS=10024,
 TRADE_RETCODE_SERVER_DISABLES_AT=10026,TRADE_RETCODE_CLIENT_DISABLES_AT=10027,
 TRADE_RETCODE_FROZEN=10029,TRADE_RETCODE_INVALID_FILL=10030,TRADE_RETCODE_ONLY_REAL=10032,TRADE_RETCODE_LIMIT_POSITIONS=10040;
const int TRADE_TRANSACTION_REQUEST=70,TRADE_TRANSACTION_ORDER_ADD=71,TRADE_TRANSACTION_HISTORY_ADD=72;
struct MqlTradeTransaction{int type=0;ulong order=0;string symbol;};
struct MqlTradeCheckResult{uint retcode=0;string comment;};
template<class T>void ZeroMemory(T&v){v=T{};}
struct FakeOrder{ulong ticket;MqlTradeRequest request;int state=0;double remaining=-1;long position=0;};
std::vector<FakeOrder> broker_orders,broker_history;
std::vector<MqlTradeRequest> sent_requests;
std::vector<uint> send_codes;
std::map<string,double> terminal_globals;
int order_selected=-1,send_index=0,check_calls=0,check_fail_at=0;
bool trading_allowed=true,history_allowed=true,margin_failure=false,marker_failure=false,send_return=true;
double free_margin=100000,margin_per_order=100;
ulong next_ticket=100;
int history_scans=0,active_reads=0,ticket_probes=0;
long AccountInfoInteger(int prop){return prop==ACCOUNT_LOGIN?12345:trading_allowed;}
long TerminalInfoInteger(int){return trading_allowed;}
long MQLInfoInteger(int){return trading_allowed;}
datetime TimeCurrent(){return 1800000000;}
int GlobalVariablesTotal(){return terminal_globals.size();}
string GlobalVariableName(int index){auto it=terminal_globals.begin();std::advance(it,index);return it->first;}
double GlobalVariableGet(const string&key){return terminal_globals.count(key)?terminal_globals[key]:0;}
int temp_create_calls=0;bool temp_create_failure=false,mutex_cas_failure=false,create_race=false,generation_failure=false;
bool GlobalVariableTemp(const string&key){++temp_create_calls;if(create_race){terminal_globals.emplace(key,0);create_race=false;return false;}if(temp_create_failure)return false;return terminal_globals.emplace(key,0).second;}
bool GlobalVariableGet(const string&key,double&v){if(!terminal_globals.count(key))return false;v=terminal_globals[key];return true;}
bool GlobalVariableSetOnCondition(const string&key,double v,double previous){if(mutex_cas_failure)return false;if(!terminal_globals.count(key)||terminal_globals[key]!=previous)return false;terminal_globals[key]=v;return true;}
datetime GlobalVariableSet(const string&key,double v){if(generation_failure&&key.find(".Gen")!=string::npos)return 0;if(marker_failure&&key.find("MF:")!=string::npos)return 0;terminal_globals[key]=v;return 1800000000;}
bool GlobalVariableCheck(const string&key){return terminal_globals.count(key);}
bool GlobalVariableDel(const string&key){return terminal_globals.erase(key)>0;}
void GlobalVariablesFlush(){}
int OrdersTotal(){return broker_orders.size();}
bool OrderSelect(ulong ticket){++ticket_probes;for(size_t i=0;i<broker_orders.size();i++)if(broker_orders[i].ticket==ticket){order_selected=i;return true;}return false;}
ulong OrderGetTicket(int i){++active_reads;order_selected=i;return broker_orders.at(i).ticket;}
long OrderGetInteger(int prop){auto&o=broker_orders.at(order_selected);if(prop==ORDER_MAGIC)return o.request.magic;if(prop==ORDER_TYPE)return o.request.type;if(prop==ORDER_POSITION_ID)return o.position;return o.state;}
string OrderGetString(int prop){auto&o=broker_orders.at(order_selected);return prop==ORDER_SYMBOL?o.request.symbol:o.request.comment;}
bool HistorySelect(datetime,datetime){++history_scans;return history_allowed;}
bool HistoryOrderSelect(ulong ticket){++ticket_probes;if(!history_allowed)return false;for(auto&o:broker_history)if(o.ticket==ticket)return true;return false;}
int HistoryOrdersTotal(){return broker_history.size();}
ulong HistoryOrderGetTicket(int i){return broker_history.at(i).ticket;}
FakeOrder&HistoryFind(ulong ticket){for(auto&o:broker_history)if(o.ticket==ticket)return o;std::abort();}
long HistoryOrderGetInteger(ulong ticket,int prop){auto&o=HistoryFind(ticket);if(prop==ORDER_MAGIC)return static_cast<long>(o.request.magic);if(prop==ORDER_TYPE)return o.request.type;if(prop==ORDER_POSITION_ID)return o.position;return o.state;}
double HistoryOrderGetDouble(ulong ticket,int prop){auto&o=HistoryFind(ticket);return prop==ORDER_VOLUME_INITIAL?o.request.volume:(o.remaining<0?o.request.volume:o.remaining);}
string HistoryOrderGetString(ulong ticket,int prop){auto&o=HistoryFind(ticket);return prop==ORDER_SYMBOL?o.request.symbol:o.request.comment;}
bool OrderCalcMargin(ENUM_ORDER_TYPE side,const string&,double,double,double&margin){assert(side==ORDER_TYPE_BUY||side==ORDER_TYPE_SELL);margin=margin_per_order;return !margin_failure;}
bool OrderCheck(MqlTradeRequest&r,MqlTradeCheckResult&result){
 ++check_calls;assert(r.action==TRADE_ACTION_PENDING);assert(r.type==ORDER_TYPE_BUY_LIMIT||r.type==ORDER_TYPE_SELL_LIMIT);
 result.retcode=check_calls==check_fail_at?TRADE_RETCODE_REJECT:0;result.comment="fake check";return check_calls!=check_fail_at;
}
bool OrderSend(MqlTradeRequest&r,MqlTradeResult&result){
 sent_requests.push_back(r);result.retcode=send_index<static_cast<int>(send_codes.size())?send_codes[send_index]:TRADE_RETCODE_DONE;++send_index;result.request_id=send_index;
 if(r.action==TRADE_ACTION_PENDING){
  assert(r.type==ORDER_TYPE_BUY_LIMIT||r.type==ORDER_TYPE_SELL_LIMIT);
  assert(r.type_filling==ORDER_FILLING_RETURN&&r.type_time==ORDER_TIME_GTC&&r.comment.size()<=31);
  if(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_PLACED||result.retcode==TRADE_RETCODE_DONE_PARTIAL){result.order=next_ticket++;broker_orders.push_back({result.order,r,0});}
 }else{
  assert(r.action==TRADE_ACTION_REMOVE);
  if(result.retcode==TRADE_RETCODE_DONE){for(auto it=broker_orders.begin();it!=broker_orders.end();++it)if(it->ticket==r.order){it->state=ORDER_STATE_CANCELED;broker_history.push_back(*it);broker_orders.erase(it);break;}}
 }
 result.comment="fake result";return send_return;
}
'''

TRADE_TESTS = r'''
void RunOrderChecks(){
 CManualFiboSettings swing_tp, none_tp;none_tp.SetTPMode(MANUAL_TP_NONE);
 auto reset=[](){broker_orders.clear();broker_history.clear();sent_requests.clear();send_codes.clear();terminal_globals.clear();send_index=0;check_calls=0;check_fail_at=0;trading_allowed=true;history_allowed=true;margin_failure=false;marker_failure=false;send_return=true;free_margin=100000;bid=199;ask=200;point_size=.01;tick_size=.01;stops_level=0;equity=10000;balance=10000;volume_step=.01;volume_min=.01;volume_max=100;profit_failure=false;quote_failure=false;stops_failure=false;};
 reset();CFiboModel model;model.SetAnchors(100,100,200,200);CManualFiboOrders orders;Check(orders.Configure(11600101),"configure order identity");
 orders.Send(model,swing_tp);Check(sent_requests.size()==3&&broker_orders.size()==3,"single batch sends selected levels");
 for(auto&r:sent_requests)Check(r.type==ORDER_TYPE_BUY_LIMIT&&r.sl==100&&r.tp==200&&r.magic==11600101,"buy limit entry SL TP magic");
 orders.Send(model,swing_tp);Check(sent_requests.size()==3,"repeated click cannot duplicate");
 model.SetRiskPercent(2);model.SetStop(2,90);orders.Send(model,none_tp);Check(sent_requests.size()==3,"risk SL TP edits do not reset identity");
 CManualFiboOrders reloaded;reloaded.Configure(11600101);reloaded.Send(model,swing_tp);Check(sent_requests.size()==3,"new engine retains ledger");
 orders.Delete();Check(broker_orders.empty()&&sent_requests.size()==6,"delete all owned pending limits");
 orders.Send(model,swing_tp);Check(sent_requests.size()==9&&broker_orders.size()==3,"confirmed no-fill deletion rearms same setup");
 terminal_globals.clear();orders.Send(model,swing_tp);Check(sent_requests.size()==9,"active new attempt prevents duplicate after ledger loss");
 reset();bid=50;ask=51;model.SetAnchors(101,200,201,100);model.ResetStop(2);orders.Send(model,none_tp);Check(sent_requests.size()==3,"sell batch");
 for(auto&r:sent_requests)Check(r.type==ORDER_TYPE_SELL_LIMIT&&r.sl==200&&r.tp==0,"sell limit no TP");
 reset();model.SetAnchors(100,100,200,200);model.SetStop(4,199);orders.Send(model,swing_tp);Check(sent_requests.empty(),"invalid later level blocks all sends");model.ResetStop(4);
 reset();free_margin=250;orders.Send(model,swing_tp);Check(sent_requests.empty(),"aggregate margin checked before sending");
 reset();check_fail_at=3;orders.Send(model,swing_tp);Check(sent_requests.empty(),"broker rejection during full preflight sends nothing");
 reset();send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT,TRADE_RETCODE_PLACED};orders.Send(model,swing_tp);Check(sent_requests.size()==3&&broker_orders.size()==2,"partial failure retains successes");orders.Send(model,swing_tp);Check(sent_requests.size()==4&&broker_orders.size()==3,"retry sends only failed level");
 reset();send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);orders.Send(model,swing_tp);Check(sent_requests.size()==3,"ambiguous timeout cannot be blindly retried");
 reset();marker_failure=true;orders.Send(model,swing_tp);Check(sent_requests.empty(),"ledger failure blocks sending");
 reset();trading_allowed=false;orders.Send(model,swing_tp);Check(sent_requests.empty(),"trading permissions checked");
 reset();history_allowed=false;orders.Send(model,swing_tp);Check(sent_requests.empty(),"history failure fails closed");
 reset();bid=149;ask=151;orders.Send(model,swing_tp);Check(sent_requests.empty(),"spread entry blocks batch");
 reset();bid=50;ask=51;for(int i=0;i<FIBO_RATIOS;i++)model.SetStop(i,220);orders.Send(model,swing_tp);Check(sent_requests.empty(),"TP on wrong side blocks batch");for(int i=0;i<FIBO_RATIOS;i++)model.ResetStop(i);
 reset();orders.Send(model,swing_tp);auto foreign=broker_orders.front();foreign.ticket=999;foreign.request.magic=7;broker_orders.push_back(foreign);foreign.ticket=998;foreign.request.magic=11600101;foreign.request.symbol="OTHER";broker_orders.push_back(foreign);foreign.ticket=997;foreign.request.symbol=_Symbol;foreign.request.comment="other EA";broker_orders.push_back(foreign);foreign.ticket=996;foreign.request.comment="MF:foreign-stop";foreign.request.type=ORDER_TYPE_BUY_STOP;broker_orders.push_back(foreign);
 orders.Delete();Check(broker_orders.size()==4,"delete excludes other magic symbol comment and stops");
 reset();orders.Send(model,swing_tp);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT};orders.Delete();Check(broker_orders.size()==1,"failed deletion leaves order available for retry");orders.Delete();Check(broker_orders.empty(),"retry failed deletion");
 reset();
 // Actual GUI path, including a text edit whose end-edit event has not fired.
 Check(OnInit()==INIT_SUCCEEDED,"restart GUI for execution");g_model.CopyFrom(model);g_model.SetBalanceRisk(true);g_dialog.Refresh(g_model);g_chart.Draw(g_model);
 controls["manualFibo.Panel.Risk"]->Text("2");Action("Send",ON_CLICK);
 Check(sent_requests.size()==3&&g_model.RiskPercent()==2,"send button commits current risk text before submitting");
 Action("Delete",ON_CLICK);Check(broker_orders.empty(),"delete button routes to scoped deletion");
 double listed=0;for(int i=2;i<=4;i++)listed+=StringToDouble(controls["manualFibo.Panel.Loss"+IntegerToString(i)]->text);
 Check(listed>0&&listed<=600&&controls["manualFibo.Panel.Total"]->text.find(DoubleToString(listed,2)+" USD")!=string::npos,"combined loss follows displayed rows and downward rounding");
 g_dialog.RefreshSettings(none_tp);OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&g_dialog.TPMode()==MANUAL_TP_NONE,"TP choice survives timeframe change");
 size_t before=sent_requests.size();Action("Send",ON_CLICK);Check(sent_requests.size()==before+3,"confirmed deletion remains rearmed across timeframe change");Action("Send",ON_CLICK);Check(sent_requests.size()==before+3,"reattached active attempt cannot duplicate");Action("Delete",ON_CLICK);before=sent_requests.size();
 // Input validation must not erase unsaved edits on a send click.
 g_model.SetAnchors(300,100,400,200);g_chart.Draw(g_model);g_dialog.Refresh(g_model);
 controls["manualFibo.Panel.Risk"]->Text("bad");Action("Send",ON_CLICK);Check(sent_requests.size()==before,"invalid live risk input blocks sending");
 controls["manualFibo.Panel.Risk"]->Text("2");controls["manualFibo.Panel.SL2"]->Text("90");Action("Send",ON_CLICK);
 Check(sent_requests.size()==before+3&&sent_requests[before].sl==90,"live custom SL is captured without end-edit event");
 Action("Delete",ON_CLICK);
 // A different chart sharing account/symbol/magic cannot race an in-flight batch.
 reset();orders.Configure(11600101);string lock_key=terminal_globals.empty()?"":terminal_globals.begin()->first;
 orders.Send(model,swing_tp);for(auto &entry:terminal_globals)if(entry.first.find("Lock")!=string::npos)lock_key=entry.first;
 terminal_globals[lock_key]=1;before=sent_requests.size();orders.Delete();Check(sent_requests.size()==before,"busy terminal mutex blocks a competing command");terminal_globals[lock_key]=0;
 reset();check_fail_at=5;orders.Send(model,swing_tp);Check(sent_requests.size()==2&&broker_orders.size()==2,"per-request recheck can fail safely after preflight");
 reset();orders.Send(model,swing_tp);broker_history=broker_orders;broker_orders.clear();terminal_globals.clear();before=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==before,"filled history blocks repeat even without terminal records");
 // A free existing mutex must not be recreated; creation races are harmless.
 reset();orders.Configure(11600101);int creations=temp_create_calls;orders.Send(model,swing_tp);
 Check(temp_create_calls==creations+1,"first operation creates its temporary mutex once");
 creations=temp_create_calls;orders.Delete();Check(temp_create_calls==creations&&broker_orders.empty(),"subsequent action reuses free existing mutex even when Temp(existing) returns false");
 CManualFiboOrders same_scope;same_scope.Configure(11600101);creations=temp_create_calls;same_scope.Delete();Check(temp_create_calls==creations,"second chart reuses existing mutex");
 reset();orders.Configure(11600101);temp_create_failure=true;string lock_error=orders.Send(model,swing_tp);Check(sent_requests.empty()&&lock_error.find("Gagal membuat lock")!=string::npos,"creation API failure differs from busy lock");temp_create_failure=false;
 reset();orders.Configure(11600101);create_race=true;orders.Send(model,swing_tp);Check(sent_requests.size()==3,"a chart racing to create the lock does not block acquisition");
 reset();orders.Configure(11600101);mutex_cas_failure=true;lock_error=orders.Send(model,swing_tp);Check(sent_requests.empty()&&lock_error.find("Gagal mengambil lock")!=string::npos,"acquisition API failure with free lock differs from busy lock");mutex_cas_failure=false;
 for(auto &entry:terminal_globals)if(entry.first.find("Lock")!=string::npos)entry.second=1;
 lock_error=orders.Send(model,swing_tp);Check(sent_requests.empty()&&lock_error.find("masih aktif")!=string::npos,"held mutex remains blocked without reset");
 // Confirmed no-fill cancellation opens a fresh attempt and frees All reservations.
 reset();orders.Configure(11600101);model.SetRiskAll(true);model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskPercent(5);model.SetBalanceRisk(true);
 for(int cycle=0;cycle<3;cycle++){
  size_t start=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==start+3&&broker_orders.size()==3,"All send/delete/send cycles can reuse the same anchors");
  double sum=0;for(auto&o:broker_orders){double profit=0;OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,o.request.volume,o.request.price,o.request.sl,profit);sum-=profit;}
  Check(sum>0&&sum<=500,"All cancelled reservations do not accumulate across cycles");orders.Delete();Check(broker_orders.empty(),"cycle deletes pending entries");
 }
 Check(broker_history.front().request.comment!=broker_history.back().request.comment,"rearmed attempts use distinct comments");
 // A rejected deletion cannot rearm its level, but other confirmed levels may retry.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);orders.Delete();Check(broker_orders.size()==1,"failed delete stays active");size_t change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change+2&&broker_orders.size()==3,"only successfully cancelled levels rearm");
 double held_total=0;for(auto&o:broker_orders){double profit=0;OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,o.request.volume,o.request.price,o.request.sl,profit);held_total-=profit;}Check(held_total<=500,"All retains risk of failed deletion while reusing freed shares");
 // Partial fill, even if its remaining pending volume is cancelled, stays protected.
 reset();orders.Configure(11600101);model.SetMask(1<<2);orders.Send(model,swing_tp);broker_orders[0].remaining=broker_orders[0].request.volume/2;broker_orders[0].position=987;orders.Delete();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"partial fill cancellation cannot reopen level");
 reset();orders.Configure(11600101);orders.Send(model,swing_tp);auto filled=broker_orders[0];filled.state=ORDER_STATE_FILLED;filled.remaining=0;filled.position=988;broker_history.push_back(filled);broker_orders.clear();orders.Delete();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"filled position cannot be resent or closed by Delete");
 // Timeout cancellation persists through reattach and resolves only from exact history.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_TIMEOUT};orders.Send(model,swing_tp);orders.Delete();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"uncertain active deletion blocks resend");
 auto cancelled=broker_orders[0];cancelled.state=ORDER_STATE_CANCELED;broker_history.push_back(cancelled);broker_orders.clear();CManualFiboOrders cancellation_recovery;cancellation_recovery.Configure(11600101);Check(cancellation_recovery.Reconcile().find("1 siap dikirim ulang")!=string::npos,"restart recovers a late confirmed deletion");cancellation_recovery.Send(model,swing_tp);Check(sent_requests.size()==change+1,"recovered cancellation permits explicit new send");
 // Successful removal acknowledgement without accessible history is insufficient.
 reset();orders.Configure(11600101);orders.Send(model,swing_tp);history_allowed=false;orders.Delete();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"missing cancellation history fails closed");history_allowed=true;orders.Send(model,swing_tp);Check(sent_requests.size()==change+1,"exact cancelled history permits send when it becomes available");
 // Old cancelled history must not resolve a newer timed-out attempt with the same anchors.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_DONE,TRADE_RETCODE_TIMEOUT};orders.Send(model,swing_tp);orders.Delete();orders.Send(model,swing_tp);change=sent_requests.size();orders.Reconcile();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"old attempt cancellation cannot confirm a newer unknown submission");
 // Counter persistence failure cannot free risk or allow a new attempt.
 reset();orders.Configure(11600101);orders.Send(model,swing_tp);generation_failure=true;orders.Delete();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change,"generation write failure blocks rearming");generation_failure=false;orders.Send(model,swing_tp);Check(sent_requests.size()==change+1,"generation write recovery completes cancellation proof");
 // Fixed Balance basis: floating equity changes never alter manual risk.
 reset();model.SetBalanceRisk(true);model.SetRiskAll(false);balance=8000;equity=16000;CFiboRisk balance_calc;FiboRiskContext balance_ctx;balance_calc.ReadContext(model,balance_ctx);Check(balance_ctx.total_budget==400&&balance_ctx.budget==400,"manual per-level risk uses balance rather than equity");equity=1;balance_calc.ReadContext(model,balance_ctx);Check(balance_ctx.total_budget==400,"floating equity does not change balance budget");model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskAll(true);balance_calc.ReadContext(model,balance_ctx);Check(balance_ctx.total_budget==400&&std::abs(balance_ctx.budget-400./3)<1e-10,"All divides a balance-based budget");
 model.SetBalanceRisk(false);
 // Risk modes use one equity snapshot and fixed equal shares before broker rounding.
 reset();model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskPercent(5);model.SetRiskAll(true);
 CFiboRisk calc;FiboRiskContext ctx;calc.ReadContext(model,ctx);Check(ctx.total_budget==500&&std::abs(ctx.budget-500./3)<1e-10,"All equal shares from one total budget");
 double total_loss=0;for(int i=0;i<FIBO_RATIOS;i++){if(!model.Enabled(i))continue;FiboLot lot;Check(calc.Calculate(model,i,ctx,lot),"All preview valid");total_loss+=lot.loss;}
 Check(total_loss>0&&total_loss<=500,"All preview aggregate never exceeds budget");
 model.SetRiskAll(false);calc.ReadContext(model,ctx);Check(ctx.budget==500,"Per level keeps full budget per selected entry");
 model.SetRiskAll(true);orders.Configure(11600101);orders.Send(model,swing_tp);
 auto loss_of=[](const MqlTradeRequest&r){double loss=0;Check(OrderCalcProfit(r.type==ORDER_TYPE_BUY_LIMIT?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,r.volume,r.price,r.sl,loss),"estimate submitted loss");return -loss;};
 total_loss=0;for(auto&r:sent_requests)total_loss+=loss_of(r);Check(sent_requests.size()==3&&total_loss<=500,"All submitted batch matches total cap");
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);
 model.SetMask(1<<3);orders.Send(model,swing_tp);total_loss=0;for(auto&o:broker_orders)total_loss+=loss_of(o.request);
 Check(broker_orders.size()==3&&total_loss<=500,"All retry cannot redistribute spent budget after selection changes");
 reset();orders.Configure(11600101);model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskAll(false);orders.Send(model,swing_tp);model.SetRiskAll(true);model.SetMask(63);size_t prior=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"switching to All cannot ignore prior per-level risk");
 reset();orders.Configure(11600101);model.SetMask(63);model.SetRiskPercent(.01);orders.Send(model,swing_tp);Check(sent_requests.empty(),"All refuses minimum lot overshoot");
 model.SetRiskPercent(5);model.SetMask(FIBO_DEFAULT_MASK);
 // Event handler is cheap; only matched definitive responses may unlock a timeout.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);
 MqlTradeRequest unresolved=sent_requests[0];MqlTradeTransaction tx={};tx.type=TRADE_TRANSACTION_REQUEST;
 MqlTradeResult response={};response.retcode=TRADE_RETCODE_REJECT;response.request_id=999;
 int scans_before=history_scans,reads_before=active_reads;orders.Transaction(tx,unresolved,response);Check(history_scans==scans_before&&active_reads==reads_before,"transaction callback performs no broker scans");
 orders.Reconcile();prior=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"mismatched request ID cannot unlock a timeout");
 response.request_id=1;response.retcode=TRADE_RETCODE_CONNECTION;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"connection result is not proof of rejection");
 response.retcode=TRADE_RETCODE_ERROR;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"processing error stays uncertain");
 response.retcode=TRADE_RETCODE_LOCKED;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"locked request stays uncertain");
 response.retcode=TRADE_RETCODE_REJECT;orders.Transaction(tx,unresolved,response);clock_value+=6000;Check(orders.Reconcile().find("1 ditolak")!=string::npos,"matched rejection reconciles without new order");orders.Send(model,swing_tp);Check(sent_requests.size()==prior+1,"only proven rejected level is eligible for user retry");
 // Missing orders/history must never release an intent. Idle polling backs off.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);orders.Reconcile();scans_before=history_scans;for(int i=0;i<20;i++)orders.Reconcile();Check(history_scans==scans_before,"backoff prevents scans on every timer call");
 prior=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"absence is not failure proof");
 // On reattach, restore an unknown record then discover a late accepted order.
 unresolved=sent_requests[0];broker_orders.push_back({900,unresolved,0});CManualFiboOrders recovered;recovered.Configure(11600101);Check(recovered.Reconcile().find("1 diterima")!=string::npos,"startup reconciles late active order by identity");scans_before=history_scans;recovered.Reconcile();Check(history_scans==scans_before,"resolved state stops reconciliation scans");recovered.Send(model,swing_tp);Check(sent_requests.size()==prior,"recovered accepted order stays protected");
 // Non-request transactions do not read their undefined request/result fields.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,swing_tp);unresolved=sent_requests[0];tx.type=TRADE_TRANSACTION_ORDER_ADD;tx.symbol=_Symbol;response.retcode=TRADE_RETCODE_REJECT;response.request_id=1;orders.Transaction(tx,unresolved,response);orders.Reconcile();prior=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==prior,"non-request result garbage cannot release an intent");
 broker_history.push_back({901,unresolved,0});tx.type=TRADE_TRANSACTION_HISTORY_ADD;orders.Transaction(tx,unresolved,response);clock_value+=6000;Check(orders.Reconcile().find("1 diterima")!=string::npos,"late history fill or cancellation reconciles acceptance");
 // Known ticket probes preserve all 64 bits and avoid a history range scan.
 reset();CManualFiboReconcile ledger;ledger.Configure("MF.test.",11600101);string note=orders.Comment(model,2);Check(ledger.Begin(note,100),"write durable intent");response={};response.retcode=TRADE_RETCODE_TIMEOUT;response.order=(1UL<<54)+37;response.request_id=123;ledger.Finish(note,response);broker_orders.push_back({response.order,unresolved,0});ledger.Configure("MF.test.",11600101);scans_before=history_scans;Check(ledger.Poll().find("1 diterima")!=string::npos&&history_scans==scans_before,"persisted 64-bit ticket resolves without history scan");
 // Definite rejection needs the exact known ticket, not an old rejected comment.
 reset();ledger.Configure("MF.test.",11600101);Check(ledger.Begin(note,100),"create historical rejection case");response={};response.retcode=TRADE_RETCODE_TIMEOUT;response.order=1001;response.request_id=124;ledger.Finish(note,response);
 broker_history.push_back({1000,unresolved,ORDER_STATE_REJECTED});ledger.Poll();Check(GlobalVariableCheck("MF.test."+note),"old rejected attempt cannot release a new unknown");broker_history.push_back({1001,unresolved,ORDER_STATE_REJECTED});clock_value+=6000;Check(ledger.Poll().find("1 ditolak")!=string::npos&&!GlobalVariableCheck("MF.test."+note),"exact historical rejected ticket releases reservation");
 // Reconnect forces a new read, never a new send, and missing history stays blocked.
 reset();ledger.Configure("MF.test.",11600101);Check(ledger.Begin(note,100),"create reconnect case");response={};response.retcode=TRADE_RETCODE_TIMEOUT;ledger.Finish(note,response);ledger.Poll();prior=sent_requests.size();trading_allowed=false;ledger.Poll();trading_allowed=true;scans_before=history_scans;history_allowed=false;ledger.Poll();Check(history_scans>scans_before&&GlobalVariableCheck("MF.test."+note)&&sent_requests.size()==prior,"reconnect with missing history never resends or unlocks");history_allowed=true;
 // Polling limits hold even for a large account order list.
 for(int i=0;i<400;i++){auto other=unresolved;other.comment="unrelated";broker_orders.push_back({static_cast<ulong>(2000+i),other,0});broker_history.push_back({static_cast<ulong>(3000+i),other,0});}
 clock_value+=6000;reads_before=active_reads;ledger.Poll();Check(active_reads-reads_before<=128,"fallback active-order scan is bounded per pass");
 // Current schema saves All and rejects malformed modes; legacy schemas stay Per level.
 CFiboState codec;codec.SetPrefix("ModeTest.");CFiboModel restored;model.SetRiskAll(true);Check(codec.Save(model,_Symbol)&&codec.Load(restored,_Symbol)&&restored.RiskAll(),"schema 5 risk-mode roundtrip");
 string encoded=ObjectGetString(0,"ModeTest.State",OBJPROP_TEXT);ObjectSetString(0,"ModeTest.State",OBJPROP_TEXT,StringSubstr(encoded,0,StringLen(encoded)-1)+"2");Check(!codec.Load(restored,_Symbol)&&restored.RiskAll(),"invalid mode rejected without mutating model");
 ObjectSetString(0,"ModeTest.State",OBJPROP_TEXT,"4"+StringSubstr(encoded,1,StringLen(encoded)-3));Check(codec.Load(restored,_Symbol)&&!restored.RiskAll(),"schema 4 migration defaults Per level");ObjectDelete(0,"ModeTest.State");
 // Reproduce native zero-value substitution that the old fake missed.
 CComboBox native_values;native_values.AddItem("All",1);native_values.AddItem("Per level",0);
 Check(!native_values.SelectByValue(0),"zero-valued second item becomes its index, reproducing old startup failure");
 // Old saved-ticket cancellations (from 1.19) recover on Send without clearing globals.
 reset();orders.Configure(11600101);model.SetRiskAll(true);model.SetBalanceRisk(true);model.SetMask(FIBO_DEFAULT_MASK);orders.Send(model,swing_tp);for(auto&o:broker_orders){o.state=ORDER_STATE_CANCELED;broker_history.push_back(o);}broker_orders.clear();change=sent_requests.size();orders.Send(model,swing_tp);Check(sent_requests.size()==change+3,"pre-update full cancellations recover from saved exact tickets");
 // Risk basis is fixed EA configuration, preserved by loading rather than a user field.
 CFiboModel balance_model;balance_model.SetBalanceRisk(true);balance_model.SetAnchors(100,100,200,200);CFiboState basis_state;basis_state.SetPrefix("BasisTest.");Check(basis_state.Save(balance_model,_Symbol),"save fixed basis fixture");CFiboModel basis_loaded;basis_loaded.SetBalanceRisk(true);Check(basis_state.Load(basis_loaded,_Symbol)&&basis_loaded.BalanceRisk(),"snapshot loading preserves fixed manual Balance configuration");ObjectDelete(0,"BasisTest.State");
 // GUI mode selection and compact amount layout, with timeframe persistence.
 reset();Check(OnInit()==INIT_SUCCEEDED,"restart GUI for risk modes");Check(g_model.BalanceRisk(),"manual OnInit fixes Balance basis after prior equity models");Check(!g_dialog.RiskAll(),"positive unique IDs retain Per level startup default");g_model.CopyFrom(model);g_model.SetBalanceRisk(true);g_model.SetRiskAll(false);g_dialog.SyncRiskMode(g_model);g_chart.Draw(g_model);g_dialog.Refresh(g_model);
 auto*mode=static_cast<CComboBox*>(controls["manualFibo.Panel.RiskMode"]);mode->SelectByValue(MANUAL_RISK_ALL);Action("RiskMode",ON_CHANGE);Check(g_model.RiskAll(),"All selector commits to model");
 Check(controls["manualFibo.Panel.Budget"]->text=="500.00","compact amount has no Budget label or currency text");
 auto*risk_input=controls["manualFibo.Panel.Risk"];auto*amount=controls["manualFibo.Panel.Budget"];Check(risk_input->m_rect.right-risk_input->m_rect.left==56&&risk_input->m_rect.right<amount->m_rect.left,"smaller risk field beside amount");
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&g_model.RiskAll()&&g_dialog.RiskAll(),"risk mode survives timeframe handoff");
 mode->SelectByValue(MANUAL_RISK_PER_LEVEL);Action("RiskMode",ON_CHANGE);Check(!g_model.RiskAll(),"Per level selector retains prior behavior");
 // Three TP modes: settings validation, tick-normalized BUY/SELL RR and persistence.
 CManualFiboSettings rr_tp;Check(rr_tp.TPMode()==MANUAL_TP_SWING&&rr_tp.RR()==2,"TP settings default swing end and RR 2");
 Check(!rr_tp.SetTPMode((ManualFiboTPMode)0)&&!rr_tp.SetRR(0)&&!rr_tp.SetRR(-1)&&!rr_tp.SetRR(EMPTY_VALUE)&&!rr_tp.SetRR(.000000001)&&rr_tp.RR()==2,"invalid mode or RR leaves settings unchanged");
 rr_tp.SetTPMode(MANUAL_TP_RR);rr_tp.SetRR(2.5);Check(rr_tp.Save(),"save TP/RR settings");CManualFiboSettings loaded_tp;Check(loaded_tp.Load()&&loaded_tp.TPMode()==MANUAL_TP_RR&&loaded_tp.RR()==2.5,"TP/RR schema roundtrip");
 ObjectSetString(0,"manualFibo.TradeOptions",OBJPROP_TEXT,"0");Check(loaded_tp.Load()&&loaded_tp.TPMode()==MANUAL_TP_NONE&&loaded_tp.RR()==2,"legacy TP off migration");ObjectSetString(0,"manualFibo.TradeOptions",OBJPROP_TEXT,"1");Check(loaded_tp.Load()&&loaded_tp.TPMode()==MANUAL_TP_SWING,"legacy TP on migration");ObjectSetString(0,"manualFibo.TradeOptions",OBJPROP_TEXT,"2|3|bad");Check(!loaded_tp.Load()&&loaded_tp.TPMode()==MANUAL_TP_SWING,"malformed settings do not mutate previous choice");loaded_tp.Consume();
 reset();orders.Configure(11600101);model.SetAnchors(100,100,200,200);model.SetMask(1<<2);model.SetBalanceRisk(true);rr_tp.SetRR(2);orders.Send(model,rr_tp);Check(broker_orders.size()==1&&broker_orders[0].request.price==150&&broker_orders[0].request.sl==100&&broker_orders[0].request.tp==250,"BUY LIMIT RR 2 target");
 reset();orders.Configure(11600101);bid=50;ask=51;model.SetAnchors(100,200,200,100);orders.Send(model,rr_tp);Check(broker_orders.size()==1&&broker_orders[0].request.tp==50&&broker_orders[0].request.type==ORDER_TYPE_SELL_LIMIT,"SELL LIMIT RR 2 target");
 reset();orders.Configure(11600101);model.SetAnchors(100,100,200,200);model.SetMask(FIBO_DEFAULT_MASK);model.SetStop(3,110);orders.Send(model,rr_tp);Check(broker_orders.size()==3,"RR supports per-level custom SL");for(auto&o:broker_orders){double expected=NormalizeDouble(MathRound((o.request.price+2*(o.request.price-o.request.sl))/tick_size)*tick_size,_Digits);Check(std::abs(o.request.tp-expected)<1e-8,"each RR target uses that level's entry and SL");}model.ResetStop(3);
 reset();orders.Configure(11600101);model.SetMask(1<<2);tick_size=.25;model.SetAnchors(100,100.1,200,200.2);rr_tp.SetRR(1.3);orders.Send(model,rr_tp);Check(broker_orders.size()==1&&broker_orders[0].request.tp==215.5,"RR uses normalized entry/SL before rounding TP to tick");
 reset();orders.Configure(11600101);model.SetAnchors(100,100,200,200);rr_tp.SetRR(.01);stops_level=100;orders.Send(model,rr_tp);Check(sent_requests.empty(),"TP below broker minimum blocks preflight");
 reset();orders.Configure(11600101);model.SetAnchors(100,200,200,100);bid=50;ask=51;rr_tp.SetRR(5);orders.Send(model,rr_tp);Check(sent_requests.empty(),"nonpositive SELL RR target blocks preflight");
 // GUI mode visibility, uncommitted input capture, editing isolation and TF handoff.
 reset();OnDeinit(0);Check(OnInit()==INIT_SUCCEEDED,"fresh GUI for TP modes");Check(g_dialog.TPMode()==MANUAL_TP_SWING&&g_settings.RR()==2&&!controls["manualFibo.Panel.RR"]->visible,"fresh attach defaults and hidden RR input");
 model.SetAnchors(100,100,200,200);model.SetMask(1<<2);g_model.CopyFrom(model);g_model.SetBalanceRisk(true);g_dialog.Refresh(g_model);g_chart.Draw(g_model);
 auto*tp_choice=static_cast<CComboBox*>(controls["manualFibo.Panel.TPMode"]);tp_choice->SelectByValue(MANUAL_TP_RR);Action("TPMode",ON_CHANGE);Check(g_settings.TPMode()==MANUAL_TP_RR&&controls["manualFibo.Panel.RR"]->visible&&controls["manualFibo.Panel.RRLabel"]->visible,"RR mode shows its input and label");
 Edit("RR","3");controls["manualFibo.Panel.RR"]->Text("2.5");OnTimer();Check(controls["manualFibo.Panel.RR"]->text=="2.5"&&g_settings.RR()==3,"timer preserves RR draft");Action("Send",ON_CLICK);Check(broker_orders.size()==1&&broker_orders[0].request.tp==275&&g_settings.RR()==2.5,"send captures RR before end-edit event");
 change=sent_requests.size();Edit("RR","3");Action("Send",ON_CLICK);Check(sent_requests.size()==change&&broker_orders[0].request.tp==275,"RR edit does not duplicate or modify existing orders");
 Action("Delete",ON_CLICK);Edit("RR","1.5");Action("Send",ON_CLICK);Check(broker_orders.size()==1&&broker_orders[0].request.tp==225,"rearmed level uses newly selected RR");Action("Delete",ON_CLICK);change=sent_requests.size();controls["manualFibo.Panel.RR"]->Text("0");Action("Send",ON_CLICK);Check(sent_requests.size()==change,"invalid live RR prevents order sending");Edit("RR","bad");Check(controls["manualFibo.Panel.RR"]->text=="1.5"&&g_settings.RR()==1.5,"invalid committed RR restores last valid value");
 tp_choice->SelectByValue(MANUAL_TP_NONE);Action("TPMode",ON_CHANGE);Check(!controls["manualFibo.Panel.RR"]->visible,"no-TP mode hides RR");OnChartEvent(TEST_MINIMIZE,0,0,"");OnChartEvent(TEST_RESTORE,0,0,"");Check(!controls["manualFibo.Panel.RR"]->visible&&!controls["manualFibo.Panel.RRLabel"]->visible,"native restore keeps RR hidden outside RR mode");
 tp_choice->SelectByValue(MANUAL_TP_RR);Action("TPMode",ON_CHANGE);controls["manualFibo.Panel.RR"]->Text("4.25");OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&g_dialog.TPMode()==MANUAL_TP_RR&&g_settings.RR()==4.25&&controls["manualFibo.Panel.RR"]->visible,"timeframe handoff captures valid RR draft and mode");
 OnChartEvent(TEST_MINIMIZE,0,0,"");OnChartEvent(TEST_RESTORE,0,0,"");Check(controls["manualFibo.Panel.RR"]->visible,"RR stays visible when its mode is restored");
 OnDeinit(0);
 std::cout<<"PASS: TP modes, normalized RR targets, settings migration, GUI drafts/visibility and timeframe persistence.\n";
 std::cout<<"PASS: All/Per level budgets, retry risk reservations, event reconciliation and bounded polling.\n";
 std::cout<<"PASS: manualFibo batch limit execution, preflight, TP, duplicate/retry ledger, scoped deletion and GUI actions.\n";
}
'''
