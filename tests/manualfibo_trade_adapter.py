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
struct MqlTradeResult{uint request_id=0,retcode=0;ulong order=0;string comment;};
const uint TRADE_RETCODE_REQUOTE=10004,TRADE_RETCODE_CANCEL=10007,TRADE_RETCODE_INVALID=10013,
 TRADE_RETCODE_INVALID_EXPIRATION=10022,TRADE_RETCODE_TOO_MANY_REQUESTS=10024,
 TRADE_RETCODE_SERVER_DISABLES_AT=10026,TRADE_RETCODE_CLIENT_DISABLES_AT=10027,
 TRADE_RETCODE_FROZEN=10029,TRADE_RETCODE_INVALID_FILL=10030,TRADE_RETCODE_ONLY_REAL=10032,TRADE_RETCODE_LIMIT_POSITIONS=10040;
const int TRADE_TRANSACTION_REQUEST=70,TRADE_TRANSACTION_ORDER_ADD=71,TRADE_TRANSACTION_HISTORY_ADD=72;
struct MqlTradeTransaction{int type=0;ulong order=0;string symbol;};
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
int history_scans=0,active_reads=0,ticket_probes=0;
long AccountInfoInteger(int prop){return prop==ACCOUNT_LOGIN?12345:trading_allowed;}
long TerminalInfoInteger(int){return trading_allowed;}
long MQLInfoInteger(int){return trading_allowed;}
datetime TimeCurrent(){return 1800000000;}
int GlobalVariablesTotal(){return terminal_globals.size();}
string GlobalVariableName(int index){auto it=terminal_globals.begin();std::advance(it,index);return it->first;}
double GlobalVariableGet(const string&key){return terminal_globals.count(key)?terminal_globals[key]:0;}
bool GlobalVariableTemp(const string&key){terminal_globals.emplace(key,0);return true;}
bool GlobalVariableSetOnCondition(const string&key,double v,double previous){if(!terminal_globals.count(key)||terminal_globals[key]!=previous)return false;terminal_globals[key]=v;return true;}
datetime GlobalVariableSet(const string&key,double v){if(marker_failure&&key.find("MF:")!=string::npos)return 0;terminal_globals[key]=v;return 1800000000;}
bool GlobalVariableCheck(const string&key){return terminal_globals.count(key);}
bool GlobalVariableDel(const string&key){return terminal_globals.erase(key)>0;}
void GlobalVariablesFlush(){}
int OrdersTotal(){return broker_orders.size();}
bool OrderSelect(ulong ticket){++ticket_probes;for(size_t i=0;i<broker_orders.size();i++)if(broker_orders[i].ticket==ticket){order_selected=i;return true;}return false;}
ulong OrderGetTicket(int i){++active_reads;order_selected=i;return broker_orders.at(i).ticket;}
long OrderGetInteger(int prop){auto&o=broker_orders.at(order_selected);if(prop==ORDER_MAGIC)return o.request.magic;if(prop==ORDER_TYPE)return o.request.type;return o.state;}
string OrderGetString(int prop){auto&o=broker_orders.at(order_selected);return prop==ORDER_SYMBOL?o.request.symbol:o.request.comment;}
bool HistorySelect(datetime,datetime){++history_scans;return history_allowed;}
bool HistoryOrderSelect(ulong ticket){++ticket_probes;if(!history_allowed)return false;for(auto&o:broker_history)if(o.ticket==ticket)return true;return false;}
int HistoryOrdersTotal(){return broker_history.size();}
ulong HistoryOrderGetTicket(int i){return broker_history.at(i).ticket;}
FakeOrder&HistoryFind(ulong ticket){for(auto&o:broker_history)if(o.ticket==ticket)return o;std::abort();}
long HistoryOrderGetInteger(ulong ticket,int prop){auto&o=HistoryFind(ticket);if(prop==ORDER_MAGIC)return static_cast<long>(o.request.magic);if(prop==ORDER_TYPE)return o.request.type;return o.state;}
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
 // Risk modes use one equity snapshot and fixed equal shares before broker rounding.
 reset();model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskPercent(5);model.SetRiskAll(true);
 CFiboRisk calc;FiboRiskContext ctx;calc.ReadContext(model,ctx);Check(ctx.total_budget==500&&std::abs(ctx.budget-500./3)<1e-10,"All equal shares from one total budget");
 double total_loss=0;for(int i=0;i<FIBO_RATIOS;i++){if(!model.Enabled(i))continue;FiboLot lot;Check(calc.Calculate(model,i,ctx,lot),"All preview valid");total_loss+=lot.loss;}
 Check(total_loss>0&&total_loss<=500,"All preview aggregate never exceeds budget");
 model.SetRiskAll(false);calc.ReadContext(model,ctx);Check(ctx.budget==500,"Per level keeps full budget per selected entry");
 model.SetRiskAll(true);orders.Configure(11600101);orders.Send(model,true);
 auto loss_of=[](const MqlTradeRequest&r){double loss=0;Check(OrderCalcProfit(r.type==ORDER_TYPE_BUY_LIMIT?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,r.volume,r.price,r.sl,loss),"estimate submitted loss");return -loss;};
 total_loss=0;for(auto&r:sent_requests)total_loss+=loss_of(r);Check(sent_requests.size()==3&&total_loss<=500,"All submitted batch matches total cap");
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_DONE,TRADE_RETCODE_REJECT,TRADE_RETCODE_DONE};orders.Send(model,true);
 model.SetMask(1<<3);orders.Send(model,true);total_loss=0;for(auto&o:broker_orders)total_loss+=loss_of(o.request);
 Check(broker_orders.size()==3&&total_loss<=500,"All retry cannot redistribute spent budget after selection changes");
 reset();orders.Configure(11600101);model.SetMask(FIBO_DEFAULT_MASK);model.SetRiskAll(false);orders.Send(model,true);model.SetRiskAll(true);model.SetMask(63);size_t prior=sent_requests.size();orders.Send(model,true);Check(sent_requests.size()==prior,"switching to All cannot ignore prior per-level risk");
 reset();orders.Configure(11600101);model.SetMask(63);model.SetRiskPercent(.01);orders.Send(model,true);Check(sent_requests.empty(),"All refuses minimum lot overshoot");
 model.SetRiskPercent(5);model.SetMask(FIBO_DEFAULT_MASK);
 // Event handler is cheap; only matched definitive responses may unlock a timeout.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,true);
 MqlTradeRequest unresolved=sent_requests[0];MqlTradeTransaction tx={};tx.type=TRADE_TRANSACTION_REQUEST;
 MqlTradeResult response={};response.retcode=TRADE_RETCODE_REJECT;response.request_id=999;
 int scans_before=history_scans,reads_before=active_reads;orders.Transaction(tx,unresolved,response);Check(history_scans==scans_before&&active_reads==reads_before,"transaction callback performs no broker scans");
 orders.Reconcile();prior=sent_requests.size();orders.Send(model,true);Check(sent_requests.size()==prior,"mismatched request ID cannot unlock a timeout");
 response.request_id=1;response.retcode=TRADE_RETCODE_CONNECTION;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,true);Check(sent_requests.size()==prior,"connection result is not proof of rejection");
 response.retcode=TRADE_RETCODE_ERROR;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,true);Check(sent_requests.size()==prior,"processing error stays uncertain");
 response.retcode=TRADE_RETCODE_LOCKED;orders.Transaction(tx,unresolved,response);clock_value+=6000;orders.Reconcile();orders.Send(model,true);Check(sent_requests.size()==prior,"locked request stays uncertain");
 response.retcode=TRADE_RETCODE_REJECT;orders.Transaction(tx,unresolved,response);clock_value+=6000;Check(orders.Reconcile().find("1 ditolak")!=string::npos,"matched rejection reconciles without new order");orders.Send(model,true);Check(sent_requests.size()==prior+1,"only proven rejected level is eligible for user retry");
 // Missing orders/history must never release an intent. Idle polling backs off.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,true);orders.Reconcile();scans_before=history_scans;for(int i=0;i<20;i++)orders.Reconcile();Check(history_scans==scans_before,"backoff prevents scans on every timer call");
 prior=sent_requests.size();orders.Send(model,true);Check(sent_requests.size()==prior,"absence is not failure proof");
 // On reattach, restore an unknown record then discover a late accepted order.
 unresolved=sent_requests[0];broker_orders.push_back({900,unresolved,0});CManualFiboOrders recovered;recovered.Configure(11600101);Check(recovered.Reconcile().find("1 diterima")!=string::npos,"startup reconciles late active order by identity");scans_before=history_scans;recovered.Reconcile();Check(history_scans==scans_before,"resolved state stops reconciliation scans");recovered.Send(model,true);Check(sent_requests.size()==prior,"recovered accepted order stays protected");
 // Non-request transactions do not read their undefined request/result fields.
 reset();orders.Configure(11600101);send_codes={TRADE_RETCODE_TIMEOUT,TRADE_RETCODE_DONE,TRADE_RETCODE_DONE};orders.Send(model,true);unresolved=sent_requests[0];tx.type=TRADE_TRANSACTION_ORDER_ADD;tx.symbol=_Symbol;response.retcode=TRADE_RETCODE_REJECT;response.request_id=1;orders.Transaction(tx,unresolved,response);orders.Reconcile();prior=sent_requests.size();orders.Send(model,true);Check(sent_requests.size()==prior,"non-request result garbage cannot release an intent");
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
 // GUI mode selection and compact amount layout, with timeframe persistence.
 reset();Check(OnInit()==INIT_SUCCEEDED,"restart GUI for risk modes");g_model.CopyFrom(model);g_model.SetRiskAll(false);g_dialog.SyncRiskMode(g_model);g_chart.Draw(g_model);g_dialog.Refresh(g_model);
 auto*mode=static_cast<CComboBox*>(controls["manualFibo.Panel.RiskMode"]);mode->SelectByValue(1);Action("RiskMode",ON_CHANGE);Check(g_model.RiskAll(),"All selector commits to model");
 Check(controls["manualFibo.Panel.Budget"]->text=="500.00","compact amount has no Budget label or currency text");
 auto*risk_input=controls["manualFibo.Panel.Risk"];auto*amount=controls["manualFibo.Panel.Budget"];Check(risk_input->m_rect.right-risk_input->m_rect.left==56&&risk_input->m_rect.right<amount->m_rect.left,"smaller risk field beside amount");
 OnDeinit(REASON_CHARTCHANGE);Check(OnInit()==INIT_SUCCEEDED&&g_model.RiskAll()&&g_dialog.RiskAll(),"risk mode survives timeframe handoff");
 mode->SelectByValue(0);Action("RiskMode",ON_CHANGE);Check(!g_model.RiskAll(),"Per level selector retains prior behavior");
 OnDeinit(0);
 std::cout<<"PASS: All/Per level budgets, retry risk reservations, event reconciliation and bounded polling.\n";
 std::cout<<"PASS: manualFibo batch limit execution, preflight, TP, duplicate/retry ledger, scoped deletion and GUI actions.\n";
}
'''
