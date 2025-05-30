#property copyright "Copyright 2024, hieuhoangcntt@gmail.com"
#property indicator_chart_window
#property indicator_plots   0

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Input Parameters
input int      XDISTANCE    = 10;
input int      YDISTANCE    = 10;
input int      FontSize     = 12;
input color    BullFVGColor = clrLime;
input color    BearFVGColor = clrRed;
input color    BullTextColor = clrLime;
input color    BearTextColor = clrRed;
input color    NeutralTextColor = clrYellow;

string label_name = "FVG_Rejection_Info";
datetime last_checked_time = 0;

bool isGreenCandle(double open, double close) { return open < close; }
bool isRedCandle(double open, double close)   { return open > close; }

bool isBullFVG(int i, const double &high[], const double &low[]) {
   return high[i-2] < low[i];
}

bool isBearFVG(int i, const double &high[], const double &low[]) {
   return low[i-2] > high[i];
}

bool isBullRejection(int i, const double &open[], const double &close[], const double &high[]) {
   return isGreenCandle(open[i-1], close[i-1]) && close[i-1] > high[i-2];
}

bool isBearRejection(int i, const double &open[], const double &close[], const double &low[]) {
   return isRedCandle(open[i-1], close[i-1]) && close[i-1] < low[i-2];
}

void draw_label(string text, color clr) {
   if (!ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0))
      return;
   ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, XDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, YDISTANCE);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, clr);
   ObjectSetString(0, label_name, OBJPROP_TEXT, text);
}

void create_fvg_box(string name, datetime time1, datetime time2, double low, double high, color box_color) {
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, low, time2, high);
   ObjectSetInteger(0, name, OBJPROP_COLOR, box_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
}

void delete_fvg_boxes(string direction) {
   int total = ObjectsTotal(0); // Chart ID: 0
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i); // Chart ID + Index
      // If it's a Bear FVG and direction is Bull, delete it
      if((direction == "Bull" && StringFind(name, "BearFVG_") == 0) ||
         (direction == "Bear" && StringFind(name, "BullFVG_") == 0)) {
         ObjectDelete(0, name);
      }
   }
}

int OnInit() {
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   ObjectDelete(0, label_name);
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
                const int &spread[]) {

   if(rates_total < 4) return(rates_total);

   datetime current_candle_time = time[rates_total - 1];

   // Only check when new candle appears
   if(current_candle_time == last_checked_time)
      return(rates_total);
   last_checked_time = current_candle_time;

   string signal_text = "❌ কোন শক্তিশালী FVG রিজেকশন নেই";
   color signal_color = NeutralTextColor;

   // Check the last 20 candles
   for(int i = rates_total - 2; i >= rates_total - 20; i--) {
      if(i < 3) break;

      // Bullish FVG + Rejection
      if(isBullFVG(i, high, low) && isBullRejection(i, open, close, high)) {
         // Delete any existing Bear FVG
         delete_fvg_boxes("Bull");

         string name = "BullFVG_" + IntegerToString(i);
         create_fvg_box(name, time[i-2], time[rates_total-1], low[i], high[i-2], BullFVGColor);
         signal_text = "✅ FVG Rejection → সম্ভাব্য Bullish ক্যান্ডেল";
         signal_color = BullTextColor;
         break;
      }

      // Bearish FVG + Rejection
      if(isBearFVG(i, high, low) && isBearRejection(i, open, close, low)) {
         // Delete any existing Bull FVG
         delete_fvg_boxes("Bear");

         string name = "BearFVG_" + IntegerToString(i);
         create_fvg_box(name, time[i-2], time[rates_total-1], high[i], low[i-2], BearFVGColor);
         signal_text = "⚠️ FVG Rejection → সম্ভাব্য Bearish ক্যান্ডেল";
         signal_color = BearTextColor;
         break;
      }
   }

   draw_label(signal_text, signal_color);
   return(rates_total);
}
