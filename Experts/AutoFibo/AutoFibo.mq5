#property strict
#property version "3.00"
#property description "Automatic Pivot/Market Structure Fibonacci with equity-risk lot previews."
#include "AutoFiboDialog.mqh"
#include "AutoFiboChart.mqh"
#include "AutoFiboState.mqh"

CFiboModel g_model;
CAutoFiboDialog g_dialog;
CAutoFiboAnalysis g_auto;
CAutoFiboChart g_chart;
CAutoFiboState g_storage;
AutoFiboMethod g_auto_method = FIBO_PIVOT;
AutoFiboAnchorSource g_source = ANCHOR_NONE;
ENUM_STRUCTURE_TREND g_structure_trend = STRUCTURE_UNCLEAR;
ENUM_TIMEFRAMES g_analysis_tf = PERIOD_CURRENT;
int g_left_bars = 2, g_right_bars = 2, g_partial_attempts = 0;
bool g_edited = false, g_analysis_transient = false, g_labels_pending = false;
bool g_auto_force_pending = true, g_dialog_created = false, g_events_saved = false;
bool g_left_down = false, g_panel_pressed = false;
bool g_saved_mouse_move = false, g_saved_object_delete = false, g_saved_scroll = true;
ulong g_labels_retry_after = 0, g_auto_retry_after = 0;
datetime g_last_auto_bar = 0;
string g_auto_pair_key = "", g_status = "", g_base_status = "", g_attached_symbol = "";

void ShowStatus(void)
{
   string message = g_base_status + (g_labels_pending ? " | Label: retry." : "");
   if(g_status == message) return;
   g_status = message; g_dialog.Status(message);
}
void SetStatus(const string message) { g_base_status = message; ShowStatus(); }
void UpdateSwingDisplay(void)
{
   g_dialog.Refresh(g_model, false);
   string source = !g_model.Ready() ? "-" : (g_source == ANCHOR_PIVOT ? "Pivot" : (g_source == ANCHOR_STRUCTURE ? "Market Structure" : "Unknown"));
   g_dialog.SetAnchorSource(source + (g_model.Ready() && g_edited ? " (edit)" : ""));
}
void RefreshResults(void)
{
   if(!g_dialog.IsMinimized() && g_dialog.RefreshLots(g_model)) ChartRedraw();
}
string CheckpointContext(void)
{
   return "1|" + g_attached_symbol + "|" + IntegerToString((int)g_analysis_tf)
          + "|" + IntegerToString(g_left_bars) + "|" + IntegerToString(g_right_bars);
}
bool SaveChartSnapshot(void)
{
   if(g_model.Ready())
   {
      if(!g_chart.HasFibo()) { g_model.Clear(); g_source = ANCHOR_NONE; g_edited = false; }
      else if(!g_model.Locked())
      {
         CFiboModel candidate; candidate.CopyFrom(g_model);
         if(g_chart.Read(candidate))
         {
            if(candidate.StartTime() != g_model.StartTime() || candidate.EndTime() != g_model.EndTime()
               || candidate.StartPrice() != g_model.StartPrice() || candidate.EndPrice() != g_model.EndPrice()) g_edited = true;
            g_model.CopyFrom(candidate);
         }
      }
   }
   AutoFiboSnapshot s;
   s.timeframe = g_analysis_tf; s.left = g_left_bars; s.right = g_right_bars; s.method = g_auto_method;
   s.source = g_source; s.trend = g_structure_trend; s.edited = g_edited; s.transient = g_analysis_transient;
   s.pending = !g_model.Locked() && g_auto_force_pending; s.bar = g_labels_pending ? 0 : g_last_auto_bar;
   s.key = g_auto_pair_key; s.status = g_base_status;
   // Optional analysis persistence must not block anchor/risk preservation.
   if(!g_storage.SaveCheckpoint(g_auto, CheckpointContext())) g_storage.ClearCheckpoint();
   return g_storage.Write(g_model, s, g_attached_symbol);
}

