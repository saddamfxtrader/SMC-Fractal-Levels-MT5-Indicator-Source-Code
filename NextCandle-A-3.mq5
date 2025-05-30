//+------------------------------------------------------------------+
//|                                                  NextCandleBiasMeter_Pro.mq5 |
//|                              Enhanced Pro Tier Version by YourName - 2025   |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Bias"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrNONE
#property indicator_width1  2

#include <Trade\Trade.mqh>
input ENUM_TIMEFRAMES HTF = PERIOD_M3;
input int RSIPeriod = 4;
input double RVRThreshold = 2.5;
input double VolumeSpikeMultiplier = 2.5;
input int AlertIntervalSeconds = 5;

#define STRONG_WEIGHT 1.5
#define WEAK_WEIGHT   0.5

double BiasBuffer[];
datetime lastAlertTime = 0;

int OnInit()
{
   SetIndexBuffer(0, BiasBuffer);
   return INIT_SUCCEEDED;
}

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


int periodSeconds = PeriodSeconds();


   int start = MathMax(prev_calculated - 1, 10);

   for (int i = start; i < rates_total; i++)
   {
      double bias = 0.0;

      if (CheckRSIAlignment(i, time)) bias += STRONG_WEIGHT;
      else bias -= STRONG_WEIGHT;

      if (CheckVolumeFVG(i, open, close, high, low, tick_volume)) bias += STRONG_WEIGHT;
      if (CheckLiquidityGrab(i, low, close, open, high)) bias += STRONG_WEIGHT;
      if (CheckVolumeSpike(i, tick_volume)) bias += STRONG_WEIGHT;
      if (CheckHTFStructureBias(i, time)) bias += STRONG_WEIGHT;
      if (CheckWickToBodyRatio(i, open, close, high, low)) bias += WEAK_WEIGHT;
      if (CheckMicroBOS(i, high, close, open)) bias += STRONG_WEIGHT;

      if (CheckBreakerBlock(i, high, low, open, close)) bias += STRONG_WEIGHT;
      if (CheckFVGRejection(i, high, low, close, open)) bias += STRONG_WEIGHT;
      if (CheckEQHSweep(i, high, low)) bias += STRONG_WEIGHT;
      if (CheckDisplacementCandle(i, open, close, high, low)) bias += STRONG_WEIGHT;
      if (CheckRSIDivergence(i, high, low)) bias -= WEAK_WEIGHT;

      if (i > 0) bias += BiasBuffer[i - 1] * 0.2; // Bias carry forward

      BiasBuffer[i] = bias;

     datetime candleCloseTime = time[i] + periodSeconds;
int secondsToClose = (int)(candleCloseTime - TimeCurrent());

if (i == rates_total - 1 && secondsToClose <= 5 && secondsToClose > 0 && TimeCurrent() - lastAlertTime >= AlertIntervalSeconds)

      {
         lastAlertTime = TimeCurrent();
         string signalType = (bias >= 3.0) ? "Bullish" : (bias <= -3.0) ? "Bearish" : "Neutral";
         Alert("Next Candle Bias Signal: ", signalType, " | Bias Score: ", DoubleToString(bias, 1));
      }
   }
   return rates_total;
}

bool CheckRSIAlignment(int i, const datetime &time[])
{
   int rsi_ltf_handle = iRSI(NULL, PERIOD_M1, RSIPeriod, PRICE_CLOSE);
   int rsi_htf_handle = iRSI(NULL, HTF, RSIPeriod, PRICE_CLOSE);
   if (rsi_ltf_handle == INVALID_HANDLE || rsi_htf_handle == INVALID_HANDLE) return false;

   double rsi_ltf[], rsi_htf[];
   if (CopyBuffer(rsi_ltf_handle, 0, i, 1, rsi_ltf) < 1) return false;
   int htf_index = iBarShift(NULL, HTF, time[i], true);
   if (htf_index < 0) return false;
   if (CopyBuffer(rsi_htf_handle, 0, htf_index, 1, rsi_htf) < 1) return false;

   return (rsi_ltf[0] > 55.0 && rsi_htf[0] > 55.0) || (rsi_ltf[0] < 45.0 && rsi_htf[0] < 45.0);
}

