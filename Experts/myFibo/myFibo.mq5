#property strict
#property version "2.18"
#property description "Select two candle extremes to draw 50%, 61.8%, and 78.6% retracements."

#include <Fibo\Fibonacci.mqh>
#include "MyFiboDialog.mqh"
#include "MyFiboAuto.mqh"
#include "MyFiboChart.mqh"
#include "MyFiboState.mqh"

SelectionState g_state = IDLE;
CFibonacci g_fibo;
CMyFiboDialog g_dialog;
CMyFiboAuto g_auto;
CMyFiboChart g_chart;
CMyFiboState g_storage;
MyFiboAnchorSource g_anchor_source = ANCHOR_NONE;
bool g_anchor_edited = false, g_analysis_transient = false, g_labels_pending = false;
ulong g_labels_retry_after = 0;
int g_partial_attempts = 0;
datetime g_pick_time = 0;
double g_pick_price = 0;
string g_base_status = "";
ENUM_STRUCTURE_TREND g_structure_trend = STRUCTURE_UNCLEAR;
MyFiboMode g_mode = FIBO_MANUAL;
MyFiboAutoMethod g_auto_method = FIBO_PIVOT;
ENUM_TIMEFRAMES g_analysis_tf = PERIOD_CURRENT;
int g_left_bars = 2, g_right_bars = 2;
bool g_anchor_locked = false;
datetime g_last_auto_bar = 0;
string g_auto_pair_key = "";
bool g_auto_force_pending = false;
ulong g_auto_retry_after = 0;
bool g_last_status_selecting = false;
string g_prefix = "myFibo.";
datetime g_start_time;
double g_start_price;
datetime g_end_time;
double g_end_price;
bool g_has_swing = false;
bool g_dialog_created = false;
bool g_left_down = false;
bool g_panel_pressed = false;
ulong g_ignore_click_until = 0;
bool g_saved_mouse_move = false;
bool g_saved_object_create = false;
bool g_saved_object_delete = false;
bool g_saved_mouse_scroll_at_init = true;
bool g_saved_mouse_scroll = true;
bool g_selection_locked = false;
string g_status = "";
string g_attached_symbol = "";

void LockSelection(void)
{
   if(g_selection_locked)
      return;
   g_saved_mouse_scroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   g_selection_locked = true;
}

void UnlockSelection(void)
{
   if(!g_selection_locked)
      return;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, g_saved_mouse_scroll);
   g_selection_locked = false;
}

bool InPanel(const int x, const int y)
{
   return g_dialog_created && g_dialog.IsVisible() && g_dialog.Contains(x, y);
}

// These helpers only protect candle selection from GUI clicks. The native
// CAppDialog::ChartEvent driver receives every event without filtering.
void PreparePanelMouse(const int x, const int y, const string flags)
{
   bool down = (StringToInteger(flags) & 1) != 0;
   if(down && !g_left_down && InPanel(x, y))
   {
      g_panel_pressed = true;
      LockSelection();
   }
}

void FinishPanelMouse(const string flags)
{
   bool down = (StringToInteger(flags) & 1) != 0;
   if(!down && g_left_down && g_panel_pressed)
   {
      g_panel_pressed = false;
      g_ignore_click_until = GetTickCount64() + 250;
   }
   g_left_down = down;
}

