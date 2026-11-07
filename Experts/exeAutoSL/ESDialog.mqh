//+------------------------------------------------------------------+
//|                                                     ESDialog.mqh  |
//|                                                     will_santoso  |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Trade/Trade.mqh>
#include "ESConfig.mqh"
#include "ESNames.mqh"
#include "ESCalculator.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CExeAutoSLDialog : public CAppDialog
{
private:
   CTrade m_ct;
   double m_inpRiskPct;
   double m_inpRiskReward;
   double m_riskUSD;
   double m_defRiskPct;
   double m_defRiskReward;
   long m_magicNumber;
   ENUM_ORDER_TYPE m_orderType;

   //Button
   CButton m_buyButton;
   CButton m_sellButton;
   CButton m_resetButton;
   CButton m_lotIncreaseButton;
   CButton m_lotDecreaseButton;
   //Label
   CLabel m_RiskLabel;
   CLabel m_RiskRewardLabel;
   CLabel m_RiskUSDLabel;
   CLabel m_LotLabel;
   CLabel m_BuyHeaderLabel;
   CLabel m_SellHeaderLabel;
   CLabel m_BuySLLabel;
   CLabel m_BuySLValueLabel;
   CLabel m_BuyTPLabel;
   CLabel m_BuyTPValueLabel;
   CLabel m_SellSLLabel;
   CLabel m_SellSLValueLabel;
   CLabel m_SellTPLabel;
   CLabel m_SellTPValueLabel;
   //Edit
   CEdit m_RiskEdit;
   CEdit m_RiskRewardEdit;
   CEdit m_LotEdit;

public:
   CExeAutoSLDialog();
   CExeAutoSLDialog(const double &inpRiskPct, const double &inpRiskReward, const long magicNumber);
   ~CExeAutoSLDialog();

   virtual bool Create(const long chart,
                       const string name,
                       const int subwin,
                       const int x1,
                       const int y1,
                       const int x2,
                       const int y2);
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   bool Refresh();

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

   bool ReadInputDouble(const string name, const string label, double &value, string &error_message);
   bool ReadInputs(ESInputs &inputs, string &error_message);
   bool SetButtonText(const string name, const string text);
   bool SetLabelText(const string name, const string text);
   bool SetEditText(const string name, const string text);
   bool SetLinePrice(const string name, const double price);
   bool SetLineTextPrice(const string name, const double price);
   bool BuildOrderPlan(ESOrderPlan &plan, string &error_message);
   bool BuildOrderPlan(const ENUM_ORDER_TYPE order_type, ESOrderPlan &plan, string &error_message);
   bool ApplyNormalizedLotInput(const ESOrderPlan &plan);
   bool UpdatePlanDisplay(const ESOrderPlan &plan);
   string PlanText(const ESOrderPlan &plan);
   void ResetOrderButtons();
   bool UpdateRiskUSD();
   bool SendMarketOrder(const ENUM_ORDER_TYPE order_type);
   bool UpdateInfoLabels();
   bool ResetPanel();
   string OrderComment(const ESInputs &inputs);
   bool IncreaseLotClick();
   bool DecreaseLotClick();
   bool AdjustLotByStep(const int direction);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExeAutoSLDialog::CExeAutoSLDialog()
{
   m_inpRiskPct = 0.0;
   m_inpRiskReward = 0.0;
   m_riskUSD = 0.0;
   m_defRiskPct = 0.0;
   m_defRiskReward = 0.0;
   m_magicNumber = 0;
   m_orderType = ORDER_TYPE_BUY;
}

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExeAutoSLDialog::CExeAutoSLDialog(const double &inpRiskPct, const double &inpRiskReward, const long magicNumber)
{
   m_defRiskPct = inpRiskPct;
   m_defRiskReward = inpRiskReward;
   m_inpRiskPct = m_defRiskPct;
   m_inpRiskReward = m_defRiskReward;
   m_riskUSD = m_inpRiskPct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   m_magicNumber = magicNumber;
   m_orderType = ORDER_TYPE_BUY;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CExeAutoSLDialog::~CExeAutoSLDialog()
{
   ObjectsDeleteAll(0, ESObjectPrefix());
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   int panW = x2 - x1;
   int colW = (panW - INDENT_LEFT - INDENT_RIGHT - CONTROLS_GAP_X) / 2;
   int buyX1 = INDENT_LEFT;
   int buyX2 = buyX1 + colW;
   int sellX1 = buyX2 + CONTROLS_GAP_X;
   int sellX2 = panW - INDENT_RIGHT;
   int valueGap = 34;
   int lotButtonW = 34;
   int lotButtonGap = 4;
   int lotSpinX2 = panW - INDENT_RIGHT;
   int lotIncX1 = lotSpinX2 - lotButtonW;
   int lotDecX1 = lotIncX1 - lotButtonGap - lotButtonW;
   int lotEditX2 = lotDecX1 - CONTROLS_GAP_X;
   int lotRowY1 = (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y;
   int lotRowY2 = (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y;

   ObjectsDeleteAll(chart, ESObjectPrefix());

   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;

   m_ct.SetExpertMagicNumber(m_magicNumber);

//--- create lines
   HLineCreate(0, "BuySL", SymbolInfoDouble(_Symbol, SYMBOL_BID), clrOrangeRed, STYLE_SOLID, 1, false, 0, "BUY SL");
   HLineCreate(0, "BuyTP", SymbolInfoDouble(_Symbol, SYMBOL_ASK), clrGreen, STYLE_SOLID, 1, false, 0, "BUY TP");
   HLineCreate(0, "SellSL", SymbolInfoDouble(_Symbol, SYMBOL_ASK), clrTomato, STYLE_DASH, 1, false, 0, "SELL SL");
   HLineCreate(0, "SellTP", SymbolInfoDouble(_Symbol, SYMBOL_BID), clrSeaGreen, STYLE_DASH, 1, false, 0, "SELL TP");

//--- reset button
   if(!CreateButton(m_resetButton,
                    chart,
                    "reset",
                    subwin,
                    "Reset",
                    INDENT_LEFT,
                    INDENT_TOP,
                    INDENT_LEFT + BUTTON_WIDTH,
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

//--- risk reward label
   if(!CreateLabel(m_RiskRewardLabel,
                   chart,
                   "RiskReward",
                   subwin,
                   "RiskReward",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y))
      return false;

//--- risk reward edit
   if(!CreateEdit(m_RiskRewardEdit,
                  chart,
                  "RiskReward",
                  subwin,
                  DoubleToString(m_inpRiskReward, 2),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- lot label
   if(!CreateLabel(m_LotLabel,
                   chart,
                   "Lot",
                   subwin,
                   "LOT",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y))
      return false;

//--- lot edit
   if(!CreateEdit(m_LotEdit,
                  chart,
                  "Lot",
                  subwin,
                  ESDefaultLotText(),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  lotRowY1,
                  lotEditX2,
                  lotRowY2,
                  false))
      return false;

//--- lot decrease button
   if(!CreateButton(m_lotDecreaseButton,
                    chart,
                    "lotDecrease",
                    subwin,
                    "-",
                    lotDecX1,
                    lotRowY1,
                    lotDecX1 + lotButtonW,
                    lotRowY2))
      return false;

//--- lot increase button
   if(!CreateButton(m_lotIncreaseButton,
                    chart,
                    "lotIncrease",
                    subwin,
                    "+",
                    lotIncX1,
                    lotRowY1,
                    lotIncX1 + lotButtonW,
                    lotRowY2))
      return false;

//--- buy header label
   if(!CreateLabel(m_BuyHeaderLabel,
                   chart,
                   "BuyHeader",
                   subwin,
                   "BUY",
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                   buyX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- sell header label
   if(!CreateLabel(m_SellHeaderLabel,
                   chart,
                   "SellHeader",
                   subwin,
                   "SELL",
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                   sellX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- buy SL label
   if(!CreateLabel(m_BuySLLabel,
                   chart,
                   "BuySL",
                   subwin,
                   "SL",
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- buy SL value label
   if(!CreateLabel(m_BuySLValueLabel,
                   chart,
                   "BuySLValue",
                   subwin,
                   "-",
                   buyX1 + valueGap,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   buyX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- buy TP label
   if(!CreateLabel(m_BuyTPLabel,
                   chart,
                   "BuyTP",
                   subwin,
                   "TP",
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- buy TP value label
   if(!CreateLabel(m_BuyTPValueLabel,
                   chart,
                   "BuyTPValue",
                   subwin,
                   "-",
                   buyX1 + valueGap,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   buyX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y))
      return false;

//--- sell SL label
   if(!CreateLabel(m_SellSLLabel,
                   chart,
                   "SellSL",
                   subwin,
                   "SL",
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- sell SL value label
   if(!CreateLabel(m_SellSLValueLabel,
                   chart,
                   "SellSLValue",
                   subwin,
                   "-",
                   sellX1 + valueGap,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   sellX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- sell TP label
   if(!CreateLabel(m_SellTPLabel,
                   chart,
                   "SellTP",
                   subwin,
                   "TP",
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- sell TP value label
   if(!CreateLabel(m_SellTPValueLabel,
                   chart,
                   "SellTPValue",
                   subwin,
                   "-",
                   sellX1 + valueGap,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   sellX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y))
      return false;

//--- buy button
   if(!CreateButton(m_buyButton,
                   chart,
                   "buy",
                   subwin,
                   "BUY",
                   buyX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y,
                   buyX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 8 + CONTROLS_GAP_Y))
      return false;

//--- sell button
   if(!CreateButton(m_sellButton,
                   chart,
                   "sell",
                   subwin,
                   "SELL",
                   sellX1,
                   (INDENT_TOP + BUTTON_HEIGHT) * 7 + CONTROLS_GAP_Y,
                   sellX2,
                   (INDENT_TOP + BUTTON_HEIGHT) * 8 + CONTROLS_GAP_Y))
      return false;

   if(!UpdateInfoLabels())
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      ResetOrderButtons();
      ResetLastError();
      if(sparam == ESEditName("Risk"))
      {
         if(!UpdateRiskUSD())
            return false;
      }

      if(!UpdateInfoLabels())
         return false;
      return true;
   }
   else if(id == ON_CLICK + CHARTEVENT_CUSTOM && StringFind(sparam, ".Button") != -1)
   {
      if(sparam == ESButtonName("buy"))
      {
         if(!SendMarketOrder(ORDER_TYPE_BUY))
            return false;
      }
      else if(sparam == ESButtonName("sell"))
      {
         if(!SendMarketOrder(ORDER_TYPE_SELL))
            return false;
      }
      else if(sparam == ESButtonName("reset"))
      {
         ResetOrderButtons();
         if(!ResetPanel())
            return false;
         return true;
      }
      else if(sparam == ESButtonName("lotIncrease"))
      {
         if(!IncreaseLotClick())
            return false;
      }
      else if(sparam == ESButtonName("lotDecrease"))
      {
         if(!DecreaseLotClick())
            return false;
      }
      return true;
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
   {
      bool base_result = CAppDialog::OnEvent(id, lparam, dparam, sparam);
      if(!UpdateInfoLabels())
         return false;
      return base_result;
   }
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::Refresh()
{
   if(!UpdateRiskUSD())
      return false;
   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//| Create buttons                                                   |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::CreateButton(CButton &cbutt,
                                const long chart,
                                const string name,
                                const int subwin,
                                const string text,
                                const int x1,
                                const int y1,
                                const int x2,
                                const int y2)
{
   if(!cbutt.Create(chart, ESButtonName(name), subwin, x1, y1, x2, y2))
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
bool CExeAutoSLDialog::CreateEdit(CEdit &cedit,
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
   if(!cedit.Create(chart, ESEditName(name), subwin, x1, y1, x2, y2))
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
bool CExeAutoSLDialog::CreateLabel(CLabel &clabel,
                               const long chart,
                               const string name,
                               const int subwin,
                               const string text,
                               const int x1,
                               const int y1,
                               const int x2,
                               const int y2)
{
   if(!clabel.Create(chart, ESLabelName(name), subwin, x1, y1, x2, y2))
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
bool CExeAutoSLDialog::ReadInputDouble(const string name, const string label, double &value, string &error_message)
{
   string text = ObjectGetString(0, ESEditName(name), OBJPROP_TEXT);
   StringTrimLeft(text);
   StringTrimRight(text);

   if(StringLen(text) == 0)
   {
      error_message = label + " is required.";
      return false;
   }

   int dot_count = 0;
   bool has_digit = false;
   for(int i = 0; i < StringLen(text); i++)
   {
      ushort ch = StringGetCharacter(text, i);
      if(ch >= 48 && ch <= 57)
      {
         has_digit = true;
         continue;
      }
      if(ch == 46)
      {
         dot_count++;
         if(dot_count <= 1)
            continue;
      }

      error_message = label + " must be a positive number using dot decimal format.";
      return false;
   }

   if(!has_digit)
   {
      error_message = label + " must be a positive number.";
      return false;
   }

   value = StringToDouble(text);
   if(value <= 0.0)
   {
      error_message = label + " must be greater than zero.";
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::ReadInputs(ESInputs &inputs, string &error_message)
{
   if(!ReadInputDouble("Risk", "Risk %", inputs.risk_pct, error_message))
      return false;
   if(!ReadInputDouble("RiskReward", "RiskReward", inputs.risk_reward, error_message))
      return false;
   if(!ReadInputDouble("Lot", "Lot", inputs.lot, error_message))
      return false;
   inputs.order_type = m_orderType;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SetButtonText(const string name, const string text)
{
   ResetLastError();
   if(!ObjectSetString(0, ESButtonName(name), OBJPROP_TEXT, text))
   {
      Print(__FUNCTION__,
            ": failed to change button text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SetLabelText(const string name, const string text)
{
   ResetLastError();
   if(!ObjectSetString(0, ESLabelName(name), OBJPROP_TEXT, text))
   {
      Print(__FUNCTION__,
            ": failed to change label text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SetEditText(const string name, const string text)
{
   ResetLastError();
   if(!ObjectSetString(0, ESEditName(name), OBJPROP_TEXT, text))
   {
      Print(__FUNCTION__,
            ": failed to change edit text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SetLinePrice(const string name, const double price)
{
   ResetLastError();
   if(!ObjectSetDouble(0, ESLineName(name), OBJPROP_PRICE, price))
   {
      Print(__FUNCTION__,
            ": failed to change line price! Error code = ", GetLastError());
      return false;
   }

   return SetLineTextPrice(name, price);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SetLineTextPrice(const string name, const double price)
{
   return HLineTextMove(0, name, price);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CExeAutoSLDialog::ResetOrderButtons()
{
   SetButtonText("buy", "BUY");
   SetButtonText("sell", "SELL");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::BuildOrderPlan(ESOrderPlan &plan, string &error_message)
{
   return BuildOrderPlan(m_orderType, plan, error_message);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::BuildOrderPlan(const ENUM_ORDER_TYPE order_type, ESOrderPlan &plan, string &error_message)
{
   if(!ReadInputs(plan.inputs, error_message))
      return false;
   plan.inputs.order_type = order_type;

   double normalized_lot = ESNormalizeVolumeDown(plan.inputs.lot);
   if(normalized_lot <= 0.0)
   {
      error_message = "Lot cannot be normalized to a tradable volume for this symbol.";
      return false;
   }

   plan.inputs.lot = normalized_lot;
   plan.entry = 0.0;
   plan.lot = normalized_lot;
   plan.risk_usd = plan.inputs.risk_pct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   plan.order_type = plan.inputs.order_type;
   plan.sl = 0.0;
   plan.tp = 0.0;
   plan.side = "";

   if(!ESSLFromRiskLot(plan.order_type, plan.lot, plan.inputs.risk_pct, plan.inputs.risk_reward, plan.entry, plan.sl, plan.tp, plan.side, error_message))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::ApplyNormalizedLotInput(const ESOrderPlan &plan)
{
   double input_lot = 0.0;
   string error_message = "";
   if(!ReadInputDouble("Lot", "Lot", input_lot, error_message))
      return false;

   if(MathAbs(input_lot - plan.lot) <= 0.00000001)
      return true;

   return SetEditText("Lot",
                      DoubleToString(plan.lot,
                                     ESVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::UpdatePlanDisplay(const ESOrderPlan &plan)
{
   string sl_label = (plan.order_type == ORDER_TYPE_BUY ? "BuySLValue" : "SellSLValue");
   string tp_label = (plan.order_type == ORDER_TYPE_BUY ? "BuyTPValue" : "SellTPValue");
   string sl_line = (plan.order_type == ORDER_TYPE_BUY ? "BuySL" : "SellSL");
   string tp_line = (plan.order_type == ORDER_TYPE_BUY ? "BuyTP" : "SellTP");

   if(!SetLabelText(sl_label, DoubleToString(plan.sl, Digits())))
      return false;
   if(!SetLinePrice(sl_line, plan.sl))
      return false;
   if(!SetLabelText(tp_label, DoubleToString(plan.tp, Digits())))
      return false;
   if(!SetLinePrice(tp_line, plan.tp))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CExeAutoSLDialog::PlanText(const ESOrderPlan &plan)
{
   return StringFormat("%s %s\nLot: %s\nEntry: %s\nSL: %s\nTP: %s\nRisk: $ %.2f\nMagic: %s",
                       _Symbol,
                       plan.side,
                       DoubleToString(plan.lot, ESVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
                       DoubleToString(plan.entry, Digits()),
                       DoubleToString(plan.sl, Digits()),
                       DoubleToString(plan.tp, Digits()),
                       plan.risk_usd,
                       IntegerToString(m_magicNumber));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::UpdateRiskUSD()
{
   string error_message = "";
   if(!ReadInputDouble("Risk", "Risk %", m_inpRiskPct, error_message))
   {
      m_riskUSD = 0.0;
      return SetLabelText("RiskUSD", "$ -");
   }

   m_riskUSD = m_inpRiskPct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);

   return SetLabelText("RiskUSD", StringFormat("$ %.2f", m_riskUSD));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CExeAutoSLDialog::OrderComment(const ESInputs &inputs)
{
   return StringFormat("ExeAutoSL B:%.2f, R:%.2f %%, RR:%.2f, L:%s",
                       AccountInfoDouble(ACCOUNT_BALANCE),
                       inputs.risk_pct,
                       inputs.risk_reward,
                       DoubleToString(inputs.lot, ESVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))));
}

//+------------------------------------------------------------------+
//| Increase Lot Click                                               |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::IncreaseLotClick()
{
   return AdjustLotByStep(1);
}

//+------------------------------------------------------------------+
//| Decrease Lot Click                                               |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::DecreaseLotClick()
{
   return AdjustLotByStep(-1);
}

//+------------------------------------------------------------------+
//| Adjust Lot by one symbol volume step                             |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::AdjustLotByStep(const int direction)
{
   double lot = 0.0;
   string error_message = "";
   if(!ReadInputDouble("Lot", "Lot", lot, error_message))
   {
      Alert(error_message);
      return true;
   }

   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volume_step <= 0.0 || volume_min <= 0.0)
   {
      Alert("Cannot adjust Lot: this symbol has invalid volume settings.");
      return true;
   }

   double next_lot = lot + (direction >= 0 ? volume_step : -volume_step);
   if(next_lot < volume_min)
      next_lot = volume_min;
   if(volume_max > 0.0 && next_lot > volume_max)
      next_lot = volume_max;

   next_lot = ESNormalizeVolumeDown(next_lot);
   if(next_lot <= 0.0)
   {
      Alert("Lot cannot be normalized to a tradable volume for this symbol.");
      return true;
   }

   if(!SetEditText("Lot", DoubleToString(next_lot, ESVolumeDigits(volume_step))))
      return false;

   ResetOrderButtons();
   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::SendMarketOrder(const ENUM_ORDER_TYPE order_type)
{
   ESOrderPlan plan;
   string error_message = "";
   m_orderType = order_type;

   if(!BuildOrderPlan(plan, error_message))
   {
      ResetOrderButtons();
      Alert(error_message);
      return true;
   }

   if(!ApplyNormalizedLotInput(plan))
      return false;

   if(!UpdatePlanDisplay(plan))
      return false;

   string comment = OrderComment(plan.inputs);
   ResetLastError();

   if(plan.order_type == ORDER_TYPE_BUY)
   {
      if(!m_ct.Buy(plan.lot, NULL, 0.0, plan.sl, plan.tp, comment))
      {
         Print(__FUNCTION__,
               ": failed to send BUY! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         Alert("Failed to send BUY: " + m_ct.ResultRetcodeDescription());
         return false;
      }
   }
   else if(plan.order_type == ORDER_TYPE_SELL)
   {
      if(!m_ct.Sell(plan.lot, NULL, 0.0, plan.sl, plan.tp, comment))
      {
         Print(__FUNCTION__,
               ": failed to send SELL! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         Alert("Failed to send SELL: " + m_ct.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      Alert("Cannot send order: invalid side.");
      return true;
   }

   ResetOrderButtons();
   Alert("Order sent:\n" + PlanText(plan));
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::UpdateInfoLabels()
{
   ESOrderPlan buy_plan;
   ESOrderPlan sell_plan;
   string buy_error = "";
   string sell_error = "";
   bool has_buy_plan = BuildOrderPlan(ORDER_TYPE_BUY, buy_plan, buy_error);
   bool has_sell_plan = BuildOrderPlan(ORDER_TYPE_SELL, sell_plan, sell_error);

   if(!SetLabelText("BuySLValue", has_buy_plan ? DoubleToString(buy_plan.sl, Digits()) : "-"))
      return false;
   if(!SetLabelText("BuyTPValue", has_buy_plan ? DoubleToString(buy_plan.tp, Digits()) : "-"))
      return false;
   if(!SetLabelText("SellSLValue", has_sell_plan ? DoubleToString(sell_plan.sl, Digits()) : "-"))
      return false;
   if(!SetLabelText("SellTPValue", has_sell_plan ? DoubleToString(sell_plan.tp, Digits()) : "-"))
      return false;

   if(has_buy_plan)
   {
      if(!SetLinePrice("BuySL", buy_plan.sl))
         return false;
      if(!SetLinePrice("BuyTP", buy_plan.tp))
         return false;
   }

   if(has_sell_plan)
   {
      if(!SetLinePrice("SellSL", sell_plan.sl))
         return false;
      if(!SetLinePrice("SellTP", sell_plan.tp))
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExeAutoSLDialog::ResetPanel()
{
   m_inpRiskPct = m_defRiskPct;
   m_inpRiskReward = m_defRiskReward;
   m_riskUSD = m_inpRiskPct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   m_orderType = ORDER_TYPE_BUY;

   if(!SetLabelText("RiskUSD", StringFormat("$ %.2f", m_riskUSD)))
      return false;

   string target_edit[] = {"Risk", "RiskReward", "Lot"};
   for(int i = 0; i < ArraySize(target_edit); i++)
   {
      ResetLastError();
      string obj_name = ESEditName(target_edit[i]);
      string prop_val = "";

      if(target_edit[i] == "Risk")
      {
         prop_val = DoubleToString(m_defRiskPct, 2);
      }
      else if(target_edit[i] == "RiskReward")
      {
         prop_val = DoubleToString(m_defRiskReward, 2);
      }
      else if(target_edit[i] == "Lot")
      {
         prop_val = ESDefaultLotText();
      }

      if(!ObjectSetString(0, obj_name, OBJPROP_TEXT, prop_val))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }

   }

   if(!SetLabelText("BuySLValue", "-"))
      return false;

   if(!SetLabelText("BuyTPValue", "-"))
      return false;

   if(!SetLabelText("SellSLValue", "-"))
      return false;

   if(!SetLabelText("SellTPValue", "-"))
      return false;

   if(!SetLinePrice("BuySL", SymbolInfoDouble(_Symbol, SYMBOL_BID)))
      return false;
   if(!SetLinePrice("BuyTP", SymbolInfoDouble(_Symbol, SYMBOL_ASK)))
      return false;
   if(!SetLinePrice("SellSL", SymbolInfoDouble(_Symbol, SYMBOL_ASK)))
      return false;
   if(!SetLinePrice("SellTP", SymbolInfoDouble(_Symbol, SYMBOL_BID)))
      return false;

   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HLineTextRightTime(const long chart_ID, datetime &label_time)
{
   int width = (int)ChartGetInteger(chart_ID, CHART_WIDTH_IN_PIXELS, 0);
   int sub_window = 0;
   double price = 0.0;

   label_time = TimeCurrent();
   if(width <= 0)
      return false;

   return ChartXYToTimePrice(chart_ID, width - 8, 0, sub_window, label_time, price);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HLineTextMove(const long chart_ID, const string name, const double price)
{
   string OBJNAME = ESLineTextName(name);
   datetime label_time = 0;
   int x = 0;
   int y = 0;

   if(ObjectFind(chart_ID, OBJNAME) < 0)
      return true;
   if(!HLineTextRightTime(chart_ID, label_time))
      label_time = TimeCurrent();
   if(!ChartTimePriceToXY(chart_ID, 0, label_time, price, x, y))
      return false;

   ResetLastError();
   if(!ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_YDISTANCE, y))
   {
      Print(__FUNCTION__,
            ": failed to move line text! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HLineTextCreate(const long chart_ID,
                     const string name,
                     const string text,
                     const double price,
                     const color clr,
                     const long z_order = 0)
{
   string OBJNAME = ESLineTextName(name);
   datetime label_time = 0;

   if(!HLineTextRightTime(chart_ID, label_time))
      label_time = TimeCurrent();

   ResetLastError();
   if(!ObjectCreate(chart_ID, OBJNAME, OBJ_LABEL, 0, 0, 0))
   {
      Print(__FUNCTION__,
            ": failed to create line text! Error code = ", GetLastError());
      return false;
   }

   ObjectSetString(chart_ID, OBJNAME, OBJPROP_TEXT, text);
   ObjectSetString(chart_ID, OBJNAME, OBJPROP_FONT, "Arial");
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_BACK, false);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_ZORDER, z_order);

   return HLineTextMove(chart_ID, name, price);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HLineCreate(const long            chart_ID = 0,
                 const string          name = "HLine",
                 double                price = 0,
                 const color           clr = clrRed,
                 const ENUM_LINE_STYLE style = STYLE_SOLID,
                 const int             width = 1,
                 const bool            selection = true,
                 const long            z_order = 0,
                 const string          text = "")
{
   string OBJNAME = ESLineName(name);

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
   ObjectSetInteger(chart_ID, OBJNAME, OBJPROP_ZORDER, z_order);
   if(StringLen(text) > 0 && !HLineTextCreate(chart_ID, name, text, price, clr, z_order))
      return false;
   return true;
}
//+------------------------------------------------------------------+
