//+------------------------------------------------------------------+
//|                                                      ESNames.mqh  |
//+------------------------------------------------------------------+
#ifndef ES_NAMES_MQH
#define ES_NAMES_MQH

#include "ESConfig.mqh"

string ESObjectPrefix()
{
   return ES_OBJECT_PREFIX + "." + IntegerToString(ChartID());
}

string ESObjectName(const string name, const string kind)
{
   return ESObjectPrefix() + "." + name + "." + kind;
}

string ESButtonName(const string name)
{
   return ESObjectName(name, "Button");
}

string ESEditName(const string name)
{
   return ESObjectName(name, "Edit");
}

string ESLabelName(const string name)
{
   return ESObjectName(name, "Label");
}

string ESLineName(const string name)
{
   return ESObjectName(name, "Line");
}

string ESLineTextName(const string name)
{
   return ESObjectName(name, "LineText");
}

#endif