void ShowStatus(void)
{
   bool selecting = g_state != IDLE;
   string message = g_base_status + (g_labels_pending ? " | Label: retry." : "");
   if(g_status == message && g_last_status_selecting == selecting) return;
   g_status = message; g_last_status_selecting = selecting;
   g_dialog.SetStatus(message, selecting);
}
void SetStatus(const string message) { g_base_status = message; ShowStatus(); }
void CancelSelection(const bool clear_preview = true)
{
   g_state = IDLE; g_pick_time = 0; g_pick_price = 0;
   if(clear_preview)
   {
      if(g_has_swing) UpdateSwingDisplay(); else g_dialog.ClearSwing();
   }
   if(!g_panel_pressed && !g_dialog.Dragging()) UnlockSelection();
   g_chart.ClearStart();
   SetStatus(g_mode == FIBO_MANUAL ? "Manual: klik Pilih Swing." : "Auto: klik Cari Swing.");
}
string CheckpointContext(void)
{
   return "1|" + g_attached_symbol + "|" + IntegerToString((int)g_analysis_tf)
          + "|" + IntegerToString(g_left_bars) + "|" + IntegerToString(g_right_bars);
}
bool SaveChartSnapshot(void)
{
   MyFiboSnapshot snapshot;
   snapshot.state = g_state;
   snapshot.has_swing = g_has_swing && g_chart.HasFibo();
   snapshot.start_time = g_start_time; snapshot.start_price = g_start_price;
   snapshot.end_time = g_end_time; snapshot.end_price = g_end_price;
   if(snapshot.has_swing && !g_anchor_locked && g_state == IDLE)
   {
      datetime first, last; double a, b; CFibonacci check;
      if(g_chart.ReadFibo(first, a, last, b) && check.SetAnchors(a, b))
      { snapshot.start_time = first; snapshot.start_price = a; snapshot.end_time = last; snapshot.end_price = b; }
   }
   snapshot.status = g_base_status; snapshot.mode = g_mode; snapshot.timeframe = g_analysis_tf;
   snapshot.left = g_left_bars; snapshot.right = g_right_bars;
   snapshot.anchor_locked = g_anchor_locked;
   snapshot.auto_bar = g_labels_pending ? 0 : g_last_auto_bar;
   snapshot.auto_key = g_auto_pair_key; snapshot.auto_force_pending = g_auto_force_pending;
   snapshot.structure_trend = g_structure_trend; snapshot.auto_method = g_auto_method;
   snapshot.anchor_source = g_anchor_source; snapshot.anchor_edited = g_anchor_edited;
   snapshot.pick_time = g_pick_time; snapshot.pick_price = g_pick_price;
   snapshot.transient_status = g_analysis_transient;
   return g_storage.SaveCheckpoint(g_auto, CheckpointContext()) && g_storage.Write(snapshot, g_attached_symbol);
}
bool ReadChartSnapshot(MyFiboSnapshot &snapshot) { return g_storage.Read(snapshot, _Symbol); }

void RestoreChartSnapshot(const MyFiboSnapshot &snapshot)
{
   g_anchor_source = (MyFiboAnchorSource)snapshot.anchor_source;
   g_anchor_edited = snapshot.anchor_edited; g_analysis_transient = snapshot.transient_status;
   g_pick_time = snapshot.pick_time; g_pick_price = snapshot.pick_price;
   g_mode = (MyFiboMode)snapshot.mode;
   g_auto_method = (MyFiboAutoMethod)snapshot.auto_method;
   g_analysis_tf = (ENUM_TIMEFRAMES)_Period;
   g_left_bars = snapshot.left; g_right_bars = snapshot.right;
   g_anchor_locked = snapshot.anchor_locked;
   g_last_auto_bar = snapshot.auto_bar; g_auto_pair_key = snapshot.auto_key;
   g_auto_force_pending = snapshot.auto_force_pending;
   g_auto_retry_after = 0;
   g_state = (SelectionState)snapshot.state;
   g_start_time = snapshot.start_time;
   g_start_price = snapshot.start_price;
   g_end_time = snapshot.end_time;
   g_end_price = snapshot.end_price;
   g_has_swing = snapshot.has_swing
                 && g_chart.HasFibo()
                 && g_fibo.SetAnchors(g_start_price, g_end_price);
   g_dialog.ClearSwing();
   if(g_state == SELECT_END)
   { g_dialog.ClearSwing(); g_dialog.SetSwingStart(g_pick_price); }
   else if(g_has_swing) UpdateSwingDisplay();
   if(g_state != IDLE)
      LockSelection();
   g_dialog.SetSettings(g_mode, g_left_bars, g_right_bars, g_anchor_locked, g_auto_method);
   if(g_has_swing && g_anchor_locked) RestoreValidSwing();
   else ApplyAnchorLock();
   g_structure_trend = (ENUM_STRUCTURE_TREND)snapshot.structure_trend;
   g_dialog.SetStructureTrend(StructureTrendName(g_structure_trend));
   SetStatus(snapshot.status);
}