int OnInit(void)
{
   CFiboModel initial; g_model.CopyFrom(initial);
   AutoFiboSnapshot snapshot;
   bool restoring = g_storage.Read(g_model, snapshot, _Symbol);
   g_dialog_created = false; g_events_saved = false; g_attached_symbol = _Symbol;
   g_auto_method = restoring ? (AutoFiboMethod)snapshot.method : FIBO_PIVOT;
   g_source = restoring ? (AutoFiboAnchorSource)snapshot.source : ANCHOR_NONE;
   g_structure_trend = restoring ? (ENUM_STRUCTURE_TREND)snapshot.trend : STRUCTURE_UNCLEAR;
   g_left_bars = restoring ? snapshot.left : 2; g_right_bars = restoring ? snapshot.right : 2;
   g_last_auto_bar = restoring ? snapshot.bar : 0; g_auto_pair_key = restoring ? snapshot.key : "";
   g_auto_force_pending = !g_model.Locked() && (!restoring || snapshot.pending);
   g_edited = restoring && snapshot.edited; g_analysis_transient = restoring && snapshot.transient;
   g_analysis_tf = (ENUM_TIMEFRAMES)_Period;
   g_left_down = false; g_panel_pressed = false; g_labels_pending = false;
   g_labels_retry_after = 0; g_auto_retry_after = 0; g_partial_attempts = 0; g_status = ""; g_base_status = "";
   g_chart.ResetCache(); g_auto.ResetAnalysis();
   if(!restoring) g_chart.ClearAll();
   if(!g_auto.Configure(g_left_bars, g_right_bars)) return INIT_FAILED;
   g_saved_mouse_move = (bool)ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE);
   g_saved_object_delete = (bool)ChartGetInteger(0, CHART_EVENT_OBJECT_DELETE);
   g_saved_scroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL); g_events_saved = true;
   g_dialog.Minimized(false);
   if(!g_dialog.Create(0, "AutoFibo.Panel", 0, 12, 24, 632, 632)) return INIT_FAILED;
   g_dialog_created = true;
   g_dialog.SetSettings(g_auto_method, g_left_bars, g_right_bars);
   UpdateSwingDisplay(); g_dialog.SetStructureTrend(StructureTrendName(g_structure_trend));
   if(!g_dialog.Run()) return INIT_FAILED;
   if(restoring) g_dialog.IniFileLoad();
   if(g_model.Ready()) { if(!g_chart.Draw(g_model)) return INIT_FAILED; }
   else g_chart.ClearFibo();
   if(restoring && snapshot.timeframe == (int)_Period)
   {
      if(!g_storage.LoadCheckpoint(g_auto, CheckpointContext()))
      { g_last_auto_bar = 0; g_auto_force_pending = !g_model.Locked(); }
      SetStatus(snapshot.status);
   }
   else
   {
      g_auto.ResetAnalysis(); ClearStructureLabels(); g_last_auto_bar = 0; g_auto_pair_key = "";
      g_auto_force_pending = !g_model.Locked(); g_analysis_transient = false;
      SetStatus(g_model.Locked() ? "Timeframe chart berubah; anchor tetap terkunci." : "Auto: analisis dijadwalkan.");
   }
   g_storage.ClearCheckpoint(); g_storage.ConsumeSnapshot();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   if(!EventSetTimer(1)) return INIT_FAILED;
   RefreshResults(); ChartRedraw(); return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_dialog_created) g_dialog.CancelDrag();
   bool preserving = reason == REASON_CHARTCHANGE && g_dialog_created && SaveChartSnapshot();
   g_dialog.Destroy(reason); g_dialog_created = false;
   if(g_events_saved)
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, g_saved_mouse_move);
      ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, g_saved_object_delete);
      ChartSetInteger(0, CHART_MOUSE_SCROLL, g_saved_scroll);
   }
   if(!preserving) g_chart.ClearAll();
   ChartRedraw();
}

