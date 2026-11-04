//+------------------------------------------------------------------+
//| TradeProEA.mq5 — روبوت TradePro Signals لـ MetaTrader 5          |
//| كيتداول تلقائياً على حساب الزبون نفسه، عند أي بروكر MT5         |
//| (Exness وغيره). المنصة لا ترى كلمة سر الزبون ولا مفاتيحه أبداً. |
//| المنطق: نفس شروط V2 الخمسة — اتجاه EMA50/200، تقاطع EMA9/21،    |
//| MACD، RSI في النطاق، قوة الاتجاه مقابل ATR. وقف 1.5×ATR وهدف 2R.|
//| ⏱️ كيقرا السوق كل 30 ثانية (Timer) ماشي غير عند الشموع.         |
//| 🛡️ حراس ضد المغامرة: مخاطرة ثابتة %، حد صفقات/يوم، وقف يومي    |
//| عند خسارة % من الرصيد، رفض السبريد العالي، صفقة واحدة فقط.      |
//| ⚠️ لا يوجد ربح مضمون — جرّب Demo أولاً أسبوعين على الأقل.       |
//| 📊 محاكاة المنطق على 1000 شمعة: 1H ≈ تعادل/ربح رقيق (ذهب +6R)  |
//| وفريم 4H خاسر (−29R): الروبوت للشارت 1H فقط.                    |
//+------------------------------------------------------------------+
#property strict
#property version "1.11"
#include <Trade/Trade.mqh>
CTrade trade;

input double InpRiskPercent = 1.0;     // المخاطرة % من الرصيد في الصفقة
input double InpSL_ATR_Mult = 1.5;     // وقف الخسارة = ATR ×
input double InpTP_R        = 2.0;     // الهدف = الوقف × R
input long   InpMagic       = 20261104;// الرقم السحري
input double InpMaxSpreadATR= 0.25;    // أقصى سبريد مقبول كنسبة من ATR (0.25 = 25%)
input bool   InpOneTrade    = true;    // صفقة واحدة في نفس الوقت
input int    InpTimerSeconds= 30;      // قراءة السوق كل كم ثانية
input int    InpMaxTradesDay= 3;       // أقصى عدد صفقات في اليوم
input double InpDailyLossPct= 3.0;     // وقف التداول اليومي عند خسارة % من الرصيد
input bool   InpVerbose     = true;    // طباعة قراءة السوق في سجل Experts كل شمعة

int hEMA9, hEMA21, hEMA50, hEMA200, hRSI, hMACD, hATR;
datetime lastBarTime = 0;
datetime lastEntryBar = 0;

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
   EventSetTimer(InpTimerSeconds);
   Print("TradeProEA: اشتغل على ", _Symbol, " — قراءة كل ", InpTimerSeconds, " ثانية — جرّب Demo أولاً!");
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
   EventKillTimer();
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
datetime DayStart(){
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0; return StructToTime(dt);
}
int TradesToday(){
   int n = 0;
   if(!HistorySelect(DayStart(), TimeCurrent())) return 0;
   for(int i = 0; i < (int)HistoryDealsTotal(); i++){
      ulong tk = HistoryDealGetTicket(i);
      if(tk && HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagic
         && HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN
         && HistoryDealGetString(tk, DEAL_SYMBOL) == _Symbol) n++;
   }
   return n;
}
double DailyPL(){
   double pl = 0;
   if(HistorySelect(DayStart(), TimeCurrent())){
      for(int i = 0; i < (int)HistoryDealsTotal(); i++){
         ulong tk = HistoryDealGetTicket(i);
         if(tk && HistoryDealGetInteger(tk, DEAL_MAGIC) == InpMagic
            && HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            pl += HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      }
   }
   for(int i = PositionsTotal()-1; i >= 0; i--){
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
         pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return pl;
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
datetime lastPrintBar = 0;
void Evaluate(){
   // الحراس أولاً — الروبوت ما كيغامرش
   if(InpOneTrade && HasOpenTrade()) return;
   if(TradesToday() >= InpMaxTradesDay) return;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0 && DailyPL() <= -balance * InpDailyLossPct / 100.0) return;
   // دخول واحد كحد أقصى في كل شمعة (القراءة كل 30 ثانية ما كتضاعفش الصفقات)
   datetime bar0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar0 == lastEntryBar) return;

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
   // فلتر السبريد نسبي لـ ATR — السبريد بالنقاط كيختلف بزاف بين الرموز والبروكرات
   double spreadPrice = ask - bid;
   bool spreadOK = (spreadPrice <= InpMaxSpreadATR * atr);
   if(InpVerbose && bar0 != lastPrintBar){
      lastPrintBar = bar0;
      Print("TradeProEA قراءة ", _Symbol, ": اتجاه ", (trendUp ? "صاعد" : (trendDn ? "هابط" : "مختلط")),
            " · RSI ", DoubleToString(rsi, 1), " · قوة ", DoubleToString(strength, 2),
            " · سبريد ", DoubleToString(100 * spreadPrice / atr, 1), "% من ATR ", (spreadOK ? "(مقبول)" : "(مرفوض — عالي)"),
            " · صفقات اليوم ", TradesToday(), "/", InpMaxTradesDay);
   }
   if(!spreadOK) return;
   if((freshUp && trendUp && macd > macdSig && rsi >= 40 && rsi <= 68 && strength > 0.08) || contUp){
      double sl = ask - InpSL_ATR_Mult * atr;
      double tp = ask + (ask - sl) * InpTP_R;
      double lot = CalcLot(ask - sl);
      if(lot > 0 && trade.Buy(lot, _Symbol, ask, sl, tp, "TradePro V2 BUY")) lastEntryBar = bar0;
   }
   if((freshDn && trendDn && macd < macdSig && rsi >= 32 && rsi <= 60 && strength > 0.08) || contDn){
      double sl = bid + InpSL_ATR_Mult * atr;
      double tp = bid - (sl - bid) * InpTP_R;
      double lot = CalcLot(sl - bid);
      if(lot > 0 && trade.Sell(lot, _Symbol, bid, sl, tp, "TradePro V2 SELL")) lastEntryBar = bar0;
   }
}
void OnTick(){
   datetime t[]; if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) < 1) return;
   if(t[0] != lastBarTime){ lastBarTime = t[0]; Evaluate(); }
}
void OnTimer(){ Evaluate(); }
//+------------------------------------------------------------------+