int OnInit(void)
{
   MyFiboSnapshot snapshot;
   bool restoring = ReadChartSnapshot(snapshot);
   g_attached_symbol = _Symbol;
   g_mode = restoring ? (MyFiboMode)snapshot.mode : FIBO_MANUAL;
   g_auto_method = restoring ? (MyFiboAutoMethod)snapshot.auto_method : FIBO_PIVOT;
   g_analysis_tf = (ENUM_TIMEFRAMES)_Period;
   g_left_bars = restoring ? snapshot.left : 2;
   g_right_bars = restoring ? snapshot.right : 2;
   g_anchor_locked = restoring && snapshot.anchor_locked;
   g_last_auto_bar = restoring ? snapshot.auto_bar : 0;
   g_auto_pair_key = restoring ? snapshot.auto_key : "";
   g_auto_force_pending = restoring && snapshot.auto_force_pending;
   g_auto_retry_after = 0;
   g_structure_trend = restoring ? (ENUM_STRUCTURE_TREND)snapshot.structure_trend : STRUCTURE_UNCLEAR;
   g_status = ""; g_base_status = "";
   g_anchor_source = ANCHOR_NONE; g_anchor_edited = false; g_analysis_transient = false;
   g_labels_pending = false; g_labels_retry_after = 0; g_partial_attempts = 0;
   g_pick_time = 0; g_pick_price = 0;
   g_chart.ResetCache(); g_auto.ResetAnalysis();
   g_last_status_selecting = false;
   g_state = IDLE;
   g_has_swing = false;
   g_left_down = false;
   g_panel_pressed = false;
   g_start_time = 0;
   g_start_price = 0.0;
   g_end_time = 0;
   g_end_price = 0.0;
   // Preserve drawings only for a matching-symbol timeframe handoff.
   if(!restoring)
      g_chart.ClearAll();
   g_saved_mouse_move = (bool)ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE);
   g_saved_object_create = (bool)ChartGetInteger(0, CHART_EVENT_OBJECT_CREATE);
   g_saved_object_delete = (bool)ChartGetInteger(0, CHART_EVENT_OBJECT_DELETE);
   g_saved_mouse_scroll_at_init = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
   // Customize this instance only; the shared class keeps its default levels.
   double levels[] = {0.5, 0.618, 0.786};
   if(!g_fibo.SetLevels(levels))
   {
      Print("myFibo: could not configure Fibonacci levels.");
      return INIT_FAILED;
   }
   if(!g_auto.Configure(g_left_bars, g_right_bars))
      return INIT_FAILED;
   g_dialog.Minimized(false);
   if(!g_dialog.Create(0, g_prefix + "Panel", 0, 12, 24, 592, 464))
      return INIT_FAILED;
   g_dialog_created = true;
   g_dialog.SetSettings(g_mode, g_left_bars, g_right_bars, g_anchor_locked, g_auto_method);
   if(!g_dialog.Run())
      return INIT_FAILED;
   if(restoring)
   {
      // Native serialization restores position, expanded/minimized geometry,
      // and the minimize button together, without a new manual GUI driver.
      g_dialog.IniFileLoad();
      RestoreChartSnapshot(snapshot);
      if(snapshot.timeframe != (int)_Period)
      {
         // A checkpoint is specific to its candle timeframe. Keep completed
         // anchors/selection, but rebuild Auto from the new chart's closed bars.
         g_auto.ResetAnalysis(); ClearStructureLabels();
         g_last_auto_bar = 0; g_auto_pair_key = ""; g_auto_retry_after = 0;
         g_auto_force_pending = g_mode == FIBO_AUTO && !g_anchor_locked;
         g_analysis_transient = false;
         if(g_mode == FIBO_AUTO)
            SetStatus(g_anchor_locked ? "TF mengikuti chart; anchor tetap terkunci."
                                      : "TF mengikuti chart; analisis Auto dijadwalkan.");
      }
      else if(!g_storage.LoadCheckpoint(g_auto, CheckpointContext()))
      {
         g_last_auto_bar = 0;
         if(g_mode == FIBO_AUTO && !g_anchor_locked)
         { g_analysis_transient = true; SetStatus("Auto: checkpoint tidak tersedia; analisis diulang."); }
      }
      g_storage.ClearCheckpoint();
      g_storage.ConsumeSnapshot();
   }
   else
      CancelSelection();
   if(!EventSetTimer(1))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_dialog_created)
      g_dialog.CancelDrag();
   bool preserving = reason == REASON_CHARTCHANGE && g_dialog_created
                     && SaveChartSnapshot();
   // CAppDialog saves its native geometry through IniFileSave in Destroy.
   g_dialog.Destroy(reason);
   g_dialog_created = false;
   g_panel_pressed = false;
   UnlockSelection();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, g_saved_mouse_move);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, g_saved_object_create);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, g_saved_object_delete);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, g_saved_mouse_scroll_at_init);
   if(!preserving)
      g_chart.ClearAll();
   ChartRedraw();
}