bool SyncFiboFromObject(void)
{
   if(!g_model.Ready()) return false;
   CFiboModel candidate; candidate.CopyFrom(g_model);
   if(g_model.Locked() || !g_chart.Read(candidate) || !g_chart.Configure(candidate))
   {
      g_chart.Draw(g_model); ChartRedraw(); SetStatus("Edit tidak valid atau anchor terkunci; swing dipulihkan."); return false;
   }
   g_model.CopyFrom(candidate); g_edited = true; g_analysis_transient = false;
   UpdateSwingDisplay(); RefreshResults(); ChartRedraw();
   SetStatus("Fibo diperbarui. Kunci anchor untuk menahan pembaruan otomatis."); return true;
}
string AutoPairKey(const SwingPoint &start, const SwingPoint &end)
{
   return IntegerToString((long)start.time) + "," + StringFormat("%.17g", start.price)
          + "," + IntegerToString((long)end.time) + "," + StringFormat("%.17g", end.price);
}

void ClearStructureLabels(void)
{
   g_chart.ClearStructure(); g_structure_trend = STRUCTURE_UNCLEAR;
   g_dialog.SetStructureTrend(StructureTrendName(g_structure_trend));
   g_labels_pending = false; g_labels_retry_after = 0;
}
bool DrawStructureLabels(void)
{
   g_structure_trend = g_auto.Trend();
   g_dialog.SetStructureTrend(StructureTrendName(g_structure_trend));
   bool ok = g_chart.DrawStructure(g_auto);
   g_labels_pending = !ok;
   g_labels_retry_after = ok ? 0 : GetTickCount64() + 5000;
   ShowStatus(); return ok;
}

// GUI callbacks enqueue a search; only the timer performs price-history work.
void RequestAutoSearch(const bool force)
{
   if(g_model.Locked()) return;
   g_auto_force_pending = force || g_auto_force_pending;
   g_auto_retry_after = 0;
   SetStatus(g_auto_force_pending ? "Auto: pencarian dijadwalkan."
                                  : "Auto aktif; menunggu pasangan swing baru.");
}

void ScheduleAutoRetry(const bool force)
{
   g_auto_force_pending = force || g_auto_force_pending;
   g_auto_retry_after = GetTickCount64() + 5000;
}

bool RefreshAutoSwing(const bool force)
{
   if(g_model.Locked()) return false;
   datetime bar = iTime(_Symbol, g_analysis_tf, 1);
   if(bar <= 0)
   {
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: menunggu riwayat timeframe analisis.");
      return false;
   }
   if(!force && bar == g_last_auto_bar) return true;
   MqlRates closed_bars[];
   ArraySetAsSeries(closed_bars, false);
   int copied = CopyRates(_Symbol, g_analysis_tf, 1, 500, closed_bars);
   if(copied < g_left_bars + g_right_bars + 1
      || closed_bars[copied - 1].time != bar || iTime(_Symbol, g_analysis_tf, 1) != bar)
   {
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: menunggu candle tertutup yang cukup.");
      return false;
   }
   if(ArraySize(closed_bars) != copied && ArrayResize(closed_bars, copied) != copied)
   {
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: gagal menyiapkan data candle.");
      return false;
   }
   SwingPoint start = {}; SwingPoint end = {};
   AutoFiboAnalysisResult result = g_auto.Analyze(closed_bars, start, end, g_auto_method, force);
   if(result == FIBO_ANALYSIS_ERROR)
   {
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: " + g_auto.LastError()); return false;
   }
   // Optional labels retry independently; a label error cannot block Fibo.
   DrawStructureLabels();
   if(g_auto.Reseeded())
   {
      Print("AutoFibo: history changed or gap reseeded; structure checkpoint rebuilt.");
      SetStatus("Auto: histori berubah; model diulang.");
   }
   if(result == FIBO_WAITING_PAIR)
   {
      if(copied < 500 && g_partial_attempts++ < 3) ScheduleAutoRetry(force);
      else g_last_auto_bar = bar;
      g_analysis_transient = false;
      SetStatus(g_auto_method == FIBO_MARKET_STRUCTURE
                ? "Market Structure: menunggu BOS; fibo sebelumnya dipertahankan."
                : "Auto: belum ada pasangan pivot terkonfirmasi.");
      return false;
   }
   g_partial_attempts = 0;
   string key = AutoPairKey(start, end);
   if(!force && key == g_auto_pair_key)
   {
      g_last_auto_bar = bar;
      if(g_auto.Reseeded()) SetStatus("Auto: histori berubah; model diulang; anchor tetap.");
      if(g_analysis_transient) { g_analysis_transient = false; SetStatus("Auto: data pulih; anchor tetap."); }
      return true; // Preserve manual edits until a genuinely different pair appears.
   }
   CFiboModel candidate; candidate.CopyFrom(g_model);
   if(!candidate.SetAnchors(start.time, start.price, end.time, end.price) || !g_chart.Draw(candidate))
   {
      if(g_model.Ready()) g_chart.Draw(g_model); else g_chart.ClearFibo();
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: gagal menggambar fibo. Klik Cari Swing untuk mencoba lagi.");
      return false;
   }
   g_model.CopyFrom(candidate);
   g_source = g_auto_method == FIBO_PIVOT ? ANCHOR_PIVOT : ANCHOR_STRUCTURE;
   g_edited = false; g_analysis_transient = false; UpdateSwingDisplay();
   g_auto_pair_key = key;
   g_last_auto_bar = bar;
   SetStatus(g_auto_method == FIBO_MARKET_STRUCTURE
             ? "Market Structure: fibo dari swing sebelum BOS ke ekstrem candle break."
             : "Auto: pasangan pivot terkonfirmasi. Anchor belum dikunci.");
   ChartRedraw(); // Geometry must update even when all preview values are unchanged.
   return true;
}

