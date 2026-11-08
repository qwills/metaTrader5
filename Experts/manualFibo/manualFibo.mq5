#property strict
#property version "1.12"
#property description "Manual Fibonacci with per-level SL and equity-risk lot estimates."
#include "ManualFiboDialog.mqh"
#include "ManualFiboChart.mqh"
#include "ManualFiboState.mqh"

enum ManualSelection { MANUAL_IDLE, MANUAL_START, MANUAL_END };
CManualFiboModel g_model;
CManualFiboDialog g_dialog;
CManualFiboChart g_chart;
CManualFiboState g_storage;
ManualSelection g_selection = MANUAL_IDLE;
datetime g_pick_time = 0;
double g_pick_price = 0;
bool g_created = false, g_events_saved = false;
bool g_left_down = false, g_panel_pressed = false, g_scroll_locked = false;
bool g_saved_scroll = true, g_init_scroll = true, g_saved_move = false, g_saved_delete = false;
ulong g_ignore_click_until = 0;
string g_symbol = "";

void Status(const string text) { g_dialog.SetStatus(text, g_selection != MANUAL_IDLE); }
void LockScroll(void)
{
   if(g_scroll_locked) return;
   g_saved_scroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false); g_scroll_locked = true;
}
void UnlockScroll(void)
{
   if(!g_scroll_locked) return;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, g_saved_scroll); g_scroll_locked = false;
}
bool InPanel(const int x, const int y)
{ return g_created && g_dialog.IsVisible() && g_dialog.Contains(x, y); }
void CancelSelection(const bool refresh = true)
{
   g_selection = MANUAL_IDLE; g_pick_time = 0; g_pick_price = 0;
   g_chart.ClearStart();
   if(!g_panel_pressed && !g_dialog.Dragging()) UnlockScroll();
   if(refresh) g_dialog.Refresh(g_model);
}

// Commit only after rendering succeeds; restore the previous valid drawing on failure.
bool ApplyModel(const CManualFiboModel &candidate)
{
   if(candidate.Ready() && !g_chart.Draw(candidate))
   {
      int drawing_error = GetLastError();
      if(g_model.Ready()) g_chart.Draw(g_model); else g_chart.ClearFibo();
      ChartRedraw();
      Print("manualFibo: drawing failed, error ", drawing_error);
      return false;
   }
   g_model.CopyFrom(candidate); g_dialog.Refresh(g_model); ChartRedraw(); return true;
}
void SyncObject(void)
{
   if(!g_model.Ready()) return;
   CManualFiboModel candidate; candidate.CopyFrom(g_model);
   if(g_model.Locked() || !g_chart.Read(candidate) || !g_chart.Configure(candidate))
   {
      g_chart.Draw(g_model); ChartRedraw();
      Status("Edit tidak valid; anchor dipulihkan."); return;
   }
   g_model.CopyFrom(candidate); g_dialog.Refresh(g_model); ChartRedraw();
   Status("Anchor diperbarui.");
}

