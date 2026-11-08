//+------------------------------------------------------------------+
//|                                                     MMDialog.mqh |
//|                                                     will_santoso |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "will_santoso"
#property link      "https://www.mql5.com"
#property version   "1.01"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\Panel.mqh>
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

   // Decorative frames are registered before the interactive controls.
   CPanel m_BuyFrame[5], m_SellFrame[5];
   CLabel m_BuyGroupTitle, m_SellGroupTitle;

   //Button
   CButton m_buyButton;
   CButton m_sellButton;
   CButton m_resetButton;
   //Label
   CLabel m_RiskLabel;
   CLabel m_RiskUSDLabel;
   CLabel m_BuySLLabel;
   CLabel m_BuyTPLabel;
   CLabel m_BuyRRLabel;
   CLabel m_BuyLotLabel;
   CLabel m_BuyLotValueLabel;
   CLabel m_SellSLLabel;
   CLabel m_SellTPLabel;
   CLabel m_SellRRLabel;
   CLabel m_SellLotLabel;
   CLabel m_SellLotValueLabel;
   //Edit
   CEdit m_RiskEdit;
   CEdit m_BuySLEdit;
   CEdit m_BuyTPEdit;
   CEdit m_BuyRREdit;
   CEdit m_SellSLEdit;
   CEdit m_SellTPEdit;
   CEdit m_SellRREdit;

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
   bool CreateGroup(CPanel &frame[], const long chart, const string name, const int subwin,
                    const int left, const int top, const int width, const int bottom);
   bool CreateGroupEdge(CPanel &edge, const long chart, const string name, const int subwin,
                        const int x1, const int y1, const int x2, const int y2);
   bool CreateInputRow(CLabel &label, CEdit &edit, const long chart, const string name,
                       const int subwin, const string caption, const string value,
                       const int left, const int top, const int width);
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
   bool UpdateInfoLabels();
   bool UpdateBuyLotLabel(const MMInputs &inputs);
   bool UpdateSellLotLabel(const MMInputs &inputs);
   bool UpdateBuyRRLabel(const MMInputs &inputs);
   bool UpdateSellRRLabel(const MMInputs &inputs);
   bool ApplyBuyRRToTP();
   bool ApplySellRRToTP();
   bool ResetPanel();
   double DefaultBuySL(const double entry);
   double DefaultSellSL(const double entry);
   string OrderComment(const MMInputs &inputs,
                       const double entry,
                       const double sl,
                       const double tp);
   bool PrepareMarketOrder(const MMInputs &inputs,
                           const ENUM_ORDER_TYPE requested_type,
                           double &entry,
                           double &sl,
                           double &tp,
                           string &error_message);
   bool PlaceMarketOrder(const MMInputs &inputs, const ENUM_ORDER_TYPE order_type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMMDialog::CMMDialog()
{
   m_defRiskPct = 0.0;
   m_inpRiskPct = 0.0;
   m_riskUSD = 0.0;
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
   // Leave room for the native dialog border/client insets.
   int clientRight = x2 - x1 - INDENT_LEFT - INDENT_RIGHT;
   int groupLeft = 6, groupGap = 16;
   int groupWidth = (clientRight - groupLeft - groupGap) / 2;
   int buyX = groupLeft, sellX = buyX + groupWidth + groupGap;
   int groupTop = 62, groupBottom = 278;
   int resetX = (clientRight + groupLeft - BUTTON_WIDTH) / 2;

   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2) || !Caption("ExeMyCalc"))
      return false;

   // Lines and their existing names/defaults stay connected to the same inputs.
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   HLineCreate(0, "BuySL", DefaultBuySL(bid), clrOrangeRed);
   HLineCreate(0, "BuyTP", 0.0, clrGreen);
   HLineCreate(0, "SellSL", DefaultSellSL(ask), clrTomato);
   HLineCreate(0, "SellTP", 0.0, clrSeaGreen);

   if(!CreateGroup(m_BuyFrame, chart, "BuyGroup", subwin, buyX, groupTop, groupWidth, groupBottom)
      || !CreateGroup(m_SellFrame, chart, "SellGroup", subwin, sellX, groupTop, groupWidth, groupBottom)
      || !CreateLabel(m_BuyGroupTitle, chart, "BuyGroupTitle", subwin, "BUY", buyX + 14, 52, buyX + 76, 72)
      || !CreateLabel(m_SellGroupTitle, chart, "SellGroupTitle", subwin, "SELL", sellX + 14, 52, sellX + 76, 72))
      return false;

   // Shared risk row above both execution groups.
   if(!CreateLabel(m_RiskLabel, chart, "Risk", subwin, "Risk %", 14, 16, 84, 40)
      || !CreateEdit(m_RiskEdit, chart, "Risk", subwin, DoubleToString(m_inpRiskPct, 2), 92, 12, 208, 40, false)
      || !CreateLabel(m_RiskUSDLabel, chart, "RiskUSD", subwin, StringFormat("$ %.2f", m_riskUSD), 232, 16, clientRight - 12, 40))
      return false;

   if(!CreateInputRow(m_BuySLLabel, m_BuySLEdit, chart, "BuySL", subwin, "SL", DoubleToString(DefaultBuySL(bid), Digits()), buyX, 84, groupWidth)
      || !CreateInputRow(m_BuyTPLabel, m_BuyTPEdit, chart, "BuyTP", subwin, "TP", "0.0", buyX, 120, groupWidth)
      || !CreateInputRow(m_BuyRRLabel, m_BuyRREdit, chart, "BuyRR", subwin, "RR", "0.0", buyX, 156, groupWidth)
      || !CreateLabel(m_BuyLotLabel, chart, "BuyLot", subwin, "LOT", buyX + 14, 196, buyX + 64, 220)
      || !CreateLabel(m_BuyLotValueLabel, chart, "BuyLotValue", subwin, "-", buyX + 70, 196, buyX + groupWidth - 14, 220)
      || !CreateButton(m_buyButton, chart, "buy", subwin, "BUY", buyX + 14, 232, buyX + groupWidth - 14, 264))
      return false;

   if(!CreateInputRow(m_SellSLLabel, m_SellSLEdit, chart, "SellSL", subwin, "SL", DoubleToString(DefaultSellSL(ask), Digits()), sellX, 84, groupWidth)
      || !CreateInputRow(m_SellTPLabel, m_SellTPEdit, chart, "SellTP", subwin, "TP", "0.0", sellX, 120, groupWidth)
      || !CreateInputRow(m_SellRRLabel, m_SellRREdit, chart, "SellRR", subwin, "RR", "0.0", sellX, 156, groupWidth)
      || !CreateLabel(m_SellLotLabel, chart, "SellLot", subwin, "LOT", sellX + 14, 196, sellX + 64, 220)
      || !CreateLabel(m_SellLotValueLabel, chart, "SellLotValue", subwin, "-", sellX + 70, 196, sellX + groupWidth - 14, 220)
      || !CreateButton(m_sellButton, chart, "sell", subwin, "SELL", sellX + 14, 232, sellX + groupWidth - 14, 264)
      || !CreateButton(m_resetButton, chart, "reset", subwin, "RESET", resetX, 296, resetX + BUTTON_WIDTH, 328))
      return false;

   return UpdateInfoLabels();
}

