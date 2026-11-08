#ifndef MANUAL_FIBO_ORDERS_MQH
#define MANUAL_FIBO_ORDERS_MQH
#include <_common\Fibo\FiboRisk.mqh>
#include "ManualFiboReconcile.mqh"

// Execution is private to manualFibo; the shared model/calculator never trades.
class CManualFiboOrders
{
private:
   CManualFiboReconcile m_reconcile;
   ulong m_magic;
   string m_scope, m_mutex;
   string Hex(uint value) const
   {
      string out = "", digits = "0123456789ABCDEF";
      for(int i = 0; i < 8; i++)
      { out = StringSubstr(digits, (int)(value & 15), 1) + out; value >>= 4; }
      return out;
   }
   string Hash(const string text) const
   {
      uint a = 2166136261, b = 5381;
      for(int i = 0; i < StringLen(text); i++)
      { uint ch = StringGetCharacter(text, i); a = (a ^ ch) * 16777619; b = b * 33 + ch; }
      return Hex(a) + Hex(b);
   }
   bool Acquire(void)
   {
      return GlobalVariableTemp(m_mutex) && GlobalVariableSetOnCondition(m_mutex, 1, 0);
   }
   void Release(void) { GlobalVariableSet(m_mutex, 0); }
   bool Owned(void) const
   {
      return (ulong)OrderGetInteger(ORDER_MAGIC) == m_magic
             && OrderGetString(ORDER_SYMBOL) == _Symbol
             && StringSubstr(OrderGetString(ORDER_COMMENT), 0, 3) == "MF:";
   }
   // History protects filled/cancelled orders too. A rejected order may be retried.
   bool AlreadySent(const string comment) const
   {
      if(GlobalVariableCheck(m_scope + comment)) return true;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
         if(OrderGetTicket(i) != 0 && Owned() && OrderGetString(ORDER_COMMENT) == comment) return true;
      for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = HistoryOrderGetTicket(i);
         if(ticket != 0 && (ulong)HistoryOrderGetInteger(ticket, ORDER_MAGIC) == m_magic
            && HistoryOrderGetString(ticket, ORDER_SYMBOL) == _Symbol
            && HistoryOrderGetString(ticket, ORDER_COMMENT) == comment
            && HistoryOrderGetInteger(ticket, ORDER_STATE) != ORDER_STATE_REJECTED) return true;
      }
      return false;
   }
   bool Permissions(void) const
   {
      return TerminalInfoInteger(TERMINAL_CONNECTED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)
             && MQLInfoInteger(MQL_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)
             && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   }
   string Level(const int index) const { return DoubleToString(FiboRatio(index) * 100, 1) + "%"; }
   bool Prepare(const CFiboModel &model, const bool use_tp, const int index,
                const FiboRiskContext &context, MqlTradeRequest &request, double &loss, string &error) const
   {
      CFiboRisk risk; FiboLot lot;
      if(!risk.Calculate(model, index, context, lot)) { error = lot.error; return false; }
      bool buy = lot.kind == FIBO_LIMIT_BUY;
      request.action = TRADE_ACTION_PENDING; request.magic = m_magic; request.symbol = _Symbol;
      request.type = buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
      request.type_filling = ORDER_FILLING_RETURN; request.type_time = ORDER_TIME_GTC;
      request.price = lot.entry; request.sl = lot.stop; request.volume = lot.volume;
      request.tp = 0;
      if(use_tp)
      {
         request.tp = NormalizeDouble(MathRound(model.EndPrice() / context.tick) * context.tick, _Digits);
         double distance = buy ? request.tp - request.price : request.price - request.tp;
         if(!MathIsValidNumber(request.tp) || request.tp <= 0 || distance <= 0
            || distance + context.tick * 0.0000001 < context.stop_distance)
         { error = "TP swing end invalid"; return false; }
      }
      request.comment = Comment(model, index); loss = lot.loss; return true;
   }
   string SendLocked(const CFiboModel &model, const bool use_tp)
   {
      if(!Permissions()) return "Aktifkan Algo Trading / koneksi akun.";
      if(!model.Ready() || model.Mask() == 0) return "Pilih swing dan minimal satu level.";
      if(!HistorySelect(0, TimeCurrent())) return "History belum tersedia; tidak mengirim.";
      CFiboRisk risk; FiboRiskContext context; risk.ReadContext(model, context);
      double available = context.total_budget;
      // All uses the same equal shares as the preview. Retained reservations
      // (including deselected/filled/cancelled levels) cap later retries too.
      if(model.RiskAll())
      {
         double held = 0; int new_count = 0;
         for(int i = 0; i < FIBO_RATIOS; i++)
         {
            string comment = Comment(model, i);
            if(AlreadySent(comment))
            {
               double loss = m_reconcile.HeldLoss(comment);
               if(loss <= 0) return "All: risiko order lama belum diketahui; tidak mengirim.";
               held += loss;
            }
            else if(model.Enabled(i)) new_count++;
         }
         double remaining = context.total_budget - held;
         available = remaining;
         if(new_count > 0 && (!MathIsValidNumber(remaining) || remaining <= 0))
            return "All: anggaran sudah terpakai order sebelumnya.";
         if(new_count > 0) context.budget = MathMin(context.budget, remaining / new_count);
      }
      MqlTradeRequest requests[FIBO_RATIOS];
      double losses[FIBO_RATIOS];
      bool pending[FIBO_RATIOS];
      int skipped = 0, count = 0;
      double total_margin = 0, total_loss = 0;
      // Full preflight: no OrderSend until every new selected level is valid.
      for(int i = 0; i < FIBO_RATIOS; i++)
      {
         ZeroMemory(requests[i]); pending[i] = false; losses[i] = 0;
         if(!model.Enabled(i)) continue;
         if(AlreadySent(Comment(model, i))) { skipped++; continue; }
         string error = "";
         if(!Prepare(model, use_tp, i, context, requests[i], losses[i], error)) return Level(i) + ": " + error;
         total_loss += losses[i];
         MqlTradeCheckResult check = {};
         if(!OrderCheck(requests[i], check) || (check.retcode != 0 && check.retcode != TRADE_RETCODE_DONE))
            return Level(i) + ": check " + IntegerToString(check.retcode) + " " + check.comment;
         double margin = 0;
         ENUM_ORDER_TYPE side = requests[i].type == ORDER_TYPE_BUY_LIMIT ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(!OrderCalcMargin(side, _Symbol, requests[i].volume, requests[i].price, margin)
            || !MathIsValidNumber(margin) || margin < 0) return Level(i) + ": margin unavailable";
         total_margin += margin; pending[i] = true; count++;
      }
      if(count == 0) return "Tidak ada level baru; sudah dikirim: " + IntegerToString(skipped);
      if(model.RiskAll() && (!MathIsValidNumber(total_loss) || total_loss > available))
         return "All: estimasi loss melebihi sisa anggaran.";
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(!MathIsValidNumber(total_margin) || !MathIsValidNumber(free_margin) || total_margin > free_margin)
         return "Margin tidak cukup untuk seluruh level baru.";
      int sent = 0, failed = 0, unknown = 0;
      for(int i = 0; i < FIBO_RATIOS; i++)
      {
         if(!pending[i]) continue;
         // State/permissions can change after preflight, especially mid-batch.
         MqlTradeCheckResult check = {};
         if(!Permissions() || !OrderCheck(requests[i], check)
            || (check.retcode != 0 && check.retcode != TRADE_RETCODE_DONE))
         { failed++; Print("manualFibo ", Level(i), ": not sent; check ", check.retcode, " ", check.comment); continue; }
         // Persist BEFORE sending: ambiguous timeouts must never be blindly retried.
         if(!m_reconcile.Begin(requests[i].comment, losses[i]))
         { failed++; Print("manualFibo ", Level(i), ": cannot save submission marker"); continue; }
         MqlTradeResult result = {};
         bool ok = OrderSend(requests[i], result);
         if(m_reconcile.AcceptedCode(result.retcode)) sent++;
         else if(m_reconcile.UncertainCode(result.retcode)) unknown++;
         else failed++;
         m_reconcile.Finish(requests[i].comment, result);
         Print("manualFibo ", Level(i), ": OrderSend=", ok, ", ticket=", result.order,
               ", retcode=", result.retcode, " ", result.comment);
      }
      GlobalVariablesFlush();
      return "Sent " + IntegerToString(sent) + "; gagal " + IntegerToString(failed)
             + "; cek " + IntegerToString(unknown) + "; skip " + IntegerToString(skipped) + ". Lihat Experts.";
   }