bool CandleAnchor(const int x, const int y, datetime &time, double &price)
{
   return g_chart.PickCandle(x, y, time, price);
}
void UpdateSwingDisplay(void)
{
   g_dialog.SetSwingStart(g_start_price);
   g_dialog.SetSwingEnd(g_end_price);
   g_dialog.SetDirection(g_end_price > g_start_price);
   g_dialog.SetLevels(g_fibo.LevelPrice(0), g_fibo.LevelPrice(1), g_fibo.LevelPrice(2));
   string source = g_anchor_source == ANCHOR_MANUAL ? "Manual" : (g_anchor_source == ANCHOR_PIVOT ? "Pivot"
                   : (g_anchor_source == ANCHOR_STRUCTURE ? "Market Structure" : (g_has_swing ? "Unknown" : "-")));
   g_dialog.SetAnchorSource(source + (g_anchor_edited ? " (edit)" : ""));
}

// Called only after an object drag ends or its Properties dialog is applied.
// No object reads or Fibonacci calculations are done for GUI mouse movement.
bool SyncFiboFromObject(void)
{
   if(!g_has_swing)
      return false;
   if(g_anchor_locked)
   {
      RestoreValidSwing();
      SetStatus("Anchor terkunci. Lepas centang untuk mengedit.");
      return false;
   }
   datetime start_time = 0, end_time = 0;
   double start_price = 0.0, end_price = 0.0;
   bool ok = g_chart.ReadFibo(start_time, start_price, end_time, end_price)
             && g_fibo.SetAnchors(start_price, end_price);
   if(ok) ok = g_chart.UpdateLevels(g_fibo);
   if(!ok)
   {
      // Invalid edits (including equal prices) return to the last valid swing.
      RestoreValidSwing();
      SetStatus("Invalid Fibonacci edit. Previous swing restored.");
      return false;
   }
   g_start_time = (datetime)start_time;
   g_start_price = start_price;
   g_end_time = (datetime)end_time;
   g_end_price = end_price;
   g_anchor_edited = true; g_analysis_transient = false;
   UpdateSwingDisplay();
   SetStatus("Fibo diperbarui. Kunci anchor tetap mengikuti checkbox.");
   return true;
}