// Thin edges leave an actual gap for the transparent title: no filled backdrop.
bool CMMDialog::CreateGroup(CPanel &frame[], const long chart, const string name, const int subwin,
                            const int left, const int top, const int width, const int bottom)
{
   int right = left + width;
   return CreateGroupEdge(frame[0], chart, name + ".TopLeft", subwin, left, top, left + 8, top + 1)
          && CreateGroupEdge(frame[1], chart, name + ".TopRight", subwin, left + 82, top, right, top + 1)
          && CreateGroupEdge(frame[2], chart, name + ".Left", subwin, left, top, left + 1, bottom)
          && CreateGroupEdge(frame[3], chart, name + ".Right", subwin, right - 1, top, right, bottom)
          && CreateGroupEdge(frame[4], chart, name + ".Bottom", subwin, left, bottom - 1, right, bottom);
}
bool CMMDialog::CreateGroupEdge(CPanel &edge, const long chart, const string name, const int subwin,
                                const int x1, const int y1, const int x2, const int y2)
{
   return edge.Create(chart, MMObjectName(name, "Panel"), subwin, x1, y1, x2, y2)
          && edge.BorderType(BORDER_FLAT) && edge.ColorBackground(clrSilver)
          && edge.ColorBorder(clrSilver) && Add(edge);
}
bool CMMDialog::CreateInputRow(CLabel &label, CEdit &edit, const long chart, const string name,
                               const int subwin, const string caption, const string value,
                               const int left, const int top, const int width)
{
   return CreateLabel(label, chart, name, subwin, caption, left + 14, top + 4, left + 64, top + 28)
          && CreateEdit(edit, chart, name, subwin, value, left + 70, top, left + width - 14, top + 28, false);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG && StringFind(sparam, ".Line") != -1)
   {
      if(!SyncEditFromLine(sparam))
         return false;
      MMInputs inputs = ReadInputs();
      if(sparam == MMLineName("BuySL"))
      {
         if(!UpdateBuyLotLabel(inputs))
            return false;
         if(!UpdateBuyRRLabel(inputs))
            return false;
      }
      else if(sparam == MMLineName("BuyTP"))
      {
         if(!UpdateBuyRRLabel(inputs))
            return false;
      }
      else if(sparam == MMLineName("SellSL"))
      {
         if(!UpdateSellLotLabel(inputs))
            return false;
         if(!UpdateSellRRLabel(inputs))
            return false;
      }
      else if(sparam == MMLineName("SellTP"))
      {
         if(!UpdateSellRRLabel(inputs))
            return false;
      }
      return true;
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      ResetLastError();
      if(sparam == MMEditName("Risk"))
      {
         if(!UpdateRiskUSD())
            return false;
         if(!UpdateInfoLabels())
            return false;
      }
      else if(sparam == MMEditName("BuyRR"))
      {
         if(!ApplyBuyRRToTP())
            return false;
      }
      else if(sparam == MMEditName("SellRR"))
      {
         if(!ApplySellRRToTP())
            return false;
      }
      else if(StringFind(sparam, ".Edit") != -1)
      {
         if(!SyncLineFromEdit(sparam))
            return false;
         MMInputs inputs = ReadInputs();
         if(sparam == MMEditName("BuySL"))
         {
            if(!UpdateBuyLotLabel(inputs))
               return false;
            if(!UpdateBuyRRLabel(inputs))
               return false;
         }
         else if(sparam == MMEditName("BuyTP"))
         {
            if(!UpdateBuyRRLabel(inputs))
               return false;
         }
         else if(sparam == MMEditName("SellSL"))
         {
            if(!UpdateSellLotLabel(inputs))
               return false;
            if(!UpdateSellRRLabel(inputs))
               return false;
         }
         else if(sparam == MMEditName("SellTP"))
         {
            if(!UpdateSellRRLabel(inputs))
               return false;
         }
      }
      return true;
   }
   else if(id == ON_CLICK + CHARTEVENT_CUSTOM && StringFind(sparam, ".Button") != -1)
   {
      if(sparam == MMButtonName("buy"))
      {
         MMInputs inputs = ReadInputs();
         if(!PlaceMarketOrder(inputs, ORDER_TYPE_BUY))
            return false;
      }
      else if(sparam == MMButtonName("sell"))
      {
         MMInputs inputs = ReadInputs();
         if(!PlaceMarketOrder(inputs, ORDER_TYPE_SELL))
            return false;
      }
      else if(sparam == MMButtonName("reset"))
      {
         if(!ResetPanel())
            return false;
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
   inputs.buy_sl = StringToDouble(ObjectGetString(0, MMEditName("BuySL"), OBJPROP_TEXT));
   inputs.buy_tp = StringToDouble(ObjectGetString(0, MMEditName("BuyTP"), OBJPROP_TEXT));
   inputs.buy_rr = StringToDouble(ObjectGetString(0, MMEditName("BuyRR"), OBJPROP_TEXT));
   inputs.sell_sl = StringToDouble(ObjectGetString(0, MMEditName("SellSL"), OBJPROP_TEXT));
   inputs.sell_tp = StringToDouble(ObjectGetString(0, MMEditName("SellTP"), OBJPROP_TEXT));
   inputs.sell_rr = StringToDouble(ObjectGetString(0, MMEditName("SellRR"), OBJPROP_TEXT));
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
bool CMMDialog::UpdateInfoLabels()
{
   MMInputs inputs = ReadInputs();

   if(!UpdateBuyLotLabel(inputs))
      return false;
   if(!UpdateSellLotLabel(inputs))
      return false;
   if(!UpdateBuyRRLabel(inputs))
      return false;
   if(!UpdateSellRRLabel(inputs))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::UpdateBuyLotLabel(const MMInputs &inputs)
{
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   string lot_text = "-";

   if(inputs.buy_sl > 0.0 && inputs.buy_sl < bid)
      lot_text = MMLotText(ask, inputs.buy_sl, inputs.risk_pct);

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("BuyLotValue"), OBJPROP_TEXT, lot_text))
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
bool CMMDialog::UpdateSellLotLabel(const MMInputs &inputs)
{
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   string lot_text = "-";

   if(inputs.sell_sl > ask)
      lot_text = MMLotText(bid, inputs.sell_sl, inputs.risk_pct);

   ResetLastError();
   if(!ObjectSetString(0, MMLabelName("SellLotValue"), OBJPROP_TEXT, lot_text))
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
bool CMMDialog::UpdateBuyRRLabel(const MMInputs &inputs)
{
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   string rr_text = MMRewardRiskText(ask, inputs.buy_sl, inputs.buy_tp);
   if(rr_text == "-")
      rr_text = "0.0";

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("BuyRR"), OBJPROP_TEXT, rr_text))
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
bool CMMDialog::UpdateSellRRLabel(const MMInputs &inputs)
{
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   string rr_text = MMRewardRiskText(bid, inputs.sell_sl, inputs.sell_tp);
   if(rr_text == "-")
      rr_text = "0.0";

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("SellRR"), OBJPROP_TEXT, rr_text))
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
bool CMMDialog::ApplyBuyRRToTP()
{
   MMInputs inputs = ReadInputs();
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double tp = 0.0;

   if(!MMTPFromRewardRisk(ask, inputs.buy_sl, inputs.buy_rr, tp))
      return true;

   string tp_text = DoubleToString(tp, Digits());

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("BuyTP"), OBJPROP_TEXT, tp_text))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   ResetLastError();
   if(!ObjectSetDouble(0, MMLineName("BuyTP"), OBJPROP_PRICE, tp))
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
bool CMMDialog::ApplySellRRToTP()
{
   MMInputs inputs = ReadInputs();
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double tp = 0.0;

   if(!MMTPFromRewardRisk(bid, inputs.sell_sl, inputs.sell_rr, tp))
      return true;

   string tp_text = DoubleToString(tp, Digits());

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("SellTP"), OBJPROP_TEXT, tp_text))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   ResetLastError();
   if(!ObjectSetDouble(0, MMLineName("SellTP"), OBJPROP_PRICE, tp))
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
   double ask = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double bid = MMNormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   double buy_sl = DefaultBuySL(bid);
   double sell_sl = DefaultSellSL(ask);

   m_inpRiskPct = m_defRiskPct;
   m_riskUSD = m_inpRiskPct / 100 * AccountInfoDouble(ACCOUNT_BALANCE);

   ResetLastError();
   if(!ObjectSetString(0, MMEditName("Risk"), OBJPROP_TEXT, DoubleToString(m_defRiskPct, 2)))
   {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ", GetLastError());
      return false;
   }

   if(!UpdateRiskUSD())
      return false;

   string edit_name[] = {"BuySL", "BuyTP", "BuyRR", "SellSL", "SellTP", "SellRR"};
   string edit_value[] = {
      DoubleToString(buy_sl, Digits()),
      "0.0",
      "0.0",
      DoubleToString(sell_sl, Digits()),
      "0.0",
      "0.0"
   };

   for(int i = 0; i < ArraySize(edit_name); i++)
   {
      ResetLastError();
      if(!ObjectSetString(0, MMEditName(edit_name[i]), OBJPROP_TEXT, edit_value[i]))
      {
         Print(__FUNCTION__,
               ": failed to change the text! Error code = ", GetLastError());
         return false;
      }
   }

   string line_name[] = {"BuySL", "BuyTP", "SellSL", "SellTP"};
   double line_value[] = {buy_sl, 0.0, sell_sl, 0.0};

   for(int i = 0; i < ArraySize(line_name); i++)
   {
      ResetLastError();
      if(!ObjectSetDouble(0, MMLineName(line_name[i]), OBJPROP_PRICE, line_value[i]))
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
double CMMDialog::DefaultBuySL(const double entry)
{
   double distance = MMMinimumStopsDistance();

   return MMNormalizePriceDown(entry - distance);
}

double CMMDialog::DefaultSellSL(const double entry)
{
   double distance = MMMinimumStopsDistance();

   return MMNormalizePriceUp(entry + distance);
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
bool CMMDialog::PrepareMarketOrder(const MMInputs &inputs,
                                   const ENUM_ORDER_TYPE requested_type,
                                   double &entry,
                                   double &sl,
                                   double &tp,
                                   string &error_message)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      error_message = "Cannot read current Bid/Ask for " + _Symbol;
      return false;
   }

   double bid = MMNormalizePrice(tick.bid);
   double ask = MMNormalizePrice(tick.ask);
   sl = MMNormalizePrice(requested_type == ORDER_TYPE_BUY ? inputs.buy_sl : inputs.sell_sl);
   tp = (requested_type == ORDER_TYPE_BUY ? inputs.buy_tp : inputs.sell_tp);
   tp = (tp > 0.0 ? MMNormalizePrice(tp) : 0.0);

   if(sl <= 0.0)
   {
      error_message = "SL must be a valid price.";
      return false;
   }

   if(requested_type == ORDER_TYPE_BUY)
   {
      entry = ask;
   }
   else if(requested_type == ORDER_TYPE_SELL)
   {
      entry = bid;
   }
   else
   {
      error_message = "Unsupported market order type.";
      return false;
   }

   double min_distance = MMMinimumStopsDistance();

   if(requested_type == ORDER_TYPE_BUY)
   {
      if(sl >= entry)
      {
         error_message = "BUY MARKET needs SL below Entry.";
         return false;
      }
      if(tp > 0.0 && tp <= entry)
      {
         error_message = "BUY MARKET needs TP above Entry.";
         return false;
      }
      if(min_distance > 0.0 && bid - sl < min_distance)
      {
         error_message = "BUY MARKET SL is too close to current Bid for this symbol.";
         return false;
      }
      if(min_distance > 0.0 && tp > 0.0 && tp - bid < min_distance)
      {
         error_message = "BUY MARKET TP is too close to current Bid for this symbol.";
         return false;
      }
   }
   else
   {
      if(sl <= entry)
      {
         error_message = "SELL MARKET needs SL above Entry.";
         return false;
      }
      if(tp > 0.0 && tp >= entry)
      {
         error_message = "SELL MARKET needs TP below Entry.";
         return false;
      }
      if(min_distance > 0.0 && sl - ask < min_distance)
      {
         error_message = "SELL MARKET SL is too close to current Ask for this symbol.";
         return false;
      }
      if(min_distance > 0.0 && tp > 0.0 && ask - tp < min_distance)
      {
         error_message = "SELL MARKET TP is too close to current Ask for this symbol.";
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CMMDialog::PlaceMarketOrder(const MMInputs &inputs, const ENUM_ORDER_TYPE order_type)
{
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   string validation_error = "";

   if(!PrepareMarketOrder(inputs, order_type, entry, sl, tp, validation_error))
   {
      Alert(validation_error);
      return true;
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

   if(order_type == ORDER_TYPE_BUY)
   {
      if(!m_ct.Buy(lot_val, NULL, 0.0, sl, tp, comment))
      {
         Print(__FUNCTION__,
               ": failed to send BUY MARKET! LastError = ", GetLastError(),
               ", retcode = ", m_ct.ResultRetcode(),
               " (", m_ct.ResultRetcodeDescription(), ")");
         return false;
      }
   }
   else
   {
      if(!m_ct.Sell(lot_val, NULL, 0.0, sl, tp, comment))
      {
         Print(__FUNCTION__,
               ": failed to send SELL MARKET! LastError = ", GetLastError(),
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
