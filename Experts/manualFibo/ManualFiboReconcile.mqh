#ifndef MANUAL_FIBO_RECONCILE_MQH
#define MANUAL_FIBO_RECONCILE_MQH

struct ManualFiboPending
{
   string comment;
   ulong ticket;
   uint request_id;
   datetime since;
   bool accepted, rejected;
};

// Durable submission records plus bounded, read-only broker reconciliation.
// 1 = uncertain intent, 2 = accepted. Absence never proves rejection.
class CManualFiboReconcile
{
private:
   string m_scope;
   ulong m_magic, m_next_poll;
   ManualFiboPending m_pending[];
   int m_history_cursor, m_active_cursor, m_ticket_cursor, m_attempts;
   bool m_connected, m_report_wait;
   string Key(const string comment) const { return m_scope + comment; }
   bool ValidComment(const string comment) const
   {
      if(StringLen(comment) != 21 || StringSubstr(comment, 0, 3) != "MF:"
         || StringSubstr(comment, 19, 1) != ":") return false;
      for(int i = 3; i < 19; i++)
      {
         ushort c = StringGetCharacter(comment, i);
         if(!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) return false;
      }
      ushort ratio = StringGetCharacter(comment, 20);
      return ratio >= '0' && ratio <= '5';
   }
   int Find(const string comment) const
   {
      for(int i = 0; i < ArraySize(m_pending); i++) if(m_pending[i].comment == comment) return i;
      return -1;
   }
   double Read(const string key) const { return GlobalVariableCheck(key) ? GlobalVariableGet(key) : 0; }
   ulong Ticket(const string key) const
   { return ((ulong)Read(key + ".Hi") << 32) | (ulong)Read(key + ".Lo"); }
   void SaveTicket(const string key, const ulong ticket)
   { GlobalVariableSet(key + ".Hi", (double)(ticket >> 32)); GlobalVariableSet(key + ".Lo", (double)(uint)ticket); }
   bool Track(const string comment)
   {
      if(Find(comment) >= 0) return true;
      int size = ArraySize(m_pending);
      if(ArrayResize(m_pending, size + 1) != size + 1) return false;
      string key = Key(comment);
      m_pending[size].comment = comment; m_pending[size].ticket = Ticket(key);
      m_pending[size].request_id = (uint)Read(key + ".Id");
      m_pending[size].since = (datetime)Read(key + ".When");
      m_pending[size].accepted = false; m_pending[size].rejected = false;
      m_next_poll = 0; m_attempts = 0; m_report_wait = true; return true;
   }
   void Remove(const int index)
   {
      int size = ArraySize(m_pending);
      for(int i = index + 1; i < size; i++) m_pending[i - 1] = m_pending[i];
      ArrayResize(m_pending, size - 1);
   }
   bool OwnedActive(void) const
   {
      long type = OrderGetInteger(ORDER_TYPE);
      return (ulong)OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == _Symbol
             && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT);
   }
   bool OwnedHistory(const ulong ticket) const
   {
      long type = HistoryOrderGetInteger(ticket, ORDER_TYPE);
      return (ulong)HistoryOrderGetInteger(ticket, ORDER_MAGIC) == m_magic
             && HistoryOrderGetString(ticket, ORDER_SYMBOL) == _Symbol
             && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT);
   }
   bool RejectedCode(const uint code) const
   {
      // Whitelist definite request failures; unknown/new broker codes stay blocked.
      return code == TRADE_RETCODE_REQUOTE || code == TRADE_RETCODE_REJECT
             || code == TRADE_RETCODE_CANCEL || (code >= TRADE_RETCODE_INVALID && code <= TRADE_RETCODE_INVALID_EXPIRATION)
             || code == TRADE_RETCODE_TOO_MANY_REQUESTS || code == TRADE_RETCODE_SERVER_DISABLES_AT
             || code == TRADE_RETCODE_CLIENT_DISABLES_AT || code == TRADE_RETCODE_FROZEN
             || code == TRADE_RETCODE_INVALID_FILL || (code >= TRADE_RETCODE_ONLY_REAL && code <= TRADE_RETCODE_LIMIT_POSITIONS);
   }
