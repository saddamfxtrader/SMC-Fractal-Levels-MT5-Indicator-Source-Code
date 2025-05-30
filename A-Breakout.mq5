//+------------------------------------------------------------------+
//|                                             NextCandleForecast.mq5 |
//|                     Forecasts next candle breakout direction     |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   0

#include <ChartObjects\ChartObjectsTxtControls.mqh>

// Input parameters
input int      xDistance = 10;
input int      yDistance = 10;
input int      FontSize  = 12;
input ENUM_TIMEFRAMES HTF = PERIOD_M5;
input ENUM_TIMEFRAMES LTF = PERIOD_M1;
input int      SignalDisplayTime = 60;  // Time in seconds to display signal

string labelName = "NextCandleForecastLabel";
double dummyBuffer[];

// A variable to track when the signal was last displayed
datetime lastSignalTime = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, dummyBuffer, INDICATOR_DATA);
   CreateLabel();
   EventSetTimer(1);  // Check every second
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectDelete(0, labelName);
  }

//+------------------------------------------------------------------+
//| Timer event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime currentTime = TimeCurrent();
   datetime candleClose = iTime(_Symbol, LTF, 0) + PeriodSeconds(LTF);

   // Check if it's within 5 seconds of candle close
   if((candleClose - currentTime) <= 5 && (candleClose - currentTime) > 0)
     {
      string signalText = GetForecastSignal();
      UpdateLabel(signalText);
      lastSignalTime = currentTime;  // Update the last signal time
     }
   
   // Check if it's time to remove the signal after SignalDisplayTime seconds
   if(currentTime - lastSignalTime > SignalDisplayTime)
     {
      UpdateLabel("No Clear Breakout");  // Remove signal after timeout
     }
  }

//+------------------------------------------------------------------+
//| Forecast Signal Based on Simple Breakout Logic                   |
//+------------------------------------------------------------------+
string GetForecastSignal()
  {
   double ltfHighPrev = iHigh(_Symbol, LTF, 1);
   double ltfLowPrev  = iLow(_Symbol, LTF, 1);
   double ltfClosePrev = iClose(_Symbol, LTF, 1);

   double htfClosePrev = iClose(_Symbol, HTF, 1);

   double ltfCurrentClose = iClose(_Symbol, LTF, 0);
   double htfCurrentClose = iClose(_Symbol, HTF, 0);

   // Breakout + HTF confirmation logic
   if(ltfCurrentClose > ltfHighPrev && htfCurrentClose > htfClosePrev)
      return "Bullish Breakout Likely";
   else if(ltfCurrentClose < ltfLowPrev && htfCurrentClose < htfClosePrev)
      return "Bearish Breakout Likely";
   else
      return "No Clear Breakout";
  }

//+------------------------------------------------------------------+
//| Create chart label                                               |
//+------------------------------------------------------------------+
void CreateLabel()
  {
   if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
      Print("Failed to create label!");
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xDistance);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yDistance);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//| Update label with forecast text                                  |
//+------------------------------------------------------------------+
void UpdateLabel(string text)
  {
   ObjectSetString(0, labelName, OBJPROP_TEXT, "Next Candle: " + text);

   if(text == "Bullish Breakout Likely")
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLime);     // সবুজ
   else if(text == "Bearish Breakout Likely")
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrRed);      // লাল
   else if(text == "No Clear Breakout")
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);   // হলুদ
  }

//+------------------------------------------------------------------+
//| Mandatory for custom indicator                                   |
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
   return(rates_total);
  }
//+------------------------------------------------------------------+