bool CheckVolumeFVG(int i, const double &open[], const double &close[], const double &high[], const double &low[], const long &tick_volume[])
{
   bool bullishFVG = (close[i] > open[i] && close[i-1] < open[i-1]);
   double avg_volume = 0.0;
   for (int j = 1; j <= 10; j++) avg_volume += (double)(tick_volume[i-j]);
   avg_volume /= 10.0;
   double current_volume = (double)(tick_volume[i]);
   return (bullishFVG && current_volume > avg_volume * VolumeSpikeMultiplier);
}

bool CheckLiquidityGrab(int i, const double &low[], const double &close[], const double &open[], const double &high[])
{
   double lower_wick = MathMin(open[i], close[i]) - low[i];
   double body = MathAbs(open[i] - close[i]);
   return (low[i] < low[i-1] && lower_wick > body && close[i] > open[i]);
}

bool CheckVolumeSpike(int i, const long &tick_volume[])
{
   double avg_volume = 0.0;
   for (int j = 1; j <= 10; j++) avg_volume += (double)(tick_volume[i-j]);
   avg_volume /= 10.0;
   double current_volume = (double)(tick_volume[i]);
   return (current_volume > avg_volume * VolumeSpikeMultiplier);
}

bool CheckHTFStructureBias(int i, const datetime &time[])
{
   int htf_index = iBarShift(NULL, HTF, time[i]);
   if (htf_index < 2) return false;

   double high0 = iHigh(NULL, HTF, htf_index);     // most recent HTF candle
   double high1 = iHigh(NULL, HTF, htf_index - 1); // previous HTF candle
   double high2 = iHigh(NULL, HTF, htf_index - 2); // two candles ago

   return (high0 > high1 && high1 > high2); // higher highs
   // return (high0 < high1 && high1 < high2); // if you want lower highs
}


bool CheckWickToBodyRatio(int i, const double &open[], const double &close[], const double &high[], const double &low[])
{
   double upper_wick = high[i] - MathMax(open[i], close[i]);
   double lower_wick = MathMin(open[i], close[i]) - low[i];
   double body = MathAbs(open[i] - close[i]);
   return (upper_wick > body * 1.5 || lower_wick > body * 1.5);
}

bool CheckMicroBOS(int i, const double &high[], const double &close[], const double &open[])
{
   return (high[i] > high[i-1] && close[i] > open[i]);
}

bool CheckBreakerBlock(int i, const double &high[], const double &low[], const double &open[], const double &close[])
{
   if (i < 2) return false;
   bool sweep = low[i] < low[i-1] && close[i] > open[i];
   bool engulf = close[i] > high[i-1];
   return sweep && engulf;
}

bool CheckFVGRejection(int i, const double &high[], const double &low[], const double &close[], const double &open[])
{
   double mid_fvg = (high[i-2] + low[i-2]) / 2.0;
   return (low[i] < mid_fvg && close[i] > open[i]);
}

bool CheckEQHSweep(int i, const double &high[], const double &low[])
{
   if (i < 3) return false;
   bool eqh = MathAbs(high[i-2] - high[i-3]) < _Point * 5;
   return eqh && high[i] > high[i-2];
}

bool CheckDisplacementCandle(int i, const double &open[], const double &close[], const double &high[], const double &low[])
{
   double body = MathAbs(close[i] - open[i]);
   double range = high[i] - low[i];
   return (body > range * 0.6 && close[i] > high[i-1]);
}

bool CheckRSIDivergence(int i, const double &high[], const double &low[])
{
   int rsi_handle = iRSI(NULL, PERIOD_M1, RSIPeriod, PRICE_CLOSE);
   if (rsi_handle == INVALID_HANDLE) return false;

   double rsi[], rsi_prev[];
   if (CopyBuffer(rsi_handle, 0, i, 1, rsi) < 1) return false;
   if (CopyBuffer(rsi_handle, 0, i+1, 1, rsi_prev) < 1) return false;

   bool price_higher = high[i] > high[i+1];
   bool rsi_lower = rsi[0] < rsi_prev[0];
   return price_higher && rsi_lower;
}