int OnInit(void)
{
   CManualFiboModel initial; g_model.CopyFrom(initial);
   bool restoring = g_storage.Load(g_model, _Symbol);
   g_symbol = _Symbol; g_created = false; g_events_saved = false;
   g_selection = MANUAL_IDLE; g_pick_time = 0; g_pick_price = 0;
   g_left_down = false; g_panel_pressed = false; g_scroll_locked = false; g_ignore_click_until = 0;
   if(!restoring) g_chart.ClearAll();
   g_saved_move = (bool)ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE);
   g_saved_delete = (bool)ChartGetInteger(0, CHART_EVENT_OBJECT_DELETE);
   g_init_scroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL); g_events_saved = true;
   g_dialog.Minimized(false);
   if(!g_dialog.Create(0, "manualFibo.Panel", 0, 12, 24, 632, 508)) return INIT_FAILED;
   g_created = true; g_dialog.Refresh(g_model);
   if(!g_dialog.Run()) return INIT_FAILED;
   if(restoring) g_dialog.IniFileLoad();
   if(g_model.Ready() && !g_chart.Draw(g_model)) return INIT_FAILED;
   g_storage.Consume();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   if(!EventSetTimer(1)) return INIT_FAILED;
   Status("Klik Pilih Swing."); ChartRedraw(); return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_created) g_dialog.CancelDrag();
   // Capture the final native edit even if a pending drag event was not delivered.
   if(g_created && g_model.Ready() && !g_model.Locked() && g_chart.HasFibo())
   {
      CManualFiboModel candidate; candidate.CopyFrom(g_model);
      if(g_chart.Read(candidate)) g_model.CopyFrom(candidate);
   }
   if(g_model.Ready() && !g_chart.HasFibo()) g_model.Clear();
   bool preserving = reason == REASON_CHARTCHANGE && g_created && g_storage.Save(g_model, g_symbol);
   g_dialog.Destroy(reason); g_created = false; g_panel_pressed = false; UnlockScroll();
   if(g_events_saved)
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, g_saved_move);
      ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, g_saved_delete);
      ChartSetInteger(0, CHART_MOUSE_SCROLL, g_init_scroll);
   }
   g_chart.ClearStart();
   if(!preserving) g_chart.ClearAll();
   ChartRedraw();
}