public:
   bool Pending(void) const { return ArraySize(m_pending) > 0; }
   CManualFiboReconcile(void) { m_magic = 0; m_next_poll = 0; m_history_cursor = 0; m_active_cursor = 0; m_ticket_cursor = 0; m_attempts = 0; m_connected = false; m_report_wait = false; }
   bool AcceptedCode(const uint code) const
   { return code == TRADE_RETCODE_PLACED || code == TRADE_RETCODE_DONE || code == TRADE_RETCODE_DONE_PARTIAL; }
   bool UncertainCode(const uint code) const { return !AcceptedCode(code) && !RejectedCode(code); }
   void Configure(const string scope, const ulong magic)
   {
      m_scope = scope; m_magic = magic; ArrayResize(m_pending, 0);
      m_next_poll = 0; m_history_cursor = 0; m_active_cursor = 0; m_ticket_cursor = 0; m_attempts = 0; m_connected = false;
      m_report_wait = false;
      // One startup inventory, not a scan on every timer tick.
      int count = GlobalVariablesTotal();
      for(int i = 0; i < count; i++)
      {
         string key = GlobalVariableName(i);
         if(StringSubstr(key, 0, StringLen(scope)) != scope) continue;
         string comment = StringSubstr(key, StringLen(scope));
         if(ValidComment(comment) && Read(key) == 1) Track(comment);
      }
   }
   bool Begin(const string comment, const double loss)
   {
      string key = Key(comment);
      if(GlobalVariableCheck(key)) return false;
      // A pre-send risk reservation survives timeouts and terminal restarts.
      if(!MathIsValidNumber(loss) || loss <= 0 || GlobalVariableSet(key + ".Loss", loss) == 0
         || GlobalVariableSet(key + ".When", (double)TimeCurrent()) == 0)
      { Forget(comment); return false; }
      if(GlobalVariableSet(key, 1) == 0) { Forget(comment); return false; }
      GlobalVariablesFlush(); return true;
   }
   void Forget(const string comment)
   {
      string key = Key(comment);
      GlobalVariableDel(key); GlobalVariableDel(key + ".Loss"); GlobalVariableDel(key + ".When");
      GlobalVariableDel(key + ".Id"); GlobalVariableDel(key + ".Hi"); GlobalVariableDel(key + ".Lo");
   }
   void Finish(const string comment, const MqlTradeResult &result)
   {
      string key = Key(comment);
      GlobalVariableSet(key + ".Id", (double)result.request_id); SaveTicket(key, result.order);
      if(AcceptedCode(result.retcode))
      { if(GlobalVariableSet(key, 2) == 0) Track(comment); }
      else if(UncertainCode(result.retcode)) Track(comment);
      else Forget(comment);
   }
   // Returns a retained reservation, or -1 for a legacy/unknown record without a loss.
   double HeldLoss(const string comment) const
   {
      string key = Key(comment);
      double loss = Read(key + ".Loss");
      return MathIsValidNumber(loss) && loss > 0 ? loss : -1;
   }
   void Transaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
   {
      if(ArraySize(m_pending) == 0) return;
      if(trans.type == TRADE_TRANSACTION_REQUEST)
      {
         // request/result are defined only for REQUEST events.
         if(request.magic != m_magic || request.symbol != _Symbol || request.action != TRADE_ACTION_PENDING
            || (request.type != ORDER_TYPE_BUY_LIMIT && request.type != ORDER_TYPE_SELL_LIMIT)) return;
         int index = Find(request.comment);
         if(index < 0) return;
         if(m_pending[index].request_id != 0 && result.request_id != m_pending[index].request_id) return;
         if(AcceptedCode(result.retcode)) m_pending[index].accepted = true;
         else if(m_pending[index].request_id != 0 && result.request_id == m_pending[index].request_id
                 && RejectedCode(result.retcode)) m_pending[index].rejected = true;
         if(result.order != 0) m_pending[index].ticket = result.order;
      }
      else
      {
         if(trans.symbol != _Symbol) return;
         bool relevant = false;
         for(int i = 0; i < ArraySize(m_pending); i++)
            if(m_pending[i].ticket == 0 || m_pending[i].ticket == trans.order) { relevant = true; break; }
         if(!relevant) return;
      }
      // Coalesce bursts; scans stay on the timer, never inside the event handler.
      if(m_next_poll > GetTickCount64() + 1000) m_next_poll = GetTickCount64() + 1000;
   }
   string Poll(void)
   {
      if(ArraySize(m_pending) == 0) return "";
      bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      if(connected && !m_connected) m_next_poll = 0;
      m_connected = connected;
      ulong now = GetTickCount64();
      if(!connected || now < m_next_poll) return "";
      m_next_poll = now + (m_attempts < 6 ? 5000 : 30000); m_attempts++;
      // Known-ticket probes avoid history scans when the ticket is available.
      int pending_count = ArraySize(m_pending);
      if(m_ticket_cursor >= pending_count) m_ticket_cursor = 0;
      for(int work = 0; work < 32 && work < pending_count; work++)
      {
         int i = m_ticket_cursor;
         m_ticket_cursor = (m_ticket_cursor + 1) % pending_count;
         ulong ticket = m_pending[i].ticket;
         if(ticket == 0 || m_pending[i].accepted || m_pending[i].rejected) continue;
         if(OrderSelect(ticket) && OwnedActive() && OrderGetString(ORDER_COMMENT) == m_pending[i].comment)
            m_pending[i].accepted = true;
         else if(HistoryOrderSelect(ticket) && OwnedHistory(ticket)
                 && HistoryOrderGetString(ticket, ORDER_COMMENT) == m_pending[i].comment)
         {
            if(HistoryOrderGetInteger(ticket, ORDER_STATE) == ORDER_STATE_REJECTED) m_pending[i].rejected = true;
            else m_pending[i].accepted = true;
         }
      }
      bool search = false; datetime from = TimeCurrent();
      for(int i = 0; i < ArraySize(m_pending); i++)
      {
         if(m_pending[i].accepted || m_pending[i].rejected) continue;
         search = true;
         datetime since = m_pending[i].since > 60 ? m_pending[i].since - 60 : 0;
         if(since < from) from = since;
      }
      if(search)
      {
         // Bounded pages, round-robin cursors; never traverse full history per tick.
         int total = OrdersTotal();
         if(m_active_cursor >= total) m_active_cursor = 0;
         for(int work = 0; work < 128 && m_active_cursor < total; work++, m_active_cursor++)
         {
            if(OrderGetTicket(m_active_cursor) == 0 || !OwnedActive()) continue;
            int index = Find(OrderGetString(ORDER_COMMENT));
            if(index >= 0) m_pending[index].accepted = true;
         }
         if(HistorySelect(from, TimeCurrent()))
         {
            total = HistoryOrdersTotal();
            if(m_history_cursor >= total) m_history_cursor = 0;
            for(int work = 0; work < 128 && m_history_cursor < total; work++, m_history_cursor++)
            {
               ulong ticket = HistoryOrderGetTicket(m_history_cursor);
               if(ticket == 0 || !OwnedHistory(ticket) || HistoryOrderGetInteger(ticket, ORDER_STATE) == ORDER_STATE_REJECTED) continue;
               int index = Find(HistoryOrderGetString(ticket, ORDER_COMMENT));
               if(index >= 0) m_pending[index].accepted = true;
            }
         }
      }
      int accepted = 0, rejected = 0;
      for(int i = ArraySize(m_pending) - 1; i >= 0; i--)
      {
         string key = Key(m_pending[i].comment);
         if(!GlobalVariableCheck(key) || Read(key) == 2) { Remove(i); continue; }
         if(m_pending[i].accepted)
         { GlobalVariableSet(key, 2); accepted++; Remove(i); }
         else if(m_pending[i].rejected)
         { Forget(m_pending[i].comment); rejected++; Remove(i); }
      }
      if(accepted > 0 || rejected > 0)
      {
         GlobalVariablesFlush(); m_report_wait = false;
         return "Rekonsiliasi: " + IntegerToString(accepted) + " diterima; " + IntegerToString(rejected) + " ditolak.";
      }
      if(m_report_wait && ArraySize(m_pending) > 0)
      {
         m_report_wait = false;
         return "Hasil " + IntegerToString(ArraySize(m_pending)) + " order belum pasti; sedang diperiksa.";
      }
      return "";
   }
};
#endif
