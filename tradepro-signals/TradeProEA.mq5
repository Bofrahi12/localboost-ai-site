//+------------------------------------------------------------------+
//| TradeProEA.mq5 — روبوت TradePro Signals لـ MetaTrader 5          |
//| كيتداول تلقائياً على حساب الزبون نفسه، عند أي بروكر MT5         |
//| (Exness وغيره). المنصة لا ترى كلمة سر الزبون ولا مفاتيحه أبداً. |
//| المنطق: نفس شروط V2 الخمسة — اتجاه EMA50/200، تقاطع EMA9/21،    |
//| MACD، RSI في النطاق، قوة الاتجاه مقابل ATR. وقف 1.5×ATR وهدف 2R.|
//| ⚠️ جرّب على حساب تجريبي (Demo) أولاً. التداول الآلي فيه خطر     |
//| خسارة حقيقية — شغّلو على مسؤوليتك وبمخاطرة صغيرة.               |
//| 📊 محاكاة المنطق على 1000 شمعة حقيقية: فريم 1H ≈ تعادل/ربح رقيق |
//| (ذهب +6R، مجموع الكريبتو +6R) — وفريم 4H خاسر (−29R): لا تستعمل  |
//| الروبوت إلا على شارت 1H.                                        |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#include <Trade/Trade.mqh>
CTrade trade;

input double InpRiskPercent = 1.0;     // المخاطرة % من الرصيد في الصفقة
input double InpSL_ATR_Mult = 1.5;     // وقف الخسارة = ATR ×
input double InpTP_R        = 2.0;     // الهدف = الوقف × R
input long   InpMagic       = 20261104;// الرقم السحري
input int    InpMaxSpreadPts= 30;      // أقصى سبريد مقبول (نقاط)
input bool   InpOneTrade    = true;    // صفقة واحدة في نفس الوقت

int hEMA9, hEMA21, hEMA50, hEMA200, hRSI, hMACD, hATR;
datetime lastBarTime = 0;

int OnInit(){
   hEMA9   = iMA(_Symbol, PERIOD_CURRENT, 9,   0, MODE_EMA, PRICE_CLOSE);
   hEMA21  = iMA(_Symbol, PERIOD_CURRENT, 21,  0, MODE_EMA, PRICE_CLOSE);
   hEMA50  = iMA(_Symbol, PERIOD_CURRENT, 50,  0, MODE_EMA, PRICE_CLOSE);
   hEMA200 = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   hMACD   = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
   hATR    = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(hEMA9==INVALID_HANDLE || hEMA200==INVALID_HANDLE || hATR==INVALID_HANDLE){
      Print("TradeProEA: فشل إنشاء المؤشرات"); return(INIT_FAILED);
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   Print("TradeProEA: اشتغل على ", _Symbol, " — جرّب Demo أولاً!");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
   IndicatorRelease(hEMA9); IndicatorRelease(hEMA21); IndicatorRelease(hEMA50);
   IndicatorRelease(hEMA200); IndicatorRelease(hRSI); IndicatorRelease(hMACD); IndicatorRelease(hATR);
}
double Buf(int handle, int buffer, int shift){
   double b[]; if(CopyBuffer(handle, buffer, shift, 1, b) < 1) return 0; return b[0];
}
bool HasOpenTrade(){
   for(int i = PositionsTotal()-1; i >= 0; i--){
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic) return true;
   }
   return false;
}
double CalcLot(double slDistancePrice){
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0 || slDistancePrice <= 0) return 0;
   double lossPerLot = (slDistancePrice / tickSize) * tickValue;
   if(lossPerLot <= 0) return 0;
   double lot = riskMoney / lossPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   return MathMax(minLot, MathMin(maxLot, NormalizeDouble(lot, 2)));
}
void OnTick(){
   // نشتغل مرة واحدة عند افتتاح شمعة جديدة فقط (إشارة الشمعة المغلقة)
   datetime t[]; if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) < 1) return;
   if(t[0] == lastBarTime) return; lastBarTime = t[0];

   if(InpOneTrade && HasOpenTrade()) return;
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPts) return;

   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   double e9_1 = Buf(hEMA9,0,1),  e9_2 = Buf(hEMA9,0,2);
   double e21_1= Buf(hEMA21,0,1), e21_2= Buf(hEMA21,0,2);
   double e50  = Buf(hEMA50,0,1), e200 = Buf(hEMA200,0,1);
   double rsi  = Buf(hRSI,0,1);
   double macd = Buf(hMACD,0,1), macdSig = Buf(hMACD,1,1);
   double atr  = Buf(hATR,0,1);
   if(atr <= 0 || close <= 0) return;

   bool trendUp = (close > e50 && e50 > e200);
   bool trendDn = (close < e50 && e50 < e200);
   bool freshUp = (e9_2 <= e21_2 && e9_1 > e21_1);
   bool freshDn = (e9_2 >= e21_2 && e9_1 < e21_1);
   double strength = MathAbs(e9_1 - e21_1) / atr;
   bool contUp = (trendUp && e9_1 > e21_1 && macd > macdSig && rsi >= 50 && rsi <= 65 && strength > 0.35);
   bool contDn = (trendDn && e9_1 < e21_1 && macd < macdSig && rsi >= 35 && rsi <= 50 && strength > 0.35);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if((freshUp && trendUp && macd > macdSig && rsi >= 40 && rsi <= 68 && strength > 0.08) || contUp){
      double sl = ask - InpSL_ATR_Mult * atr;
      double tp = ask + (ask - sl) * InpTP_R;
      double lot = CalcLot(ask - sl);
      if(lot > 0) trade.Buy(lot, _Symbol, ask, sl, tp, "TradePro V2 BUY");
   }
   if((freshDn && trendDn && macd < macdSig && rsi >= 32 && rsi <= 60 && strength > 0.08) || contDn){
      double sl = bid + InpSL_ATR_Mult * atr;
      double tp = bid - (sl - bid) * InpTP_R;
      double lot = CalcLot(sl - bid);
      if(lot > 0) trade.Sell(lot, _Symbol, bid, sl, tp, "TradePro V2 SELL");
   }
}
//+------------------------------------------------------------------+