void OnTimer(void)
{
   if(!g_dialog_created || IsStopped() || g_dialog.Dragging() || g_left_down || g_panel_pressed) return;
   if(g_labels_pending && !g_model.Locked() && GetTickCount64() >= g_labels_retry_after) DrawStructureLabels();
   if(g_auto_retry_after == 0 || GetTickCount64() >= g_auto_retry_after)
   {
      bool force = g_auto_force_pending; g_auto_force_pending = false; g_auto_retry_after = 0;
      RefreshAutoSwing(force);
   }
   // Risk/quote refresh remains active even while locked or waiting for history.
   RefreshResults();
}
void ApplyPanelSettings(void)
{
   AutoFiboMethod method = g_dialog.Method(); int left = g_dialog.LeftBars(), right = g_dialog.RightBars();
   if(!IsValidAutoFiboSettings((int)_Period, left, right, method))
   { g_dialog.SetSettings(g_auto_method, g_left_bars, g_right_bars); SetStatus("Pengaturan tidak valid."); return; }
   if(method == g_auto_method && left == g_left_bars && right == g_right_bars) return;
   g_auto_method = method; g_left_bars = left; g_right_bars = right;
   g_auto.Configure(left, right); g_auto.ResetAnalysis(); ClearStructureLabels();
   g_last_auto_bar = 0; g_auto_pair_key = ""; g_auto_retry_after = 0; g_partial_attempts = 0;
   g_auto_force_pending = false; g_analysis_transient = false;
   g_dialog.SetSettings(method, left, right);
   if(g_model.Locked()) SetStatus("Pengaturan disimpan; anchor masih terkunci."); else RequestAutoSearch(true);
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_dialog_created || IsStopped()) return;
   bool minimized = g_dialog.IsMinimized();
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      bool down = (StringToInteger(sparam) & 1) != 0;
      if(down && !g_left_down && g_dialog.Contains((int)lparam, (int)dparam)) g_panel_pressed = true;
      if(!down) g_panel_pressed = false;
      g_left_down = down;
   }
   g_dialog.ChartEvent(id, lparam, dparam, sparam);
   if(IsStopped()) return;
   if(minimized && !g_dialog.IsMinimized()) RefreshResults();
   if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_CHART_CHANGE) return;
   if(id == CHARTEVENT_OBJECT_DELETE && sparam == g_chart.Name())
   {
      if(g_model.Ready() && !g_chart.HasFibo())
      {
         g_model.Clear(); g_source = ANCHOR_NONE; g_edited = false; g_auto_force_pending = false;
         g_auto_retry_after = 0; UpdateSwingDisplay(); RefreshResults(); SetStatus("Fibo dihapus; klik Cari Swing atau tunggu candle baru.");
      }
      return;
   }
   if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE) && sparam == g_chart.Name())
   { SyncFiboFromObject(); return; }
   if(g_dialog.TakeSettingsChange()) { ApplyPanelSettings(); return; }
   FiboAction action = g_dialog.TakeAction();
   if(action == FIBO_PANEL_RISK)
   {
      double percent = 0, previous = g_model.RiskPercent();
      if(!FiboParseNumber(g_dialog.RiskText(), percent) || !g_model.SetRiskPercent(percent))
      { if(g_dialog.RefreshRiskInput(g_model)) ChartRedraw(); SetStatus("Risk 0-100 persen, maksimal 8 desimal."); return; }
      bool changed = g_dialog.RefreshRiskInput(g_model);
      if(previous == g_model.RiskPercent()) { if(changed) ChartRedraw(); return; }
      RefreshResults(); SetStatus("Risk diperbarui untuk setiap level."); return;
   }
   if(action == FIBO_PANEL_SL)
   {
      int index = g_dialog.EditIndex(); if(index < 0 || index >= FIBO_RATIOS) return;
      string text = g_dialog.StopText(index); StringTrimLeft(text); StringTrimRight(text);
      double existing = g_model.StopPrice(index), stop = 0;
      if(text == (existing == EMPTY_VALUE ? "" : DoubleToString(existing, _Digits))) return;
      if(text == "") g_model.ResetStop(index);
      else if(!FiboParseNumber(text, stop) || !g_model.SetStop(index, stop))
      { if(g_dialog.RefreshStopInput(g_model, index)) ChartRedraw(); SetStatus("SL harus harga positif; kosong = awal swing."); return; }
      g_dialog.RefreshStopInput(g_model, index); RefreshResults(); ChartRedraw();
      SetStatus(text == "" ? "SL mengikuti awal swing." : "SL level diperbarui."); return;
   }
   if(action == FIBO_PANEL_LEVELS)
   {
      int mask = g_dialog.RatioMask(); if(mask == g_model.Mask()) return;
      CFiboModel candidate; candidate.CopyFrom(g_model); candidate.SetMask(mask);
      if(candidate.Ready() && !g_chart.Draw(candidate))
      {
         g_chart.Draw(g_model); UpdateSwingDisplay(); ChartRedraw(); SetStatus("Gagal mengubah level; pilihan dipulihkan."); return;
      }
      g_model.CopyFrom(candidate); UpdateSwingDisplay(); RefreshResults(); ChartRedraw(); return;
   }
   if(action == FIBO_PANEL_LOCK)
   {
      bool locked = g_dialog.AnchorLocked(); if(locked == g_model.Locked()) return;
      if(!g_chart.Lock(locked))
      { g_chart.Lock(g_model.Locked()); UpdateSwingDisplay(); ChartRedraw(); SetStatus("Gagal mengubah kunci anchor."); return; }
      g_model.SetLocked(locked); g_auto_force_pending = false; g_auto_retry_after = 0;
      if(locked) SetStatus("Anchor terkunci; analisis otomatis dijeda."); else RequestAutoSearch(false);
      ChartRedraw(); return;
   }
   if(action == FIBO_PANEL_DRAW)
   {
      if(g_model.Locked()) SetStatus("Lepas centang Kunci anchor untuk mencari swing."); else RequestAutoSearch(true);
      return;
   }
   if(action == FIBO_PANEL_RESET)
   {
      g_model.Clear(); g_source = ANCHOR_NONE; g_edited = false; g_analysis_transient = false;
      g_auto_force_pending = false; g_auto_retry_after = 0; g_chart.ClearFibo(); ClearStructureLabels();
      g_last_auto_bar = iTime(_Symbol, g_analysis_tf, 1); UpdateSwingDisplay(); RefreshResults(); ChartRedraw();
      SetStatus("Fibo dihapus; pencarian berikutnya pada candle baru atau Cari Swing."); return;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 27)
   { g_dialog.CancelDrag(); g_left_down = false; g_panel_pressed = false; }
}
