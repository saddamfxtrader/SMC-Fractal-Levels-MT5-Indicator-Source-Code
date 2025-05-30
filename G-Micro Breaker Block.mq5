//+------------------------------------------------------------------+
//|     M1 Micro Breaker Block Label Signal Indicator (No Arrows)   |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict

#property indicator_buffers 1
#property indicator_plots   1

double DummyBuffer[];

// Input Parameters
input int    XDISTANCE     = 10;
input int    YDISTANCE     = 130;
input int    FontSize      = 12;
input color  BullishColor  = clrLime;
input color  BearishColor  = clrRed;
input color  NoSignalColor = clrYellow;

// Global variables
string label_name = "M1_BreakerBlock_Label";
datetime last_processed = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);  // No drawing will be done

   EventSetTimer(1);
   CreateLabel("Waiting for signal...", NoSignalColor);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Timer function: check signal 5 seconds before candle close      |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime local_time  = TimeLocal();
   datetime candle_time = iTime(_Symbol, PERIOD_M1, 0);
   int seconds_passed   = int(local_time - candle_time);
   int seconds_remaining = 60 - seconds_passed;

   // Check only in last 5 seconds of current candle
   if (seconds_remaining <= 5 && candle_time != last_processed)
   {
      last_processed = candle_time;

      int current = iBarShift(_Symbol, PERIOD_M1, TimeCurrent(), false);
      if (current < 0) return;

      bool isBullish = false;

      if (CheckMicroBreakerBlock(current, isBullish))
      {
         if (isBullish)
            CreateLabel("Bullish Signal (Micro Breaker Block)", BullishColor);
         else
            CreateLabel("Bearish Signal (Micro Breaker Block)", BearishColor);
      }
      else
      {
         CreateLabel("No Valid Signal", NoSignalColor);
      }
   }
}

//+------------------------------------------------------------------+
//| Micro Breaker Block logic with Volume Check                      |
//+------------------------------------------------------------------+
bool CheckMicroBreakerBlock(int current, bool &isBullish)
{
   if (current < 3) return false;

   double prevHigh = iHigh(_Symbol, PERIOD_M1, current + 1);
   double prevLow  = iLow(_Symbol, PERIOD_M1, current + 1);
   double currHigh = iHigh(_Symbol, PERIOD_M1, current);
   double currLow  = iLow(_Symbol, PERIOD_M1, current);

   double prevVolume = (double)iVolume(_Symbol, PERIOD_M1, current + 1);  // Previous candle volume as double
double currVolume = (double)iVolume(_Symbol, PERIOD_M1, current);      // Current candle volume as double


   // Check for Bullish pattern and higher volume
   if (currLow > prevLow && currHigh > prevHigh && currVolume > prevVolume)
   {
      isBullish = true;
      return true;
   }
   // Check for Bearish pattern and higher volume
   else if (currHigh < prevHigh && currLow < prevLow && currVolume > prevVolume)
   {
      isBullish = false;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Label drawer                                                    |
//+------------------------------------------------------------------+
void CreateLabel(string text, color c)
{
   if (!ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0))
      ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, label_name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| OnCalculate (dummy, required for custom indicator)              |
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
   return rates_total;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete(0, label_name);
}
