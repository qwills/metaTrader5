//+------------------------------------------------------------------+
//|                                                     ASDialog.mqh  |
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
#include "ASConfig.mqh"
#include "ASNames.mqh"
#include "ASCalculator.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CAutoSLDialog : public CAppDialog
{
private:
   CTrade m_ct;
   double m_inpRiskPct;
   double m_inpRiskReward;
   double m_riskUSD;
   double m_defRiskPct;
   double m_defRiskReward;
   long m_magicNumber;
   bool m_pendingConfirm;
   string m_confirmSignature;

   //Button
   CButton m_calcButton;
   CButton m_resetButton;
   CButton m_lotIncreaseButton;
   CButton m_lotDecreaseButton;
   //Label
   CLabel m_EntryLabel;
   CLabel m_RiskLabel;
   CLabel m_RiskRewardLabel;
   CLabel m_RiskUSDLabel;
   CLabel m_LotLabel;
   CLabel m_SLLabel;
   CLabel m_SLValueLabel;
   CLabel m_TPLabel;
   CLabel m_TPValueLabel;
   CLabel m_LimitLabel;
   CLabel m_LimitValueLabel;
   //Edit
   CEdit m_EntryEdit;
   CEdit m_RiskEdit;
   CEdit m_RiskRewardEdit;
   CEdit m_LotEdit;

public:
   CAutoSLDialog();
   CAutoSLDialog(const double &inpRiskPct, const double &inpRiskReward, const long magicNumber);
   ~CAutoSLDialog();

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
   bool ReadInputs(ASInputs &inputs, string &error_message);
   bool SetButtonText(const string name, const string text);
   bool SetLabelText(const string name, const string text);
   bool SetLinePrice(const string name, const double price);
   bool BuildOrderPlan(ASOrderPlan &plan, string &error_message);
   bool UpdatePlanDisplay(const ASOrderPlan &plan);
   string PlanSignature(const ASOrderPlan &plan);
   string PlanText(const ASOrderPlan &plan);
   void ClearConfirmation();
   bool UpdateRiskUSD();
   bool SyncEditFromLine(const string line_name);
   bool SyncLineFromEdit(const string edit_name);
   bool SendPendingOrder();
   bool UpdateInfoLabels();
   bool ResetPanel();
   string OrderComment(const ASInputs &inputs);
   bool IncreaseLotClick();
   bool DecreaseLotClick();
   bool AdjustLotByStep(const int direction);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAutoSLDialog::CAutoSLDialog()
{
   m_inpRiskPct = 0.0;
   m_inpRiskReward = 0.0;
   m_riskUSD = 0.0;
   m_defRiskPct = 0.0;
   m_defRiskReward = 0.0;
   m_magicNumber = 0;
   m_pendingConfirm = false;
   m_confirmSignature = "";
}

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAutoSLDialog::CAutoSLDialog(const double &inpRiskPct, const double &inpRiskReward, const long magicNumber)
{
   m_defRiskPct = inpRiskPct;
   m_defRiskReward = inpRiskReward;
   m_inpRiskPct = m_defRiskPct;
   m_inpRiskReward = m_defRiskReward;
   m_riskUSD = m_inpRiskPct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   m_magicNumber = magicNumber;
   m_pendingConfirm = false;
   m_confirmSignature = "";
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CAutoSLDialog::~CAutoSLDialog()
{
   ObjectsDeleteAll(0, ASObjectPrefix());
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   int panW = x2 - x1;
   int lotButtonW = 34;
   int lotButtonGap = 4;
   int lotButtonX2 = panW - INDENT_RIGHT;
   int lotIncX1 = lotButtonX2 - lotButtonW;
   int lotDecX1 = lotIncX1 - lotButtonGap - lotButtonW;
   int lotEditX2 = lotDecX1 - CONTROLS_GAP_X;
   int lotRowY1 = (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y;
   int lotRowY2 = (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y;

   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;

   m_ct.SetExpertMagicNumber(m_magicNumber);

//--- create lines
   HLineCreate(0, "Entry", SymbolInfoDouble(_Symbol, SYMBOL_BID), clrBlue, STYLE_SOLID, 1, true);
   HLineCreate(0, "SL", SymbolInfoDouble(_Symbol, SYMBOL_ASK), clrOrangeRed, STYLE_SOLID, 1, false);
   HLineCreate(0, "TP", 0.0, clrGreen, STYLE_SOLID, 1, false);

//--- calculate button
   if(!CreateButton(m_calcButton,
                    chart,
                    "calc",
                    subwin,
                    "Send",
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
                  DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), Digits()),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 2 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- risk reward label
   if(!CreateLabel(m_RiskRewardLabel,
                   chart,
                   "RiskReward",
                   subwin,
                   "RiskReward",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y))
      return false;

//--- risk reward edit
   if(!CreateEdit(m_RiskRewardEdit,
                  chart,
                  "RiskReward",
                  subwin,
                  DoubleToString(m_inpRiskReward, 2),
                  INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                  (INDENT_TOP + BUTTON_HEIGHT) * 3 + CONTROLS_GAP_Y,
                  panW - BUTTON_WIDTH - INDENT_RIGHT,
                  (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                  false))
      return false;

//--- lot label
   if(!CreateLabel(m_LotLabel,
                   chart,
                   "Lot",
                   subwin,
                   "LOT",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 4 + CONTROLS_GAP_Y))
      return false;

//--- lot edit
   if(!CreateEdit(m_LotEdit,
                  chart,
                  "Lot",
                  subwin,
                  ASDefaultLotText(),
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

//--- SL label
   if(!CreateLabel(m_SLLabel,
                   chart,
                   "SL",
                   subwin,
                   "SL",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y))
      return false;

//--- SL value label
   if(!CreateLabel(m_SLValueLabel,
                   chart,
                   "SLValue",
                   subwin,
                   "-",
                   INDENT_LEFT + BUTTON_WIDTH + CONTROLS_GAP_X,
                   (INDENT_TOP + BUTTON_HEIGHT) * 5 + CONTROLS_GAP_Y,
                   panW - BUTTON_WIDTH - INDENT_RIGHT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- TP label
   if(!CreateLabel(m_TPLabel,
                   chart,
                   "TP",
                   subwin,
                   "TP",
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y,
                   INDENT_LEFT,
                   (INDENT_TOP + BUTTON_HEIGHT) * 6 + CONTROLS_GAP_Y))
      return false;

//--- TP value label
   if(!CreateLabel(m_TPValueLabel,
                   chart,
                   "TPValue",
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
bool CAutoSLDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG && sparam == ASLineName("Entry"))
   {
      ClearConfirmation();
      if(!SyncEditFromLine(sparam))
         return false;
      if(!UpdateInfoLabels())
         return false;
      return true;
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      ClearConfirmation();
      ResetLastError();
      if(sparam == ASEditName("Risk"))
      {
         if(!UpdateRiskUSD())
            return false;
      }
      else if(sparam == ASEditName("Entry"))
      {
         if(!SyncLineFromEdit(sparam))
            return false;
      }

      if(!UpdateInfoLabels())
         return false;
      return true;
   }
   else if(id == ON_CLICK + CHARTEVENT_CUSTOM && StringFind(sparam, ".Button") != -1)
   {
      if(sparam == ASButtonName("calc"))
      {
         if(!SendPendingOrder())
            return false;
      }
      else if(sparam == ASButtonName("reset"))
      {
         ClearConfirmation();
         if(!ResetPanel())
            return false;
         return true;
      }
      else if(sparam == ASButtonName("lotIncrease"))
      {
         if(!IncreaseLotClick())
            return false;
      }
      else if(sparam == ASButtonName("lotDecrease"))
      {
         if(!DecreaseLotClick())
            return false;
      }
      return true;
   }
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::Refresh()
{
   if(!UpdateRiskUSD())
      return false;
   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//| Create buttons                                                   |
//+------------------------------------------------------------------+
bool CAutoSLDialog::CreateButton(CButton &cbutt,
                                const long chart,
                                const string name,
                                const int subwin,
                                const string text,
                                const int x1,
                                const int y1,
                                const int x2,
                                const int y2)
{
   if(!cbutt.Create(chart, ASButtonName(name), subwin, x1, y1, x2, y2))
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
bool CAutoSLDialog::CreateEdit(CEdit &cedit,
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
   if(!cedit.Create(chart, ASEditName(name), subwin, x1, y1, x2, y2))
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
bool CAutoSLDialog::CreateLabel(CLabel &clabel,
                               const long chart,
                               const string name,
                               const int subwin,
                               const string text,
                               const int x1,
                               const int y1,
                               const int x2,
                               const int y2)
{
   if(!clabel.Create(chart, ASLabelName(name), subwin, x1, y1, x2, y2))
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
bool CAutoSLDialog::ReadInputDouble(const string name, const string label, double &value, string &error_message)
{
   string text = ObjectGetString(0, ASEditName(name), OBJPROP_TEXT);
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
bool CAutoSLDialog::ReadInputs(ASInputs &inputs, string &error_message)
{
   if(!ReadInputDouble("Risk", "Risk %", inputs.risk_pct, error_message))
      return false;
   if(!ReadInputDouble("RiskReward", "RiskReward", inputs.risk_reward, error_message))
      return false;
   if(!ReadInputDouble("Entry", "Entry", inputs.entry, error_message))
      return false;
   if(!ReadInputDouble("Lot", "Lot", inputs.lot, error_message))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::SetButtonText(const string name, const string text)
{
   ResetLastError();
   if(!ObjectSetString(0, ASButtonName(name), OBJPROP_TEXT, text))
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
bool CAutoSLDialog::SetLabelText(const string name, const string text)
{
   ResetLastError();
   if(!ObjectSetString(0, ASLabelName(name), OBJPROP_TEXT, text))
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
bool CAutoSLDialog::SetLinePrice(const string name, const double price)
{
   ResetLastError();
   if(!ObjectSetDouble(0, ASLineName(name), OBJPROP_PRICE, price))
   {
      Print(__FUNCTION__,
            ": failed to change line price! Error code = ", GetLastError());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CAutoSLDialog::ClearConfirmation()
{
   m_pendingConfirm = false;
   m_confirmSignature = "";
   SetButtonText("calc", "Send");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::BuildOrderPlan(ASOrderPlan &plan, string &error_message)
{
   if(!ReadInputs(plan.inputs, error_message))
      return false;

   double raw_lot = plan.inputs.lot;
   double normalized_lot = ASNormalizeVolumeDown(plan.inputs.lot);
   if(normalized_lot <= 0.0)
   {
      error_message = "Lot cannot be normalized to a tradable volume for this symbol.";
      return false;
   }

   plan.inputs.lot = normalized_lot;
   plan.entry = ASNormalizePrice(plan.inputs.entry);
   plan.lot = normalized_lot;
   plan.risk_usd = plan.inputs.risk_pct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);
   plan.sl = 0.0;
   plan.tp = 0.0;
   plan.side = "";

   if(!ASSLFromRiskLot(plan.entry, plan.lot, plan.inputs.risk_pct, plan.inputs.risk_reward, plan.sl, plan.tp, plan.side, error_message))
      return false;

   if(MathAbs(raw_lot - normalized_lot) > 0.00000001)
   {
      if(!ObjectSetString(0,
                          ASEditName("Lot"),
                          OBJPROP_TEXT,
                          DoubleToString(normalized_lot, ASVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)))))
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::UpdatePlanDisplay(const ASOrderPlan &plan)
{
   if(!SetLabelText("SLValue", DoubleToString(plan.sl, Digits())))
      return false;
   if(!SetLinePrice("SL", plan.sl))
      return false;
   if(!SetLabelText("TPValue", DoubleToString(plan.tp, Digits())))
      return false;
   if(!SetLinePrice("TP", plan.tp))
      return false;
   if(!SetLabelText("LimitValue", plan.side))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CAutoSLDialog::PlanSignature(const ASOrderPlan &plan)
{
   return StringFormat("%s|%s|%s|%s|%s|%s|%s",
                       _Symbol,
                       plan.side,
                       DoubleToString(plan.entry, Digits()),
                       DoubleToString(plan.lot, ASVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
                       DoubleToString(plan.sl, Digits()),
                       DoubleToString(plan.tp, Digits()),
                       DoubleToString(plan.inputs.risk_pct, 4));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CAutoSLDialog::PlanText(const ASOrderPlan &plan)
{
   return StringFormat("%s %s\nLot: %s\nEntry: %s\nSL: %s\nTP: %s\nRisk: $ %.2f\nMagic: %s",
                       _Symbol,
                       plan.side,
                       DoubleToString(plan.lot, ASVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
                       DoubleToString(plan.entry, Digits()),
                       DoubleToString(plan.sl, Digits()),
                       DoubleToString(plan.tp, Digits()),
                       plan.risk_usd,
                       IntegerToString(m_magicNumber));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::UpdateRiskUSD()
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
bool CAutoSLDialog::SyncEditFromLine(const string line_name)
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
bool CAutoSLDialog::SyncLineFromEdit(const string edit_name)
{
   string line_name = edit_name;
   double entry = 0.0;
   string error_message = "";
   StringReplace(line_name, ".Edit", ".Line");

   if(!ReadInputDouble("Entry", "Entry", entry, error_message))
   {
      Alert(error_message);
      return true;
   }

   ResetLastError();
   if(!ObjectSetDouble(0, line_name, OBJPROP_PRICE, ASNormalizePrice(entry)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   return ObjectSetString(0, edit_name, OBJPROP_TEXT, DoubleToString(ASNormalizePrice(entry), Digits()));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CAutoSLDialog::OrderComment(const ASInputs &inputs)
{
   return StringFormat("AutoSL B:%.2f, R:%.2f %%, RR:%.2f, L:%s",
                       AccountInfoDouble(ACCOUNT_BALANCE),
                       inputs.risk_pct,
                       inputs.risk_reward,
                       DoubleToString(inputs.lot, ASVolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))));
}

//+------------------------------------------------------------------+
//| Increase Lot Click                                               |
//+------------------------------------------------------------------+
bool CAutoSLDialog::IncreaseLotClick()
{
   return AdjustLotByStep(1);
}

//+------------------------------------------------------------------+
//| Decrease Lot Click                                               |
//+------------------------------------------------------------------+
bool CAutoSLDialog::DecreaseLotClick()
{
   return AdjustLotByStep(-1);
}

//+------------------------------------------------------------------+
//| Adjust Lot by one symbol volume step                             |
//+------------------------------------------------------------------+
bool CAutoSLDialog::AdjustLotByStep(const int direction)
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

   next_lot = ASNormalizeVolumeDown(next_lot);
   if(next_lot <= 0.0)
   {
      Alert("Lot cannot be normalized to a tradable volume for this symbol.");
      return true;
   }

   ResetLastError();
   if(!ObjectSetString(0,
                       ASEditName("Lot"),
                       OBJPROP_TEXT,
                       DoubleToString(next_lot, ASVolumeDigits(volume_step))))
   {
      Print(__FUNCTION__,
            ": failed to change lot text! Error code = ", GetLastError());
      return false;
   }

   ClearConfirmation();
   return UpdateInfoLabels();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::SendPendingOrder()
{
   ASOrderPlan plan;
   string error_message = "";

   if(!BuildOrderPlan(plan, error_message))
   {
      ClearConfirmation();
      Alert(error_message);
      return true;
   }

   if(!UpdatePlanDisplay(plan))
      return false;

   string signature = PlanSignature(plan);
   if(!m_pendingConfirm || m_confirmSignature != signature)
   {
      m_pendingConfirm = true;
      m_confirmSignature = signature;
      if(!SetButtonText("calc", "Confirm"))
         return false;
      Alert("Review order, then click Confirm to send:\n" + PlanText(plan));
      return true;
   }

   string comment = OrderComment(plan.inputs);
   ResetLastError();

   if(plan.side == "BUY LIMIT")
   {
      if(!m_ct.BuyLimit(plan.lot, plan.entry, NULL, plan.sl, plan.tp, ORDER_TIME_GTC, 0, comment))
      {
         Print(__FUNCTION__,
               ": failed to send BUY LIMIT! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         Alert("Failed to send BUY LIMIT: " + m_ct.ResultRetcodeDescription());
         return false;
      }
   }
   else if(plan.side == "SELL LIMIT")
   {
      if(!m_ct.SellLimit(plan.lot, plan.entry, NULL, plan.sl, plan.tp, ORDER_TIME_GTC, 0, comment))
      {
         Print(__FUNCTION__,
               ": failed to send SELL LIMIT! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         Alert("Failed to send SELL LIMIT: " + m_ct.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      Alert("Cannot send order: invalid side.");
      return true;
   }

   ClearConfirmation();
   Alert("Order sent:\n" + PlanText(plan));
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::UpdateInfoLabels()
{
   ASOrderPlan plan;
   string error_message = "";
   bool has_plan = BuildOrderPlan(plan, error_message);
   string sl_text = (has_plan ? DoubleToString(plan.sl, Digits()) : "-");
   string tp_text = (has_plan ? DoubleToString(plan.tp, Digits()) : "-");
   string side_text = (has_plan ? plan.side : "-");

   if(!SetLabelText("SLValue", sl_text))
      return false;
   if(!SetLabelText("TPValue", tp_text))
      return false;
   if(!SetLabelText("LimitValue", side_text))
      return false;

   if(has_plan)
   {
      if(!SetLinePrice("SL", plan.sl))
         return false;
      if(!SetLinePrice("TP", plan.tp))
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CAutoSLDialog::ResetPanel()
{
   m_inpRiskPct = m_defRiskPct;
   m_inpRiskReward = m_defRiskReward;
   m_riskUSD = m_inpRiskPct / 100.0 * AccountInfoDouble(ACCOUNT_BALANCE);

   if(!SetLabelText("RiskUSD", StringFormat("$ %.2f", m_riskUSD)))
      return false;

   string target_edit[] = {"Risk", "RiskReward", "Entry", "Lot"};
   for(int i = 0; i < ArraySize(target_edit); i++)
   {
      ResetLastError();
      string obj_name = ASEditName(target_edit[i]);
      string prop_val = "";
      double dprop_val = 0.0;

      if(target_edit[i] == "Risk")
      {
         prop_val = DoubleToString(m_defRiskPct, 2);
         dprop_val = m_defRiskPct;
      }
      else if(target_edit[i] == "RiskReward")
      {
         prop_val = DoubleToString(m_defRiskReward, 2);
         dprop_val = m_defRiskReward;
      }
      else if(target_edit[i] == "Entry")
      {
         prop_val = DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), Digits());
         dprop_val = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      else if(target_edit[i] == "Lot")
      {
         prop_val = ASDefaultLotText();
      }

      if(!ObjectSetString(0, obj_name, OBJPROP_TEXT, prop_val))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }

      if(target_edit[i] != "Entry")
         continue;

      if(!SetLinePrice(target_edit[i], dprop_val))
         return false;
   }

   if(!SetLabelText("SLValue", "-"))
      return false;

   if(!SetLabelText("TPValue", "-"))
      return false;

   if(!SetLabelText("LimitValue", "-"))
      return false;

   if(!SetLinePrice("SL", SymbolInfoDouble(_Symbol, SYMBOL_ASK)))
      return false;
   if(!SetLinePrice("TP", 0.0))
      return false;

   return UpdateInfoLabels();
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
                 const long            z_order = 0)
{
   string OBJNAME = ASLineName(name);

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
