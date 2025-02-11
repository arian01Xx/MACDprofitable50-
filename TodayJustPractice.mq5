#include <Trade/Trade.mqh>

CTrade trade;
CPositionInfo pos;

input group "======== Trade Managmenet ============"
input ENUM_TIMEFRAMES Timeframe=PERIOD_CURRENT;
input double RiskPercent =2;
input ulong InpMagic =8234;
input int SLvsMA =20;
input double TPvsRisk =1.5;

input group "======== MACD Inputs ================="
input int FastLength =12;
input int SlowLength =26;
input int MACDSMA =9;
input ENUM_APPLIED_PRICE MACDAppPrice =PRICE_CLOSE;

input group "======== Moving Average Inputs ======="
input int MAPeriod =200;
input ENUM_MA_METHOD MAMode =MODE_EMA;
input ENUM_APPLIED_PRICE MAAppPrice =PRICE_MEDIAN;

int handleMACD, handleEMA;
double IndBuffer[];
int OpenSell, OpenBuy;

int OnInit(){

   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   handleEMA=iMA(_Symbol,Timeframe,MAPeriod,1,MAMode,MAAppPrice);
   handleMACD=iMACD(_Symbol,Timeframe,FastLength,SlowLength,MACDSMA,MACDAppPrice);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
  IndicatorRelease(handleEMA);  ///supongo para hacer mas rapido el codigo y no esté tan lento
  IndicatorRelease(handleMACD);
}

void OnTick(){
  if(!IsNewBar()) return;
  
  CopyBuffer(handleEMA,0,1,1,IndBuffer);
  double MovAVG=IndBuffer[0];
  
  ArraySetAsSeries(IndBuffer,true);
  CopyBuffer(handleMACD,0,1,2,IndBuffer);
  double MACDx1=IndBuffer[0];
  double MACDx2=IndBuffer[1];
  
  CopyBuffer(handleMACD,1,1,2,IndBuffer);
  double Signalx1=IndBuffer[0];
  double Signalx2=IndBuffer[1];
  
  double Closex1=iClose(_Symbol,Timeframe,1);
  
  CheckOpenPositions();
  
  //Buy Condition
  if(Closex1>MovAVG && MACDx1>Signalx1 && MACDx2<Signalx2 && MACDx1<0 && Signalx1<0 && OpenBuy<1){
    double entry=Closex1;
    double sl=MovAVG-SLvsMA*_Point;
    double tp=entry+(entry-sl)*TPvsRisk;
    double lots=calcLots(entry-sl);
    
    trade.Buy(lots,_Symbol,entry,sl,tp,"Nexo Noir Intelectual Corp. and Nova Noir Bank wish you the best luck");
  }
  
  //Sell Condition
  if(Closex1<MovAVG && MACDx1<Signalx1 && MACDx2>Signalx2 && MACDx1>0 && Signalx1>0 && OpenSell<1){
    double entry=Closex1;
    double sl=MovAVG+SLvsMA*_Point;
    double tp=entry-(sl-entry)*TPvsRisk;
    double lots=calcLots(sl-entry);
    
    trade.Sell(lots,_Symbol,entry,sl,tp,"Nexo Noir Intelectual Corp.and Nova Noir Bank see the future with numbers");
  }
}

bool IsNewBar(){
  static datetime previousTime=0;
  datetime currentTime=iTime(_Symbol,PERIOD_CURRENT,0);
  if(previousTime!=currentTime){
    previousTime=currentTime;
    return true;
  }
  return false;
}

void CheckOpenPositions(){
  OpenBuy=0;
  OpenSell=0;
  for(int i=PositionsTotal()-1; i>=0; i--){
    pos.SelectByIndex(i);
    if(pos.Symbol()==_Symbol && pos.Magic()==InpMagic){
      if(pos.PositionType()==POSITION_TYPE_BUY){
        OpenBuy++;
      }else if(pos.PositionType()==POSITION_TYPE_SELL){
        OpenSell++;
      }
    }
  }
}

double calcLots(double slPoints){
  double risk=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100;
  
  double ticksize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  double tickvalue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  
  double moneyPerLotstep=slPoints/ticksize*tickvalue*lotstep;
  double lots=MathFloor(risk/moneyPerLotstep)*lotstep;
  
  double minvolume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
  double maxvolume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
  
  if(maxvolume!=0){
    lots=MathMin(lots,maxvolume);
  }
  if(minvolume!=0){
    lots=MathMax(lots,minvolume);
  }
  
  lots=NormalizeDouble(lots,2);
  return lots;
}