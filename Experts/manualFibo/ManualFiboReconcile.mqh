#ifndef MANUAL_FIBO_RECONCILE_MQH
#define MANUAL_FIBO_RECONCILE_MQH

struct ManualFiboPending
{
   string comment;
   ulong ticket;
   uint request_id;
   datetime since;
   bool accepted, rejected, deleting, rearm;
};

// Durable submission records plus bounded, read-only broker reconciliation.
// 1 = uncertain submission, 2 = accepted, 3 = deletion awaiting history proof.
// A confirmed wholly unfilled cancellation advances the per-level attempt ID.
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
      if((StringLen(comment) != 21 && StringLen(comment) != 30) || StringSubstr(comment, 0, 3) != "MF:"
         || StringSubstr(comment, 19, 1) != ":") return false;
      for(int i = 3; i < 19; i++)
      {
         ushort c = StringGetCharacter(comment, i);
         if(!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) return false;
      }
      ushort ratio = StringGetCharacter(comment, 20);
      if(ratio < '0' || ratio > '5') return false;
      if(StringLen(comment) == 30)
      {
         if(StringSubstr(comment, 21, 1) != "-") return false;
         for(int i = 22; i < 30; i++)
         {
            ushort c = StringGetCharacter(comment, i);
            if(!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) return false;
         }
      }
      return true;
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
      int size = Find(comment);
      if(size < 0)
      {
         size = ArraySize(m_pending);
         if(ArrayResize(m_pending, size + 1) != size + 1) return false;
      }
      string key = Key(comment);
      m_pending[size].comment = comment; m_pending[size].ticket = Ticket(key);
      m_pending[size].request_id = (uint)Read(key + ".Id");
      m_pending[size].since = (datetime)Read(key + ".When");
      m_pending[size].accepted = false; m_pending[size].rejected = false;
      m_pending[size].deleting = Read(key) == 3; m_pending[size].rearm = false;
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
   uint Attempt(const string comment) const
   {
      if(StringLen(comment) == 21) return 0;
      uint value = 0;
      for(int i = 22; i < 30; i++)
      {
         ushort c = StringGetCharacter(comment, i);
         value = value * 16 + (uint)(c <= '9' ? c - '0' : c - 'A' + 10);
      }
      return value;
   }
   uint Generation(const string base) const { return (uint)Read(Key(base) + ".Gen"); }
   bool WhollyCancelled(const ulong ticket) const
   {
      if(HistoryOrderGetInteger(ticket, ORDER_STATE) != ORDER_STATE_CANCELED) return false;
      double initial = HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL);
      double remaining = HistoryOrderGetDouble(ticket, ORDER_VOLUME_CURRENT);
      // Missing data or any partial fill must never release the risk reservation.
      return MathIsValidNumber(initial) && initial > 0 && MathIsValidNumber(remaining) && remaining == initial
             && HistoryOrderGetInteger(ticket, ORDER_POSITION_ID) == 0;
   }
   bool SupersededCancellation(const ulong ticket, const string current) const
   {
      string previous = HistoryOrderGetString(ticket, ORDER_COMMENT);
      return ValidComment(previous) && StringSubstr(previous, 0, 21) == StringSubstr(current, 0, 21)
             && Attempt(previous) < Attempt(current) && WhollyCancelled(ticket);
   }
   bool BeginDelete(const string comment, const ulong ticket)
   {
      if(!ValidComment(comment)) return false;
      string key = Key(comment);
      // Store the exact ticket before removal. On restart marker 3 resumes proof checks.
      SaveTicket(key, ticket);
      if(Ticket(key) != ticket || GlobalVariableSet(key, 3) == 0) return false;
      GlobalVariablesFlush(); return Track(comment);
   }
   void FinishDelete(const string comment, const MqlTradeResult &result)
   {
      string key = Key(comment);
      GlobalVariableSet(key + ".Id", (double)result.request_id);
      if(!AcceptedCode(result.retcode) && !UncertainCode(result.retcode))
      {
         GlobalVariableSet(key, 2); // Failed removal keeps the accepted order protected.
         int index = Find(comment); if(index >= 0) Remove(index);
      }
      else Track(comment); // Acknowledgement alone is not a no-fill cancellation proof.
      GlobalVariablesFlush();
   }
   bool Advance(const string comment)
   {
      string base = StringSubstr(comment, 0, 21);
      uint previous = Attempt(comment), current = Generation(base);
      if(current < previous || previous == (uint)0xFFFFFFFF) return false;
      if(current == previous && GlobalVariableSet(Key(base) + ".Gen", (double)previous + 1) == 0) return false;
      // Counter first, then remove only the old attempt. A crash stays fail-closed.
      GlobalVariablesFlush(); Forget(comment); GlobalVariablesFlush(); return true;
   }
   bool RefreshCancellation(const string comment)
   {
      // Also repairs old accepted records whose cancellation predates this build.
      string key = Key(comment);
      if(!GlobalVariableCheck(key)) return false;
      ulong ticket = Ticket(key);
      if(ticket == 0 || OrderSelect(ticket) || !HistoryOrderSelect(ticket) || !OwnedHistory(ticket)
         || HistoryOrderGetString(ticket, ORDER_COMMENT) != comment || !WhollyCancelled(ticket)) return false;
      if(!Advance(comment)) return false;
      int index = Find(comment); if(index >= 0) Remove(index);
      return true;
   }
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
         if(ValidComment(comment) && (Read(key) == 1 || Read(key) == 3)) Track(comment);
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
         if(request.magic != m_magic || request.symbol != _Symbol) return;
         int index = -1;
         if(request.action == TRADE_ACTION_PENDING
            && (request.type == ORDER_TYPE_BUY_LIMIT || request.type == ORDER_TYPE_SELL_LIMIT))
         {
            index = Find(request.comment);
            if(index >= 0 && m_pending[index].deleting) return;
         }
         else if(request.action == TRADE_ACTION_REMOVE)
         {
            for(int i = 0; i < ArraySize(m_pending); i++)
               if(m_pending[i].deleting && m_pending[i].ticket == request.order) { index = i; break; }
         }
         if(index < 0) return;
         if(m_pending[index].request_id != 0 && result.request_id != m_pending[index].request_id) return;
         if(!m_pending[index].deleting && AcceptedCode(result.retcode)) m_pending[index].accepted = true;
         else if(m_pending[index].request_id != 0 && result.request_id == m_pending[index].request_id
                 && RejectedCode(result.retcode)) m_pending[index].rejected = true;
         if(!m_pending[index].deleting && result.order != 0) m_pending[index].ticket = result.order;
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
         if(m_pending[i].deleting)
         {
            if(OrderSelect(ticket)) continue;
            if(HistoryOrderSelect(ticket) && OwnedHistory(ticket)
               && HistoryOrderGetString(ticket, ORDER_COMMENT) == m_pending[i].comment)
            {
               long state = HistoryOrderGetInteger(ticket, ORDER_STATE);
               if(WhollyCancelled(ticket)) m_pending[i].rearm = true;
               else if(state == ORDER_STATE_FILLED || state == ORDER_STATE_CANCELED
                       || state == ORDER_STATE_EXPIRED || state == ORDER_STATE_REJECTED)
               {
                  m_pending[i].accepted = true; // Filled/partial/uncertain volume: preserve protection.
                  Print("manualFibo delete #", ticket, ": stays protected; state ", state,
                        "; initial ", HistoryOrderGetDouble(ticket, ORDER_VOLUME_INITIAL),
                        "; remaining ", HistoryOrderGetDouble(ticket, ORDER_VOLUME_CURRENT),
                        "; position ", HistoryOrderGetInteger(ticket, ORDER_POSITION_ID));
               }
            }
            continue;
         }
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
         if(m_pending[i].deleting || m_pending[i].accepted || m_pending[i].rejected) continue;
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
            ulong ticket = OrderGetTicket(m_active_cursor);
            if(ticket == 0 || !OwnedActive()) continue;
            int index = Find(OrderGetString(ORDER_COMMENT));
            if(index >= 0 && !m_pending[index].deleting)
            { m_pending[index].accepted = true; m_pending[index].ticket = ticket; }
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
               if(index >= 0 && !m_pending[index].deleting)
               { m_pending[index].accepted = true; m_pending[index].ticket = ticket; }
            }
         }
      }
      int accepted = 0, rejected = 0, rearmed = 0;
      for(int i = ArraySize(m_pending) - 1; i >= 0; i--)
      {
         string key = Key(m_pending[i].comment);
         if(!GlobalVariableCheck(key) || Read(key) == 2) { Remove(i); continue; }
         if(m_pending[i].deleting)
         {
            if(m_pending[i].rearm)
            { if(Advance(m_pending[i].comment)) { rearmed++; Remove(i); } }
            else if(m_pending[i].accepted || m_pending[i].rejected)
            { if(GlobalVariableSet(key, 2) != 0) { accepted++; Remove(i); } }
            continue;
         }
         if(m_pending[i].accepted)
         {
            if(m_pending[i].ticket != 0) SaveTicket(key, m_pending[i].ticket);
            if(GlobalVariableSet(key, 2) != 0) { accepted++; Remove(i); }
         }
         else if(m_pending[i].rejected)
         { Forget(m_pending[i].comment); rejected++; Remove(i); }
      }
      if(accepted > 0 || rejected > 0 || rearmed > 0)
      {
         GlobalVariablesFlush(); m_report_wait = false;
         return "Rekonsiliasi: " + IntegerToString(accepted) + " diterima; " + IntegerToString(rejected) + " ditolak; " + IntegerToString(rearmed) + " siap dikirim ulang.";
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
