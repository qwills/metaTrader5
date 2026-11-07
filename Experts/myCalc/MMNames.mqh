//+------------------------------------------------------------------+
//|                                                      MMNames.mqh  |
//+------------------------------------------------------------------+
#ifndef MM_NAMES_MQH
#define MM_NAMES_MQH

#include "MMConfig.mqh"

string MMObjectName(const string name, const string kind)
{
   return MM_OBJECT_PREFIX + "." + name + "." + kind;
}

string MMButtonName(const string name)
{
   return MMObjectName(name, "Button");
}

string MMEditName(const string name)
{
   return MMObjectName(name, "Edit");
}

string MMLabelName(const string name)
{
   return MMObjectName(name, "Label");
}

string MMLineName(const string name)
{
   return MMObjectName(name, "Line");
}

#endif

