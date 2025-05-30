//+------------------------------------------------------------------+
//|                                       Wick Liquidity grab.mq5    |
//|             এখন জয়ের হার (Winrate %) এবং MTF Rejection দেখাবে!   |
//+------------------------------------------------------------------+

//Liquidity Grab Detection (Wick Ratio এবং Volume Validation):
//Higher Timeframe (HTF) Confirmation:
//MTF Rejection Logic:



#property strict
#property indicator_chart_window
#property indicator_plots 0

#include <ChartObjects\ChartObjectsTxtControls.mqh>

// Input parameters
input int XDISTANCE = 10;
input int YDISTANCE = 50;
input int FontSize = 12;
input int MaxCandles = 120;
input ENUM_TIMEFRAMES HTF = PERIOD_M5; // Higher TimeFrame
input ENUM_TIMEFRAMES LTF = PERIOD_M1; // Lower TimeFrame

// Global variables
string signalLabel = "LiquidityGrabSignalLabel";
string winrateLabel = "LiquidityGrabWinrateLabel";
datetime lastCheckedTime = 0;
int totalSignals = 0;
int totalWins = 0;
string lastSignal = "";
datetime lastSignalTime = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ObjectDelete(0, signalLabel);
   ObjectDelete(0, winrateLabel);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main calculation loop                                            |
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
   datetime now = TimeCurrent();
   datetime candleEndTime = iTime(_Symbol, LTF, 0) + PeriodSeconds(LTF);

   // 1. চেক করি নতুন ক্যান্ডেল শেষ হয়েছে কিনা
   if (now >= (candleEndTime - 5) && now < candleEndTime)
   {
      if (lastCheckedTime != iTime(_Symbol, LTF, 0))
      {
         // 2. যদি আগের সিগন্যাল থাকে, সেটার ফলাফল চেক করি
         CheckPreviousSignalResult();

         // 3. নতুন সিগন্যাল বের করি
         string signal = DetectLiquidityGrabSignal();
         if (signal != "NEUTRAL")
         {
            lastSignal = signal;
            lastSignalTime = iTime(_Symbol, LTF, 0);
            totalSignals++;
         }

         // 4. চার্টে দেখাই
         DisplaySignal(signal);
         DisplayWinrate();

         lastCheckedTime = iTime(_Symbol, LTF, 0);
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
//| Liquidity Grab Detection Logic                                   |
//+------------------------------------------------------------------+
string DetectLiquidityGrabSignal()
{
   for (int i = 1; i < MaxCandles; i++)
   {
      double high = iHigh(_Symbol, LTF, i);
      double low = iLow(_Symbol, LTF, i);
      double open = iOpen(_Symbol, LTF, i);
      double close = iClose(_Symbol, LTF, i);
      long volume = iVolume(_Symbol, LTF, i);

      double body = MathAbs(close - open);
      double wickTop = high - MathMax(open, close);
      double wickBottom = MathMin(open, close) - low;

      double wickTopRatio = body > 0 ? wickTop / body : 0;
      double wickBottomRatio = body > 0 ? wickBottom / body : 0;

      // MTF Rejection Confirmation
      bool htfRejection = CheckMTFRejection();

      if (wickBottomRatio > 2.0 && volume > iVolume(_Symbol, LTF, i + 1) && htfRejection) // Bullish LG
      {
         if (iClose(_Symbol, HTF, 0) > iOpen(_Symbol, HTF, 0))
            return "BUY";
      }
      else if (wickTopRatio > 2.0 && volume > iVolume(_Symbol, LTF, i + 1) && htfRejection) // Bearish LG
      {
         if (iClose(_Symbol, HTF, 0) < iOpen(_Symbol, HTF, 0))
            return "SELL";
      }
   }
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Check MTF Rejection Logic                                        |
//+------------------------------------------------------------------+
bool CheckMTFRejection()
{
   double htfHigh = iHigh(_Symbol, HTF, 0);
   double htfLow = iLow(_Symbol, HTF, 0);
   double htfOpen = iOpen(_Symbol, HTF, 0);
   double htfClose = iClose(_Symbol, HTF, 0);

   // Example Rejection Criteria: Higher Timeframe Wick-to-Body ratio
   double htfBody = MathAbs(htfClose - htfOpen);
   double htfWickTop = htfHigh - MathMax(htfOpen, htfClose);
   double htfWickBottom = MathMin(htfOpen, htfClose) - htfLow;

   double htfWickTopRatio = htfBody > 0 ? htfWickTop / htfBody : 0;
   double htfWickBottomRatio = htfBody > 0 ? htfWickBottom / htfBody : 0;

   return (htfWickTopRatio > 1.5 || htfWickBottomRatio > 1.5); // Example Threshold
}

//+------------------------------------------------------------------+
//| Check Previous Signal Result (Win/Loss)                         |
//+------------------------------------------------------------------+
void CheckPreviousSignalResult()
{
   if (lastSignal != "" && lastSignalTime != 0)
   {
      double openNext = iOpen(_Symbol, LTF, 1);
      double closeNext = iClose(_Symbol, LTF, 1);

      if ((lastSignal == "BUY" && closeNext > openNext) ||
          (lastSignal == "SELL" && closeNext < openNext))
      {
         totalWins++;
      }

      // পুরনো সিগন্যাল রিসেট করে দেই
      lastSignal = "";
      lastSignalTime = 0;
   }
}

//+------------------------------------------------------------------+
//| Draw Signal Text on Chart                                        |
//+------------------------------------------------------------------+
void DisplaySignal(string signalText)
{
   if (ObjectFind(0, signalLabel) < 0)
      ObjectCreate(0, signalLabel, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, signalLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, signalLabel, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, signalLabel, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, signalLabel, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, signalLabel, OBJPROP_COLOR,
      signalText == "BUY" ? clrLime : signalText == "SELL" ? clrRed : clrYellow);
   ObjectSetString(0, signalLabel, OBJPROP_TEXT, "Next Candle: " + signalText);
}

//+------------------------------------------------------------------+
//| Draw Winrate Text on Chart                                       |
//+------------------------------------------------------------------+
void DisplayWinrate()
{
   if (ObjectFind(0, winrateLabel) < 0)
      ObjectCreate(0, winrateLabel, OBJ_LABEL, 0, 0, 0);

   double winrate = (totalSignals > 0) ? ((double)totalWins / totalSignals) * 100.0 : 0;

   ObjectSetInteger(0, winrateLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, winrateLabel, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, winrateLabel, OBJPROP_YDISTANCE, YDISTANCE + 20);
   ObjectSetInteger(0, winrateLabel, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, winrateLabel, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, winrateLabel, OBJPROP_TEXT,
      StringFormat("Winrate: %.2f%% (%d wins / %d signals)", winrate, totalWins, totalSignals));
}