public:
   CManualFiboOrders(void) { m_magic = 0; }
   bool Configure(const ulong magic)
   {
      if(magic == 0) return false;
      m_magic = magic;
      m_scope = "MF." + Hash(AccountInfoString(ACCOUNT_SERVER) + "|" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))
                  + "|" + IntegerToString((long)magic) + "|" + _Symbol) + ".";
      m_mutex = m_scope + "Lock";
      m_reconcile.Configure(m_scope, magic);
      return true;
   }
   string Comment(const CFiboModel &model, const int index) const
   {
      // Risk/SL/TP edits do not turn a previously sent anchor/ratio into a new order.
      string setup = IntegerToString((long)model.StartTime()) + "|" + DoubleToString(model.StartPrice(), _Digits)
                     + "|" + IntegerToString((long)model.EndTime()) + "|" + DoubleToString(model.EndPrice(), _Digits);
      return "MF:" + Hash(setup) + ":" + IntegerToString(index);
   }
   string Send(const CFiboModel &model, const bool use_tp)
   {
      if(!Acquire()) return "Operasi manualFibo lain masih berjalan.";
      string message = SendLocked(model, use_tp); Release(); return message;
   }
   void Transaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
   { m_reconcile.Transaction(trans, request, result); }
   string Reconcile(void)
   {
      if(!m_reconcile.Pending()) return "";
      if(!Acquire()) return "";
      string message = m_reconcile.Poll(); Release(); return message;
   }
   string Delete(void)
   {
      if(!Acquire()) return "Operasi manualFibo lain masih berjalan.";
      if(!Permissions()) { Release(); return "Aktifkan Algo Trading / koneksi akun."; }
      int deleted = 0, failed = 0;
      // Current symbol + magic + EA comment only; never close filled positions.
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !Owned()) continue;
         long type = OrderGetInteger(ORDER_TYPE);
         if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT) continue;
         MqlTradeRequest request = {}; MqlTradeResult result = {};
         request.action = TRADE_ACTION_REMOVE; request.order = ticket;
         request.symbol = _Symbol; request.magic = m_magic;
         bool ok = OrderSend(request, result);
         if(ok && result.retcode == TRADE_RETCODE_DONE) deleted++; else failed++;
         Print("manualFibo delete #", ticket, ": ", result.retcode, " ", result.comment);
      }
      Release();
      return "Deleted " + IntegerToString(deleted) + "; gagal " + IntegerToString(failed) + ". Lihat Experts.";
   }
};
#endif
