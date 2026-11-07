#ifndef SWING_TYPES_MQH
#define SWING_TYPES_MQH

enum ENUM_SWING_TYPE { SWING_HIGH, SWING_LOW };
enum ENUM_SWING_EQUAL_POLICY
{
   SWING_EQUAL_REJECT, // Strict high/low: ties disqualify the candidate.
   SWING_EQUAL_FIRST,  // Earliest equal extreme in the comparison window.
   SWING_EQUAL_LAST    // Latest equal extreme in the comparison window.
};

struct SwingPoint
{
   datetime time;       // Open time of the pivot candle, not detection time.
   double price;
   ENUM_SWING_TYPE type;
   bool confirmed;
};

#endif // SWING_TYPES_MQH
