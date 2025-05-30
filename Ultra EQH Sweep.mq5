//+------------------------------------------------------------------+
//| Wick Liquidity grab + Ultra EQH Sweep + Volume Spike + Displacement |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <Indicators\Indicators.mqh>

// Input parameters
input int XDISTANCE = 10;
input int YDISTANCE = 250;
input int FontSize = 12;
input int MaxCandles = 120;
input int EQH_Lookback = 5;
input double EQH_Tolerance = 3.0;
input double VolumeSpikeMultiplier = 1.01;
input double DisplacementBodyMultiplier = 1.01;
input ENUM_TIMEFRAMES HTF = PERIOD_M5;
input ENUM_TIMEFRAMES LTF = PERIOD_M1;

input bool Use_EQH_Filter = false;

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
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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

   if (now >= (candleEndTime - 5) && now < candleEndTime)
   {
      if (lastCheckedTime != iTime(_Symbol, LTF, 0))
      {
         CheckPreviousSignalResult();

         string signal = DetectLiquidityGrabSignal();
         if (signal != "NEUTRAL")
         {
            lastSignal = signal;
            lastSignalTime = iTime(_Symbol, LTF, 0);
            totalSignals++;
         }

         DisplaySignal(signal);
         DisplayWinrate();

         lastCheckedTime = iTime(_Symbol, LTF, 0);
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
//| Liquidity Grab + EQH Sweep + Volume Spike + Displacement Logic   |
//+------------------------------------------------------------------+
string DetectLiquidityGrabSignal()
{
   int i = 1; // আগের ক্যান্ডেল দেখি

   double high = iHigh(_Symbol, LTF, i);
   double low = iLow(_Symbol, LTF, i);
   double open = iOpen(_Symbol, LTF, i);
   double close = iClose(_Symbol, LTF, i);
   long vol = iVolume(_Symbol, LTF, i);

   double body = MathAbs(close - open);
   double wickTop = high - MathMax(open, close);
   double wickBottom = MathMin(open, close) - low;

   double wickTopRatio = body > 0 ? wickTop / body : 0;
   double wickBottomRatio = body > 0 ? wickBottom / body : 0;

   bool htfRejection = CheckMTFRejection();
   bool eqhSweepBuy = CheckUltraFastEQHSweep(true);
   bool eqhSweepSell = CheckUltraFastEQHSweep(false);
   bool volumeSpike = CheckUltraFastVolumeSpike();
   bool displacementCandle = CheckUltraFastDisplacement();

   if (wickBottomRatio > 2.0 && 
       vol > iVolume(_Symbol, LTF, i + 1) &&
       htfRejection &&
       eqhSweepBuy &&
       volumeSpike &&
       displacementCandle)
   {
      if (iClose(_Symbol, HTF, 0) > iOpen(_Symbol, HTF, 0))
         return "BUY";
   }
   else if (wickTopRatio > 2.0 && 
            vol > iVolume(_Symbol, LTF, i + 1) &&
            htfRejection &&
            eqhSweepSell &&
            volumeSpike &&
            displacementCandle)
   {
      if (iClose(_Symbol, HTF, 0) < iOpen(_Symbol, HTF, 0))
         return "SELL";
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

   double htfBody = MathAbs(htfClose - htfOpen);
   double htfWickTop = htfHigh - MathMax(htfOpen, htfClose);
   double htfWickBottom = MathMin(htfOpen, htfClose) - htfLow;

   double htfWickTopRatio = htfBody > 0 ? htfWickTop / htfBody : 0;
   double htfWickBottomRatio = htfBody > 0 ? htfWickBottom / htfBody : 0;

   return (htfWickTopRatio > 1.5 || htfWickBottomRatio > 1.5);
}

//+------------------------------------------------------------------+
//| Ultra-Fast EQH Sweep Detection                                   |
//+------------------------------------------------------------------+
bool CheckUltraFastEQHSweep(bool isBullish)
{
   double currentHigh = iHigh(_Symbol, LTF, 1);
   double currentLow = iLow(_Symbol, LTF, 1);

   for (int i = 2; i <= EQH_Lookback; i++)
   {
      double pastHigh = iHigh(_Symbol, LTF, i);
      double pastLow = iLow(_Symbol, LTF, i);

      if (isBullish)
      {
         if (MathAbs(currentLow - pastLow) * MathPow(10, _Digits) <= EQH_Tolerance)
         {
            if (iClose(_Symbol, LTF, 1) > iOpen(_Symbol, LTF, 1))
               return true;
         }
      }
      else
      {
         if (MathAbs(currentHigh - pastHigh) * MathPow(10, _Digits) <= EQH_Tolerance)
         {
            if (iClose(_Symbol, LTF, 1) < iOpen(_Symbol, LTF, 1))
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Ultra-Fast Volume Spike Detection                               |
//+------------------------------------------------------------------+
bool CheckUltraFastVolumeSpike()
{
   long volCurrent = iVolume(_Symbol, LTF, 1);
   long volPrevious = iVolume(_Symbol, LTF, 2);

   if (volPrevious > 0 && volCurrent > volPrevious * VolumeSpikeMultiplier)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Ultra-Fast Displacement Candle Detection                        |
//+------------------------------------------------------------------+
bool CheckUltraFastDisplacement()
{
   double high = iHigh(_Symbol, LTF, 1);
   double low = iLow(_Symbol, LTF, 1);
   double open = iOpen(_Symbol, LTF, 1);
   double close = iClose(_Symbol, LTF, 1);

   double body = MathAbs(close - open);
   double totalRange = high - low;
   double wickTotal = totalRange - body;

   if (body > wickTotal * DisplacementBodyMultiplier)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check Previous Signal Result                                    |
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
   winrate = NormalizeDouble(winrate, 2);

   ObjectSetInteger(0, winrateLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, winrateLabel, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, winrateLabel, OBJPROP_YDISTANCE, YDISTANCE + 20);
   ObjectSetInteger(0, winrateLabel, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, winrateLabel, OBJPROP_COLOR, clrWhite);

   ObjectSetString(0, winrateLabel, OBJPROP_TEXT,
      StringFormat("Winrate: %.2f%% (%d wins / %d signals)", winrate, totalWins, totalSignals));
}