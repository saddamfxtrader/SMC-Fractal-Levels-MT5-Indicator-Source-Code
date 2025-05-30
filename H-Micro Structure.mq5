//+------------------------------------------------------------------+
//|                                                      MicroSignal.mq5 |
//|                        Developed by: indicatormaster11              |
//+------------------------------------------------------------------+
#property copyright "indicatormaster11"
#property link      "https://github.com/indicatormaster11"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Trade\Trade.mqh>

input int XDISTANCE = 10;          // Horizontal distance from corner
input int YDISTANCE = 150;         // Vertical distance from corner
input int FontSize = 12;           // Font size of the label

long SignalLabel;                  // Declare label handle

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create the label
   SignalLabel = ObjectCreate(0, "SignalLabel", OBJ_LABEL, 0, 0, 0);
   if(SignalLabel == 0)
   {
      Print("Error creating label!");
      return(INIT_FAILED);
   }

   ObjectSetInteger(0, "SignalLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SignalLabel", OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, "SignalLabel", OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, "SignalLabel", OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, "SignalLabel", OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, "SignalLabel", OBJPROP_TEXT, "Waiting for signal...");

   EventSetTimer(1); // Set a timer to check every second

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "SignalLabel"); // Delete the label on deinitialization
   EventKillTimer();              // Kill the timer
}

//+------------------------------------------------------------------+
//| Custom indicator timer function                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime current_time = TimeCurrent();
   datetime candle_close_time = iTime(NULL, PERIOD_M1, 0) + 60;

   // Check if it's within 5 seconds before the M1 candle closes
   if(candle_close_time - current_time <= 5 && candle_close_time - current_time > 0)
   {
      string signal = CheckMicroStructure();
      if(signal == "BULLISH")
      {
         ObjectSetString(0, "SignalLabel", OBJPROP_TEXT, "BULLISH Signal!");
         ObjectSetInteger(0, "SignalLabel", OBJPROP_COLOR, clrLime);
      }
      else if(signal == "BEARISH")
      {
         ObjectSetString(0, "SignalLabel", OBJPROP_TEXT, "BEARISH Signal!");
         ObjectSetInteger(0, "SignalLabel", OBJPROP_COLOR, clrRed);
      }
      else
      {
         ObjectSetString(0, "SignalLabel", OBJPROP_TEXT, "No Signal Detected!");
         ObjectSetInteger(0, "SignalLabel", OBJPROP_COLOR, clrYellow);
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function (mandatory)                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // OnCalculate is mandatory for custom indicators
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Function to check Micro Structure for bullish/bearish signal     |
//+------------------------------------------------------------------+
string CheckMicroStructure()
{
   // Example: Simple Micro Structure logic
   double high1 = iHigh(NULL, PERIOD_M1, 1);
   double low1 = iLow(NULL, PERIOD_M1, 1);
   double high2 = iHigh(NULL, PERIOD_M1, 2);
   double low2 = iLow(NULL, PERIOD_M1, 2);

   // Volume comparison
   long volume1 = iVolume(NULL, PERIOD_M1, 1); // Volume of previous candle
   long volume2 = iVolume(NULL, PERIOD_M1, 2); // Volume of the candle before previous

   // Explicitly cast 'long' to 'double'
   double volume1_double = (double)volume1;
   double volume2_double = (double)volume2;

   // Check if the current candle is higher and the volume is also increasing
   if(high1 > high2 && low1 > low2)
   {
      if(volume1_double > volume2_double) // If volume is increasing, it's a stronger bullish signal
         return("BULLISH");
   }
   // Check for bearish structure with increasing volume
   else if(high1 < high2 && low1 < low2)
   {
      if(volume1_double > volume2_double) // If volume is increasing, it's a stronger bearish signal
         return("BEARISH");
   }

   return(""); // No signal
}
