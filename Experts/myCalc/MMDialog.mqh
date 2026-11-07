//+------------------------------------------------------------------+
//|                                                     MMDialog.mqh |
//|                                                     will_santoso |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
//#include <Custom/Class/Fibonacci.mqh>
#include <Trade/Trade.mqh>
#include "MMConfig.mqh"
#include "MMNames.mqh"
#include "MMCalculator.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CMMDialog : public CAppDialog
{
private:
   CTrade m_ct;
   double m_inpRiskPct;
   double m_riskUSD;
   double m_defRiskPct;
   bool m_autoSL;

   //Button
   CButton m_calcButton;
   CButton m_resetButton;
   //Label
   CLabel m_EntryLabel;
   CLabel m_RiskLabel;
   CLabel m_RiskUSDLabel;
   CLabel m_SLLabel;
   CLabel m_TPLabel;
   CLabel m_RRLabel;
   CLabel m_LotLabel;
   CLabel m_LotValueLabel;
   CLabel m_LimitLabel;
   CLabel m_LimitValueLabel;
   //Edit
   CEdit m_EntryEdit;
   CEdit m_RiskEdit;
   CEdit m_SLEdit;
   CEdit m_TPEdit;
   CEdit m_RREdit;

public:
   CMMDialog();
   CMMDialog(const double &inpRiskPct);
   ~CMMDialog();

   //--- create
   virtual bool Create(const long chart,
                       const string name,
                       const int subwin,
                       const int x1,
                       const int y1,
                       const int x2,
                       const int y2);
   //--- chart event handler
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

protected:
   bool              CreateButton(CButton &cbutt,
                                  const long chart,
                                  const string name,
                                  const int subwin,
                                  const string text,
                                  const int x1,
                                  const int y1,
                                  const int x2,
                                  const int y2);
   bool              CreateEdit(CEdit &cedit,
                                const long chart,
                                const string name,
                                const int subwin,
                                const string text,
                                const int x1,
                                const int y1,
                                const int x2,
                                const int y2,
                                bool readonly,
                                ENUM_ALIGN_MODE txtAlign = ALIGN_CENTER);
   bool              CreateLabel(CLabel &clabel,
                                 const long chart,
                                 const string name,
                                 const int subwin,
                                 const string text,
                                 const int x1,
                                 const int y1,
                                 const int x2,
                                 const int y2);

   MMInputs ReadInputs();
   bool UpdateRiskUSD();
   bool SyncEditFromLine(const string line_name);
   bool SyncLineFromEdit(const string edit_name);
   bool ApplyRewardRiskToTP();
   bool UpdateInfoLabels(bool update_rr = true);
   bool ResetPanel();
   double DefaultSL(const double entry);
   bool ApplyDefaultSLForEntry();
   string OrderComment(const MMInputs &inputs,
                       const double entry,
                       const double sl,
                       const double tp);
   bool PreparePendingOrder(const MMInputs &inputs,
                            ENUM_ORDER_TYPE &order_type,
                            double &entry,
                            double &sl,
                            double &tp,
                            bool &entry_adjusted,
                            string &error_message);
   bool PlacePendingOrder(const MMInputs &inputs);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMMDialog::CMMDialog()
{
   m_defRiskPct = 0.0;
   m_inpRiskPct = 0.0;
   m_riskUSD = 0.0;
   m_autoSL = true;
}

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMMDialog::CMMDialog(const double &inpRiskPct)
{
//--- set user input
   m_defRiskPct = inpRiskPct;
   m_inpRiskPct = m_defRiskPct;
   m_riskUSD = m_inpRiskPct / 100 * AccountInfoDouble(ACCOUNT_BALANCE);
   m_autoSL = true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CMMDialog::~CMMDialog()
{
   ObjectsDeleteAll(0, MM_OBJECT_PREFIX);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   int panW = x2 - x1;
   int panH = y2 - y1;

   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;

//--- create lines
   double default_entry = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double default_sl = DefaultSL(default_entry);
   HLineCreate(0, "Entry", default_entry, clrBlue);
   HLineCreate(0, "SL", default_sl, clrOrangeRed);
   HLineCreate(0, "TP", 0.0, clrGreen);
   
//--- calculate button
   if(!CreateButton(m_calcButton,
                    chart,
                    "calc",
                    subwin,
                    "Calculate",
                    INDENT_LEFT,
                    INDENT_TOP,
                    INDENT_LEFT + BUTTON_WIDTH,
                    INDENT_TOP + BUTTON_HEIGHT))
      return false;

//--- reset button
   if(!CreateButton(m_resetButton,
                    chart,
                    "reset",
                    subwin,
                    "Reset",
                    INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                    INDENT_TOP,
                    (INDENT_LEFT + BUTTON_WIDTH) * 2 + CONTROLS_GAP_X,
                    INDENT_TOP + BUTTON_HEIGHT))
      return false;

//--- risk label
   if(!CreateLabel(m_RiskLabel,
                   chart,
                   "Risk",
                   subwin,
                   "Risk %",
                   INDENT_LEFT,
                   INDENT_TOP + BUTTON_HEIGHT + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   INDENT_TOP + BUTTON_HEIGHT + CONTROLS_GAP_Y))
      return false;

//--- risk edit
   if(!CreateEdit(m_RiskEdit,
                  chart,
                  "Risk",
                  subwin,
                  DoubleToString(m_inpRiskPct, 2),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  INDENT_TOP + BUTTON_HEIGHT + CONTROLS_GAP_Y,
                  (INDENT_LEFT + BUTTON_WIDTH) * 2 + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- riskUSD label
   if(!CreateLabel(m_RiskUSDLabel,
                   chart,
                   "RiskUSD",
                   subwin,
                   StringFormat("$ %.2f", m_riskUSD),
                   (INDENT_LEFT + BUTTON_WIDTH) * 2 + CONTROLS_GAP_X * 2,
                   INDENT_TOP + BUTTON_HEIGHT + CONTROLS_GAP_Y * 2,
                   (INDENT_LEFT + BUTTON_WIDTH) * 3 + CONTROLS_GAP_X,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y))
      return false;

//--- Entry label
   if(!CreateLabel(m_EntryLabel,
                   chart,
                   "Entry",
                   subwin,
                   "ENTRY",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y))
      return false;

//--- Entry edit
   if(!CreateEdit(m_EntryEdit,
                  chart,
                  "Entry",
                  subwin,
                  DoubleToString(default_entry, Digits()),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- SL label
   if(!CreateLabel(m_SLLabel,
                   chart,
                   "SL",
                   subwin,
                   "SL",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y))
      return false;

//--- SL edit
   if(!CreateEdit(m_SLEdit,
                  chart,
                  "SL",
                  subwin,
                  DoubleToString(default_sl, Digits()),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- TP label
   if(!CreateLabel(m_TPLabel,
                   chart,
                   "TP",
                   subwin,
                   "TP",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y))
      return false;

//--- TP edit
   if(!CreateEdit(m_TPEdit,
                  chart,
                  "TP",
                  subwin,
                  "0.0",
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- RR label
   if(!CreateLabel(m_RRLabel,
                   chart,
                   "RR",
                   subwin,
                   "RR",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- RR edit
   if(!CreateEdit(m_RREdit,
                   chart,
                   "RR",
                   subwin,
                   "-",
                   INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   panW - BUTTON_WIDTH - INDENT_RIGHT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   false))
      return false;

//--- lot label
   if(!CreateLabel(m_LotLabel,
                   chart,
                   "Lot",
                   subwin,
                   "LOT",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- lot value label
   if(!CreateLabel(m_LotValueLabel,
                   chart,
                   "LotValue",
                   subwin,
                   "-",
                   INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   panW - BUTTON_WIDTH - INDENT_RIGHT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y))
      return false;

//--- limit status label
   if(!CreateLabel(m_LimitLabel,
                   chart,
                   "Limit",
                   subwin,
                   "Limit",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y))
      return false;

//--- limit status value label
   if(!CreateLabel(m_LimitValueLabel,
                   chart,
                   "LimitValue",
                   subwin,
                   "-",
                   INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y,
                   panW - BUTTON_WIDTH - INDENT_RIGHT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 8 + CONTROLS_GAP_Y))
      return false;

   if(!UpdateInfoLabels())
      return false;

   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG && StringFind(sparam, ".Line") != -1)
   {
      //--- if a line is dragged

      if(!SyncEditFromLine(sparam))
         return false;
      if(sparam == MMLineName("Entry") && !ApplyDefaultSLForEntry())
         return false;
      if(sparam == MMLineName("SL"))
         m_autoSL = false;
      if(!UpdateInfoLabels())
         return false;
      return true;
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      //--- check if EDIT object is modified

      ResetLastError();
      if(sparam == MMEditName("Risk"))
      {
         //--- if Risk Edit change, change m_inpRiskPct and m_riskUSD

         if(!UpdateRiskUSD())
            return false;
      }
      else if(sparam == MMEditName("RR"))
      {
         if(!ApplyRewardRiskToTP())
            return false;
      }
      else if(StringFind(sparam, ".Edit") != -1)
      {
         //--- change entry/SL/TP EDIT to move line

         if(!SyncLineFromEdit(sparam))
            return false;
         if(sparam == MMEditName("Entry") && !ApplyDefaultSLForEntry())
            return false;
         if(sparam == MMEditName("SL"))
            m_autoSL = false;
      }
      if(!UpdateInfoLabels())
         return false;
      return true;
   }
   else if (id == ON_CLICK + CHARTEVENT_CUSTOM && StringFind(sparam, ".Button") != -1)
   {
      //--- check if any BUTTON is pressed

      if(sparam == MMButtonName("calc"))
      {
         //--- check if calc BUTTON is pressed
         MMInputs inputs = ReadInputs();
         if(!PlacePendingOrder(inputs))
            return false;
      }
      else if(sparam == MMButtonName("reset"))
      {
         //--- check if reset BUTTON is pressed
         if(!ResetPanel())
            return false;
         return true;
      }
      return true;
   }
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Create buttons                                                   |
//+------------------------------------------------------------------+
bool CMMDialog::CreateButton(CButton &cbutt,
                             const long chart,
                             const string name,
                             const int subwin,
                             const string text,
                             const int x1,
                             const int y1,
                             const int x2,
                             const int y2)
{
   if(!cbutt.Create(chart, MMButtonName(name), subwin, x1, y1, x2, y2))
      return false;
   if(!cbutt.Text(text))
      return false;
   if(!Add(cbutt))
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| Create edits                                                     |
//+------------------------------------------------------------------+
bool CMMDialog::CreateEdit(CEdit &cedit,
                           const long chart,
                           const string name,
                           const int subwin,
                           const string text,
                           const int x1,
                           const int y1,
                           const int x2,
                           const int y2,
                           bool readonly,
                           ENUM_ALIGN_MODE txtAlign = ALIGN_CENTER)
{
   if(!cedit.Create(chart, MMEditName(name), subwin, x1, y1, x2, y2))
      return(false);
   if(!cedit.ReadOnly(readonly))
      return(false);
   if(!cedit.TextAlign(txtAlign))
      return(false);
   if(!cedit.Text(text))
      return(false);
   if(!Add(cedit))
      return(false);
   return true;
}

//+------------------------------------------------------------------+
//| Create labels                                                    |
//+------------------------------------------------------------------+
bool CMMDialog::CreateLabel(CLabel &clabel,
                            const long chart,
                            const string name,
                            const int subwin,
                            const string text,
                            const int x1,
                            const int y1,
                            const int x2,
                            const int y2)
{
   if(!clabel.Create(chart, MMLabelName(name), subwin, x1, y1, x2, y2))
      return(false);
   if(!clabel.Text(text))
      return(false);
   if(!Add(clabel))
      return(false);
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MMInputs CMMDialog::ReadInputs()
{
   MMInputs inputs;
   inputs.risk_pct = StringToDouble(ObjectGetString(0, MMEditName("Risk"), OBJPROP_TEXT));
   inputs.entry = StringToDouble(ObjectGetString(0, MMEditName("Entry"), OBJPROP_TEXT));
   inputs.sl = StringToDouble(ObjectGetString(0, MMEditName("SL"), OBJPROP_TEXT));
   inputs.tp = StringToDouble(ObjectGetString(0, MMEditName("TP"), OBJPROP_TEXT));
   inputs.rr = StringToDouble(ObjectGetString(0, MMEditName("RR"), OBJPROP_TEXT));
   return inputs;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::UpdateRiskUSD()
{
   m_inpRiskPct = StringToDouble(ObjectGetString(0, MMEditName("Risk"), OBJPROP_TEXT));
   m_riskUSD = m_inpRiskPct / 100 * AccountInfoDouble(ACCOUNT_BALANCE);

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("RiskUSD"), OBJPROP_TEXT, StringFormat("$ %.2f", m_riskUSD)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::SyncEditFromLine(const string line_name)
{
   string edit_name = line_name;
   StringReplace(edit_name, ".Line", ".Edit");

   ResetLastError();
   if(!ObjectSetString(0, edit_name, OBJPROP_TEXT, DoubleToString(ObjectGetDouble(0, line_name, OBJPROP_PRICE), Digits())))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::SyncLineFromEdit(const string edit_name)
{
   string line_name = edit_name;
   StringReplace(line_name, ".Edit", ".Line");

   ResetLastError();
   if(!ObjectSetDouble(0, line_name, OBJPROP_PRICE, StringToDouble(ObjectGetString(0, edit_name, OBJPROP_TEXT))))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::ApplyRewardRiskToTP()
{
   MMInputs inputs = ReadInputs();
   double tp_val = 0.0;

   if(!MMTPFromRewardRisk(inputs.entry, inputs.sl, inputs.rr, tp_val))
      return true;

   string tp_text = DoubleToString(tp_val, Digits());

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("TP"), OBJPROP_TEXT, tp_text))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   ResetLastError();
   if(!ObjectSetDouble(0, MMLineName("TP"), OBJPROP_PRICE, tp_val))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::UpdateInfoLabels(bool update_rr)
{
   MMInputs inputs = ReadInputs();

   if(update_rr)
   {
      ResetLastError();
      if(!ObjectSetString(0, MMEditName("RR"), OBJPROP_TEXT, MMRewardRiskText(inputs.entry, inputs.sl, inputs.tp)))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }
   }

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("LotValue"), OBJPROP_TEXT, MMLotText(inputs.entry, inputs.sl, inputs.risk_pct)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("LimitValue"), OBJPROP_TEXT, MMLimitStatusText(inputs.entry, inputs.sl, inputs.risk_pct)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::ResetPanel()
{
   m_inpRiskPct = m_defRiskPct;
   m_riskUSD = m_inpRiskPct / 100 * AccountInfoDouble(ACCOUNT_BALANCE);
   m_autoSL = true;

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("RiskUSD"), OBJPROP_TEXT, StringFormat("$ %.2f", m_riskUSD)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   string target_edit[] = {"Risk", "Entry", "SL", "TP"};
   for(int i = 0; i < ArraySize(target_edit); i++)
   {
      ResetLastError();
      string obj_name = MMEditName(target_edit[i]);
      string prop_val = "0.0";
      double dprop_val = 0.0;

      if(target_edit[i] == "Risk")
      {
         prop_val = DoubleToString(m_defRiskPct, 2);
         dprop_val = m_defRiskPct;
      }
      else if(target_edit[i] == "Entry")
      {
         dprop_val = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
         prop_val = DoubleToString(dprop_val, Digits());
      }
      else if(target_edit[i] == "SL")
      {
         double entry = StringToDouble(ObjectGetString(0, MMEditName("Entry"), OBJPROP_TEXT));
         dprop_val = DefaultSL(entry);
         prop_val = DoubleToString(dprop_val, Digits());
      }

      if(!ObjectSetString(0, obj_name, OBJPROP_TEXT, prop_val))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }

      if(target_edit[i] == "Risk")
         continue;

      obj_name = MMLineName(target_edit[i]);
      if(!ObjectSetDouble(0, obj_name, OBJPROP_PRICE, dprop_val))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }
   }

   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CMMDialog::DefaultSL(const double entry)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double distance = MMMinimumStopsDistance() + 20.0 * point;

   if(entry > ask)
      return MMNormalizePriceUp(entry + distance);

   return MMNormalizePriceDown(entry - distance);
}

bool CMMDialog::ApplyDefaultSLForEntry()
{
   double entry = StringToDouble(ObjectGetString(0, MMEditName("Entry"), OBJPROP_TEXT));

   if(!m_autoSL)
      return true;

   double sl = DefaultSL(entry);
   string sl_text = DoubleToString(sl, Digits());

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("SL"), OBJPROP_TEXT, sl_text))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   ResetLastError();
   if(!ObjectSetDouble(0, MMLineName("SL"), OBJPROP_PRICE, sl))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CMMDialog::OrderComment(const MMInputs &inputs,
                               const double entry,
                               const double sl,
                               const double tp)
{
   return StringFormat("B:%.2f, R:%.2f %%, RR:%s",
                       AccountInfoDouble(ACCOUNT_BALANCE),
                       inputs.risk_pct,
                       MMRewardRiskText(entry, sl, tp));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::PreparePendingOrder(const MMInputs &inputs,
                                    ENUM_ORDER_TYPE &order_type,
                                    double &entry,
                                    double &sl,
                                    double &tp,
                                    bool &entry_adjusted,
                                    string &error_message)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      error_message = "Cannot read current Bid/Ask for " + _Symbol;
      return false;
   }

   entry = MMNormalizePrice(inputs.entry);
   sl = MMNormalizePrice(inputs.sl);
   tp = (inputs.tp > 0.0 ? MMNormalizePrice(inputs.tp) : 0.0);
   entry_adjusted = false;

   if(entry <= 0.0 || sl <= 0.0)
   {
      error_message = "Entry and SL must be valid prices.";
      return false;
   }

   double bid = MMNormalizePrice(tick.bid);
   double ask = MMNormalizePrice(tick.ask);
   double min_distance = MMMinimumStopsDistance();

   if(entry < bid)
   {
      order_type = ORDER_TYPE_BUY_LIMIT;
      double max_entry = MMNormalizePriceDown(bid - min_distance);
      if(entry > max_entry)
      {
         entry = max_entry;
         entry_adjusted = true;
      }
   }
   else if(entry > ask)
   {
      order_type = ORDER_TYPE_SELL_LIMIT;
      double min_entry = MMNormalizePriceUp(ask + min_distance);
      if(entry < min_entry)
      {
         entry = min_entry;
         entry_adjusted = true;
      }
   }
   else
   {
      error_message = StringFormat("Entry is inside the spread. Use below Bid for BUY LIMIT or above Ask for SELL LIMIT. Bid=%s Ask=%s",
                                   DoubleToString(bid, Digits()),
                                   DoubleToString(ask, Digits()));
      return false;
   }

   if(order_type == ORDER_TYPE_BUY_LIMIT)
   {
      if(sl >= entry)
      {
         error_message = "BUY LIMIT needs SL below Entry.";
         return false;
      }
      if(tp > 0.0 && tp <= entry)
      {
         error_message = "BUY LIMIT needs TP above Entry.";
         return false;
      }
      if(min_distance > 0.0 && entry - sl < min_distance)
      {
         error_message = "BUY LIMIT SL is too close to Entry for this symbol.";
         return false;
      }
      if(min_distance > 0.0 && tp > 0.0 && tp - entry < min_distance)
      {
         error_message = "BUY LIMIT TP is too close to Entry for this symbol.";
         return false;
      }
   }
   else
   {
      if(sl <= entry)
      {
         error_message = "SELL LIMIT needs SL above Entry.";
         return false;
      }
      if(tp > 0.0 && tp >= entry)
      {
         error_message = "SELL LIMIT needs TP below Entry.";
         return false;
      }
      if(min_distance > 0.0 && sl - entry < min_distance)
      {
         error_message = "SELL LIMIT SL is too close to Entry for this symbol.";
         return false;
      }
      if(min_distance > 0.0 && tp > 0.0 && entry - tp < min_distance)
      {
         error_message = "SELL LIMIT TP is too close to Entry for this symbol.";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::PlacePendingOrder(const MMInputs &inputs)
{
   ENUM_ORDER_TYPE order_type;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   bool entry_adjusted = false;
   string validation_error = "";

   if(!PreparePendingOrder(inputs, order_type, entry, sl, tp, entry_adjusted, validation_error))
   {
      Alert(validation_error);
      return true;
   }

   if(entry_adjusted)
   {
      string entry_text = DoubleToString(entry, Digits());
      ObjectSetString(0, MMEditName("Entry"), OBJPROP_TEXT, entry_text);
      ObjectSetDouble(0, MMLineName("Entry"), OBJPROP_PRICE, entry);
      UpdateInfoLabels();
      Alert("Entry adjusted to nearest broker-valid pending price: " + entry_text);
   }

   double lot_val = MMLotByPoints(entry, sl, inputs.risk_pct);
   string comment = OrderComment(inputs, entry, sl, tp);
   printf("calculated lot: %g", lot_val);

   if(lot_val < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Alert("LOT is not enough");
      return true;
   }

   ResetLastError();

   if(order_type == ORDER_TYPE_BUY_LIMIT)
   {
      if(!m_ct.BuyLimit(lot_val, entry, NULL, sl, tp, ORDER_TIME_GTC, 0, comment))
      {
         Print(__FUNCTION__,
               ": failed to send BUY LIMIT! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         return false;
      }
   }
   else
   {
      if(!m_ct.SellLimit(lot_val, entry, NULL, sl, tp, ORDER_TIME_GTC, 0, comment))
      {
         Print(__FUNCTION__,
               ": failed to send SELL LIMIT! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HLineCreate(const long            chart_ID = 0,      // chart's ID
                 const string          name = "HLine",    // line name
                 double                price = 0,         // line price
                 const color           clr = clrRed,      // line color
                 const ENUM_LINE_STYLE style = STYLE_SOLID, // line style
                 const int             width = 1,         // line width
                 const bool            selection = true,  // highlight to move
                 const long            z_order = 0)       // priority for mouse click
{
   string OBJNAME = MMLineName(name);

   ResetLastError();
   if(!ObjectCreate(chart_ID, OBJNAME, OBJ_HLINE, 0, 0, price))
   {
      Print(__FUNCTION__,
            ": failed to create a horizontal line! Error code = ", GetLastError());
      return false;
   }
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_STYLE, style);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_WIDTH, width);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_BACK, true);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_SELECTED, selection);
   return true;
}
//+------------------------------------------------------------------+