bool DrawSwing(const datetime end_time, const double end_price)
{
   if(!g_fibo.SetAnchors(g_start_price, end_price)
      || !g_chart.DrawFibo(g_fibo, g_start_time, g_start_price, end_time, end_price, g_anchor_locked)) return false;
   g_end_time = end_time; g_end_price = end_price; g_has_swing = true;
   UpdateSwingDisplay(); return true;
}
bool ApplyAnchorLock(void) { return g_chart.LockFibo(g_anchor_locked); }
void RestoreValidSwing(void)
{
   if(g_fibo.SetAnchors(g_start_price, g_end_price))
      g_chart.DrawFibo(g_fibo, g_start_time, g_start_price, g_end_time, g_end_price, g_anchor_locked);
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
   if(g_mode != FIBO_AUTO || g_anchor_locked) return;
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
   if(g_mode != FIBO_AUTO || g_anchor_locked || g_state != IDLE) return false;
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
   SwingPoint start, end;
   MyFiboAnalysisResult result = g_auto.Analyze(closed_bars, start, end, g_auto_method, force);
   if(result == FIBO_ANALYSIS_ERROR)
   {
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: " + g_auto.LastError()); return false;
   }
   // Optional labels retry independently; a label error cannot block Fibo.
   DrawStructureLabels();
   if(g_auto.Reseeded())
   {
      Print("myFibo: history changed or gap reseeded; structure checkpoint rebuilt.");
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
   datetime saved_time = g_start_time;
   double saved_price = g_start_price;
   bool had_swing = g_has_swing && g_chart.HasFibo();
   g_start_time = start.time; g_start_price = start.price;
   if(!DrawSwing(end.time, end.price))
   {
      g_start_time = saved_time; g_start_price = saved_price;
      g_has_swing = had_swing;
      if(had_swing) RestoreValidSwing();
      ScheduleAutoRetry(force); g_analysis_transient = true;
      SetStatus("Auto: gagal menggambar fibo. Klik Cari Swing untuk mencoba lagi.");
      return false;
   }
   g_anchor_source = g_auto_method == FIBO_PIVOT ? ANCHOR_PIVOT : ANCHOR_STRUCTURE;
   g_anchor_edited = false; g_analysis_transient = false; UpdateSwingDisplay();
   g_auto_pair_key = key;
   g_last_auto_bar = bar;
   SetStatus(g_auto_method == FIBO_MARKET_STRUCTURE
             ? "Market Structure: fibo dari swing sebelum BOS ke ekstrem candle break."
             : "Auto: pasangan pivot terkonfirmasi. Anchor belum dikunci.");
   return true;
}

void OnTimer(void)
{
   if(!g_dialog_created || IsStopped() || g_dialog.Dragging() || g_left_down || g_panel_pressed)
      return;
   if(g_labels_pending && !g_anchor_locked && GetTickCount64() >= g_labels_retry_after)
      DrawStructureLabels();
   if(g_auto_retry_after != 0 && GetTickCount64() < g_auto_retry_after)
      return;
   bool force = g_auto_force_pending;
   g_auto_force_pending = false;
   g_auto_retry_after = 0;
   RefreshAutoSwing(force);
}

void ApplyPanelSettings(void)
{
   MyFiboMode mode = g_dialog.Mode();
   MyFiboAutoMethod method = g_dialog.AutoMethod();
   ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)_Period;
   int left = g_dialog.LeftBars(), right = g_dialog.RightBars();
   if(!IsValidMyFiboSettings(mode, timeframe, left, right, method))
   {
      g_dialog.SetSettings(g_mode, g_left_bars, g_right_bars, g_anchor_locked, g_auto_method);
      SetStatus("Pengaturan tidak valid.");
      return;
   }
   if(mode == g_mode && timeframe == g_analysis_tf && left == g_left_bars && right == g_right_bars && method == g_auto_method)
      return;
   if(g_state != IDLE) CancelSelection();
   if(timeframe != g_analysis_tf) g_auto.ResetAnalysis();
   g_analysis_transient = false; g_partial_attempts = 0;
   g_mode = mode; g_auto_method = method; g_analysis_tf = timeframe; g_left_bars = left; g_right_bars = right;
   g_auto.Configure(left, right);
   ClearStructureLabels();
   g_last_auto_bar = 0; g_auto_pair_key = "";
   g_auto_force_pending = false; g_auto_retry_after = 0;
   g_dialog.SetSettings(g_mode, left, right, g_anchor_locked, g_auto_method);
   if(g_anchor_locked) SetStatus("Pengaturan disimpan. Anchor masih terkunci.");
   else if(g_mode == FIBO_AUTO) RequestAutoSearch(true);
   else SetStatus("Manual: klik Pilih Swing atau edit objek fibo.");
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(!g_dialog_created || IsStopped())
      return;
   bool was_dragging = g_dialog.Dragging();
   bool was_left_down = g_left_down;
   if(id == CHARTEVENT_MOUSE_MOVE)
      PreparePanelMouse((int)lparam, (int)dparam, sparam);

   // Exactly one dispatch, including mouse/focus/priority/custom events.
   // CAppDialog owns mouse routing and redraw after handled events.
   g_dialog.ChartEvent(id, lparam, dparam, sparam);
   if(IsStopped())
      return;

   if(id == CHARTEVENT_MOUSE_MOVE)
      FinishPanelMouse(sparam);
   if(was_dragging && !g_dialog.Dragging())
      g_ignore_click_until = GetTickCount64() + 250;
   if(g_state == IDLE && !g_panel_pressed && !g_dialog.Dragging())
      UnlockSelection();
   // Hold the chart still while selecting candle anchors, even if the native
   // dialog's mouse handling has changed scrolling after a GUI interaction.
   if(g_state != IDLE
      && ((id == CHARTEVENT_MOUSE_MOVE && was_left_down && !g_left_down)
          || (was_dragging && !g_dialog.Dragging())))
      ChartSetInteger(0, CHART_MOUSE_SCROLL, false);

   if(id == CHARTEVENT_OBJECT_DELETE && sparam == g_prefix + "Swing.Fibo")
   {
      // Our own Reset/new-selection already clears this flag before deletion.
      if(g_has_swing)
      {
         g_has_swing = false; g_anchor_source = ANCHOR_NONE; g_anchor_edited = false;
         g_dialog.ClearSwing();
         g_auto_force_pending = false; g_auto_retry_after = 0;
         SetStatus("Objek fibo dihapus. Klik Pilih/Cari Swing untuk menggambar kembali.");
      }
      return;
   }
   if((id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
      && sparam == g_prefix + "Swing.Fibo")
   {
      SyncFiboFromObject();
      return;
   }
   if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_CHART_CHANGE)
      return;
   MyFiboPanelAction action = g_dialog.TakeAction();
   if(action == PANEL_SETTINGS)
   {
      ApplyPanelSettings();
      return;
   }
   if(action == PANEL_LOCK)
   {
      bool locked = g_dialog.AnchorLocked();
      if(locked == g_anchor_locked) return;
      bool previous = g_anchor_locked;
      g_anchor_locked = locked;
      if(!ApplyAnchorLock())
      {
         g_anchor_locked = previous;
         ApplyAnchorLock();
         g_dialog.SetSettings(g_mode, g_left_bars, g_right_bars, previous, g_auto_method);
         SetStatus("Gagal mengubah kunci anchor. Status sebelumnya dipulihkan.");
         return;
      }
      if(locked && g_state != IDLE) CancelSelection();
      if(locked) { g_auto_force_pending = false; g_auto_retry_after = 0; }
      SetStatus(locked ? "Anchor terkunci; pembaruan Auto dihentikan."
                       : "Anchor bebas diedit; Auto aktif sesuai mode.");
      if(!locked && g_mode == FIBO_AUTO) RequestAutoSearch(false);
      return;
   }
   if(action == PANEL_DRAW)
   {
      if(g_anchor_locked)
      {
         SetStatus("Lepas centang Kunci anchor sebelum memilih swing.");
         return;
      }
      if(g_mode == FIBO_AUTO)
      {
         RequestAutoSearch(true);
         return;
      }
      if(g_state != IDLE)
         CancelSelection();
      else
      {
         g_pick_time = 0; g_pick_price = 0;
         g_chart.ClearStart();
         g_dialog.ClearSwing();
         LockSelection();
         g_state = SELECT_START;
         SetStatus("Select swing start: click near a candle high or low. Esc cancels.");
      }
      return;
   }
   if(action == PANEL_RESET)
   {
      CancelSelection();
      g_dialog.ClearSwing();
      g_has_swing = false; g_anchor_source = ANCHOR_NONE; g_anchor_edited = false;
      g_analysis_transient = false;
      g_auto_force_pending = false; g_auto_retry_after = 0;
      g_chart.ClearFibo();
      ClearStructureLabels();
      if(g_mode == FIBO_AUTO) g_last_auto_bar = iTime(_Symbol, g_analysis_tf, 1);
      SetStatus("Fibo dihapus. Klik Pilih/Cari Swing untuk menggambar kembali.");
      return;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 27)
   {
      g_dialog.CancelDrag();
      g_panel_pressed = false;
      g_ignore_click_until = GetTickCount64() + 250;
      CancelSelection();
      return;
   }
   if(id != CHARTEVENT_CLICK || g_state == IDLE || g_mode != FIBO_MANUAL || g_anchor_locked)
      return;
   int x = (int)lparam;
   int y = (int)dparam;
   // Object clicks can also generate chart clicks. Never use the UI as an anchor.
   if(g_panel_pressed || g_dialog.Dragging()
      || GetTickCount64() < g_ignore_click_until || InPanel(x, y))
      return;
   datetime bar_time;
   double price;
   if(!CandleAnchor(x, y, bar_time, price))
   {
      SetStatus("Click a candle in the main price chart.");
      return;
   }
   if(g_state == SELECT_START)
   {
      g_pick_time = bar_time;
      g_pick_price = price;
      if(!g_chart.MarkStart(bar_time, price))
      {
         SetStatus("Could not mark start. Select the start again.");
         return;
      }
      g_dialog.SetSwingStart(price);
      g_state = SELECT_END;
      SetStatus("Awal: " + DoubleToString(price, _Digits) + ". Pilih titik akhir swing.");
      return;
   }
   if(price == g_pick_price)
   {
      SetStatus("End must have a different price. Select swing end again.");
      return;
   }
   datetime saved_time = g_start_time; double saved_price = g_start_price;
   g_start_time = g_pick_time; g_start_price = g_pick_price;
   if(!DrawSwing(bar_time, price))
   {
      g_start_time = saved_time; g_start_price = saved_price;
      if(g_has_swing) RestoreValidSwing();
      SetStatus("Drawing failed. Select swing end again; see Experts log.");
      Print("myFibo drawing error: ", GetLastError());
      return;
   }
   g_anchor_source = ANCHOR_MANUAL; g_anchor_edited = false; g_analysis_transient = false;
   UpdateSwingDisplay();
   CancelSelection(false);
   SetStatus("Manual: fibo digambar. Double-click untuk mengedit anchor.");
}
