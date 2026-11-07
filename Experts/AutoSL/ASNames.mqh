//+------------------------------------------------------------------+
//|                                                      ASNames.mqh  |
//+------------------------------------------------------------------+
#ifndef AS_NAMES_MQH
#define AS_NAMES_MQH

#include "ASConfig.mqh"

string ASObjectPrefix()
{
   return AS_OBJECT_PREFIX + "." + IntegerToString(ChartID());
}

string ASObjectName(const string name, const string kind)
{
   return ASObjectPrefix() + "." + name + "." + kind;
}

string ASButtonName(const string name)
{
   return ASObjectName(name, "Button");
}

string ASEditName(const string name)
{
   return ASObjectName(name, "Edit");
}

string ASLabelName(const string name)
{
   return ASObjectName(name, "Label");
}

string ASLineName(const string name)
{
   return ASObjectName(name, "Line");
}

#endif