void OnTimer(void)
{
   if(g_created && !IsStopped() && !g_dialog.IsMinimized() && g_dialog.RefreshLots(g_model)) ChartRedraw();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_created || IsStopped()) return;
   bool was_dragging = g_dialog.Dragging(), was_left = g_left_down;
   bool was_minimized = g_dialog.IsMinimized();
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      bool down = (StringToInteger(sparam) & 1) != 0;
      if(down && !g_left_down && InPanel((int)lparam, (int)dparam))
      { g_panel_pressed = true; LockScroll(); }
   }
   // Let Standard Library route all events and handle drag/minimize itself.
   g_dialog.ChartEvent(id, lparam, dparam, sparam);
   if(IsStopped()) return;
   if(was_minimized && !g_dialog.IsMinimized() && g_dialog.RefreshLots(g_model)) ChartRedraw();
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      bool down = (StringToInteger(sparam) & 1) != 0;
      if(!down && g_left_down && g_panel_pressed)
      { g_panel_pressed = false; g_ignore_click_until = GetTickCount64() + 250; }
      g_left_down = down;
   }
   if(was_dragging && !g_dialog.Dragging()) g_ignore_click_until = GetTickCount64() + 250;
   if(g_selection == MANUAL_IDLE && !g_panel_pressed && !g_dialog.Dragging()) UnlockScroll();
   if(g_selection != MANUAL_IDLE && ((id == CHARTEVENT_MOUSE_MOVE && was_left && !g_left_down)
                                     || (was_dragging && !g_dialog.Dragging())))
      ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   if(id == CHARTEVENT_OBJECT_DELETE && sparam == g_chart.Name())
   {
      if(!g_chart.HasFibo() && g_model.Ready())
      { g_model.Clear(); g_dialog.Refresh(g_model); Status("Fibo dihapus."); }
      return;
   }
   if((id == CHARTEVENT_OBJECT_CHANGE || id == CHARTEVENT_OBJECT_DRAG) && sparam == g_chart.Name())
   { SyncObject(); return; }
   if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_CHART_CHANGE) return;
   ManualFiboAction action = g_dialog.TakeAction();
   if(action == MANUAL_RISK)
   {
      double percent = 0, previous = g_model.RiskPercent();
      if(!ManualFiboParseNumber(g_dialog.RiskText(), percent) || !g_model.SetRiskPercent(percent))
      { if(g_dialog.RefreshRiskInput(g_model)) ChartRedraw(); Status("Risk 0-100 persen, maksimal 8 desimal."); return; }
      bool changed = g_dialog.RefreshRiskInput(g_model);
      if(previous == g_model.RiskPercent()) { if(changed) ChartRedraw(); return; }
      g_dialog.RefreshLots(g_model); ChartRedraw(); Status("Risk diperbarui untuk setiap level."); return;
   }
   if(action == MANUAL_SL)
   {
      int index = g_dialog.EditIndex();
      if(index < 0 || index >= MANUAL_FIBO_RATIOS) return;
      string text = g_dialog.StopText(index); StringTrimLeft(text); StringTrimRight(text);
      double existing = g_model.StopPrice(index);
      string displayed = existing == EMPTY_VALUE ? "" : DoubleToString(existing, _Digits);
      // Focusing/leaving an untouched default field must not freeze its SL.
      if(text == displayed) return;
      double stop = 0;
      if(text == "") g_model.ResetStop(index);
      else if(!ManualFiboParseNumber(text, stop) || !g_model.SetStop(index, stop))
      { if(g_dialog.RefreshStopInput(g_model, index)) ChartRedraw(); Status("SL harus harga positif; kosong = awal swing."); return; }
      g_dialog.RefreshStopInput(g_model, index); g_dialog.RefreshLots(g_model); ChartRedraw();
      Status(text == "" ? "SL kembali mengikuti awal swing." : "SL level diperbarui."); return;
   }
   if(action == MANUAL_LEVELS)
   {
      int mask = g_dialog.RatioMask();
      if(mask == g_model.Mask()) return;
      CManualFiboModel candidate; candidate.CopyFrom(g_model); candidate.SetMask(mask);
      if(!ApplyModel(candidate)) { g_dialog.Refresh(g_model); Status("Gagal mengubah level; coba lagi."); }
      else Status(g_model.Mask() == 0 ? "Semua level disembunyikan." : "Level diperbarui.");
      return;
   }
   if(action == MANUAL_LOCK)
   {
      bool locked = g_dialog.AnchorLocked();
      if(locked == g_model.Locked()) return;
      if(!g_chart.Lock(locked))
      { g_chart.Lock(g_model.Locked()); g_dialog.Refresh(g_model); Status("Gagal mengubah kunci anchor."); return; }
      g_model.SetLocked(locked);
      if(locked) CancelSelection();
      Status(locked ? "Anchor terkunci." : "Anchor bebas diedit."); ChartRedraw(); return;
   }
   if(action == MANUAL_RESET)
   {
      g_model.Clear(); CancelSelection(); g_chart.ClearFibo(); ChartRedraw();
      Status("Fibo dihapus. Klik Pilih Swing."); return;
   }
   if(action == MANUAL_DRAW)
   {
      if(g_model.Locked()) { Status("Lepas centang Kunci anchor."); return; }
      if(g_selection != MANUAL_IDLE) { CancelSelection(); Status("Pemilihan dibatalkan."); }
      else { LockScroll(); g_selection = MANUAL_START; Status("Pilih high/low candle awal."); }
      return;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 27)
   {
      g_dialog.CancelDrag(); g_panel_pressed = false; g_ignore_click_until = GetTickCount64() + 250;
      CancelSelection(); Status("Pemilihan dibatalkan."); return;
   }
   if(id != CHARTEVENT_CLICK || g_selection == MANUAL_IDLE || g_model.Locked()) return;
   int x = (int)lparam, y = (int)dparam;
   if(g_panel_pressed || g_dialog.Dragging() || GetTickCount64() < g_ignore_click_until || InPanel(x, y)) return;
   datetime time = 0; double price = 0;
   if(!g_chart.PickCandle(x, y, time, price)) { Status("Klik candle pada chart utama."); return; }
   if(g_selection == MANUAL_START)
   {
      if(!g_chart.MarkStart(time, price)) { Status("Gagal menandai awal; coba lagi."); return; }
      g_pick_time = time; g_pick_price = price; g_selection = MANUAL_END;
      Status("Pilih high/low candle akhir."); return;
   }
   CManualFiboModel candidate; candidate.CopyFrom(g_model);
   if(!candidate.SetAnchors(g_pick_time, g_pick_price, time, price))
   { Status("Harga akhir harus berbeda."); return; }
   if(!ApplyModel(candidate)) { Status("Gagal menggambar; pilih akhir lagi."); return; }
   CancelSelection(false); Status("Fibo siap. Double-click untuk edit.");
}
