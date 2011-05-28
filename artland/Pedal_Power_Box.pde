/**** Pedal Power Monitor 
 * Arduino code to monitor and control the Artland Pedal Power Box
 * http://pedalpower.cc
 */

char* VERSION = "0.4.0";

//define parameters
int DISPLAY_INTERVAL_MS = 2000; // when auto-display is on, display every this many milli-seconds
int READ_INTERVAL_MS = 0; // read voltage every this many milliseconds
float AVG_CYCLES = 50.0; // average voltage over this many read cycles to smooth ripple
//float AMPS_AVG_CYCLES = 10.0; // average voltage over this many read cycles to smooth ripple

int  VOLT_CUTOFF = 30; // voltage safety cutoff level
int  AMPS_CUTOFF_CONVERTER = 12; // DC to DC converter amps cutoff

int AMPS1_ADJUST = -101;
int AMPS2_ADJUST = -101;
int AMPS3_ADJUST = -101;
int AMPS4_ADJUST = -100;
int AMPS5_ADJUST = -101;

//define timing variables
unsigned long time = 0;
unsigned long timeRead = 0;
unsigned long timeDisplay = 0;

// define hardware pins
int pinVoltage = 0; // pin A0
int pinAmps1 = 7;
int pinAmps2 = 6;
int pinAmps3 = 5;
int pinAmps4 = 4;
int pinAmps5 = 3;

int pinRelay = 40; // pin 40 for mega
int pinRelayLED = 32; // pin 32 for mega
int pinConverterDisable = 52; // pin 52 for mega

// define variables
unsigned int voltsRead = 0;
float voltsAvg = 0;
int ampsTotal, amps1Read, amps2Read, amps3Read, amps4Read, amps5Read = 0;
float ampsAvg, amps1Avg, amps2Avg, amps3Avg, amps4Avg, amps5Avg = 0;
long voltsBig, ampsBig, powerBig = 0;
int amps5Adc, voltsAdc;
float volts, amps, power = 0;
int in = 0;
boolean disableBikes = false;
boolean disableConverter = false;
boolean enableCutoffs = true;
boolean enableAutoDisplay = false;
boolean enablePowerFlow = false;
unsigned int readCount = 0;

// setup ADC Cutoff Value
int adcCutoff = volts2adc(VOLT_CUTOFF);
int adcCutoffConverter = amps2AdcBig(AMPS_CUTOFF_CONVERTER);


void setup(){
  Serial.begin(9600);
  Serial.write((byte)0x00);

  // setup digital outputs
  pinMode(pinRelay, OUTPUT);
  pinMode(pinRelayLED, OUTPUT);
  pinMode(pinConverterDisable, OUTPUT);
}

void loop(){
  // read current time
  time = millis();
  
  if(time - timeRead > READ_INTERVAL_MS){  
    timeRead = time;
    readVoltsAvg();
    readAmpsBigAvg();
    doPowerFlow();
    readCount++;
    doCutoff();
  }
  
  if(enableAutoDisplay && (time - timeDisplay) > DISPLAY_INTERVAL_MS){
    timeDisplay = time;
    calcPowerBig();    
    printStuff();
    readCount = 0;
  }
  

  if (Serial.available() > 0) {
    // get incoming byte:
    in = Serial.read();
    switch(in){
      case 'v': // version
        Serial.print("Artland Pedal Power Monitor ver. ");
        Serial.println(VERSION);
        break;
      case 'a': // rAhhhh
        enableAutoDisplay = !enableAutoDisplay;
        break;
      case 'b':
        disableBikes = !disableBikes;
        doRelay();
        break;
      case 'c':
        disableConverter = !disableConverter;
        doConverterDisable();
        break;
      case 'p':
        printStuff();
        break;
      case 'e':
        Serial.print("Enable Cutoffs:");
        Serial.println(enableCutoffs);
        enableCutoffs = !enableCutoffs;
      case 'f':
        enablePowerFlow = !enablePowerFlow;
        Serial.print("Power Flow: ");
        if(enablePowerFlow)
          Serial.println("ENABLED");
        else
          Serial.println("DISABLED");
        break;
      case 'r':
        sendRaw();
        break;
      default:
        break;
    }
  }
}



//////////////////////////////// auto read ////////////////////////////////////

int voltsBigAvg = 0;

void readVoltsBigAvg(){
  voltsRead = analogRead(pinVoltage);
  voltsBigAvg = averageInt((voltsRead * 10), voltsBigAvg);
}

float voltsReadAvg = 0;

void readVoltsAvg(){
  voltsRead = analogRead(pinVoltage);
  voltsReadAvg = averageFloat(voltsRead, voltsReadAvg);
}


//
//unsigned int averageUInt(unsigned int val, unsigned int avg){
//  avg + (val - avg) / AVG_CYCLES;
//}

//int averageInt(int val, int avg){
//  return avg + (val - avg) / AVG_CYCLES;
//}

int averageInt(int val, int avg){
  if(avg == 0)
    avg = val;
  return (val + avg * (AVG_CYCLES - 1)) / (AVG_CYCLES);
}

float averageFloat(float val, float avg){
  if(avg == 0)
    avg = val;
  return (val + (avg * (AVG_CYCLES - 1))) / AVG_CYCLES;
}

int amps1BigAvg = 0;
int amps2BigAvg = 0;
int amps3BigAvg = 0;
int amps4BigAvg = 0;
int amps5BigAvg = 0;
int amps1Big = 0;
int amps2Big = 0;
int amps3Big = 0;
int amps4Big = 0;
int amps5Big = 0;
long ampsBigAvg = 0;


//void readAmpsBigAvg(){
//  amps1Read = analogRead(pinAmps1);
//  amps1BigAvg = averageInt(amps1Read * 10, amps1BigAvg);
//  amps2Read = analogRead(pinAmps2);
//  amps2BigAvg = averageInt(amps2Read * 10, amps2BigAvg);
//  amps3Read = analogRead(pinAmps3);
//  amps3BigAvg = averageInt(amps3Read * 10, amps3BigAvg);
//  amps4Read = analogRead(pinAmps4);
//  amps4BigAvg = averageInt(amps4Read * 10, amps4BigAvg);
//  amps5Read = analogRead(pinAmps5);
//  amps5BigAvg = averageInt(amps5Read * 10, amps5BigAvg);
//}

void readAmpsBigAvg(){
  amps1Read = analogRead(pinAmps1) + AMPS1_ADJUST;
  amps1BigAvg = averageInt(amps1Read * 10, amps1BigAvg);
  amps2Read = analogRead(pinAmps2) + AMPS2_ADJUST;
  amps2BigAvg = averageInt(amps2Read * 10, amps2BigAvg);
  amps3Read = analogRead(pinAmps3) + AMPS3_ADJUST;
  amps3BigAvg = averageInt(amps3Read * 10, amps3BigAvg);
  amps4Read = analogRead(pinAmps4) + AMPS4_ADJUST;
  amps4BigAvg = averageInt(amps4Read * 10, amps4BigAvg);
  amps5Read = analogRead(pinAmps5) + AMPS5_ADJUST;
  amps5BigAvg = averageInt(amps5Read * 10, amps5BigAvg);
}

//////////////////////////////////////////// safety logic ///////////////////////////////////////////

void doRelay(){
  if(disableBikes){
    Serial.println("Relay: ON");
    digitalWrite(pinRelay, HIGH);
    digitalWrite(pinRelayLED, HIGH);
  }else{
    Serial.println("Relay: OFF");
    digitalWrite(pinRelay, LOW);
    digitalWrite(pinRelayLED, LOW);
  }
}

void doConverterDisable(){
  if(disableConverter){
    Serial.println("DisableConverter: ON");
    digitalWrite(pinConverterDisable, HIGH);
  }else{
    Serial.println("DisableConverter: OFF");
    digitalWrite(pinConverterDisable, LOW);
  }
}

void doCutoff(){
  if(!enableCutoffs)
    return;

  if((adcBig2Amps(amps5BigAvg) > AMPS_CUTOFF_CONVERTER) != disableConverter){
    disableConverter = !disableConverter;
    doConverterDisable();
  }
  
  if((adcBig2Volts(voltsBigAvg) > VOLT_CUTOFF) != disableBikes){
    disableBikes = !disableBikes;
    doRelay();
  }
}


//////////////////////////////// conversions ////////////////////////////////////


static int volts2adc(float v){
 /* voltage calculations
 *
 * Vout = Vin * R2/(R1+R2), where R1 = 100k, R2 = 10K 
 * 30V * 10k/110k = 2.72V      // at ADC input, for a 55V max input range
 *
 * Val = Vout / 5V max * 1024 adc val max (2^10 = 1024 max vaue for a 10bit ADC)
 * 2.727/5 * 1024 = 558.4896 
 */
//int volt30 = 559;

/* 24v
 * 24v * 10k/110k = 2.181818181818182
 * 2.1818/5 * 1024 = 446.836363636363636
 */
//int volt24 = 447;

//adc = v * 10/110/5 * 1024 == v * 18.618181818181818;

return v * 18.618181818181818;
}

float adcFloat2Volts(float adc){
  // v = adc * 110/10 * 5 / 1024 == adc * 0.0537109375;
  return adc * 0.0537109375; // 55 / 1024 = 0.0537109375; 
}

int adc2VoltsInt(int adc){
  // v = adc * 110/10 * 5 / 1024 == adc * 0.0537109375;
  return adc * 0.0537109375; // 55 / 1024 = 0.0537109375; 
}

float adcBig2Volts(int adc){
  return (float)adc *  0.00537109375; // 55 / (1024 * 10)  = 0.00537109375; 
}


// amp sensor conversion factors
// 0.133v/A                       // sensor sensitivity (v = adc input volts, not main power system volts) 
// 5v/1024adc                     // adc2v conversion ratio
// 0A == 0.5v                     // current sensor offset

// adc2v = xadc * 5v/1024adc                         = x * 0.0048828125
// v2A = (xv - .5v) * A/.133v                        = (x - .5) * 7.518796992481203

// adc2A = ((adc * 5 / 1024) - .5) / .133            = x * 0.03671287593985 - 3.759398496240602
// adcBig2A = ((adc / 10 * 5 / 1024) - .5) / .133    = x * 0.003671287593985 - 3.759398496240602

// A2v = (xA * .133v/A) + .5v                        = x * .133 + .5
// v2adc = xv * 1024adc/5v                           = x * 204.8

// A2adc = ((A * .133) + .5) * 1024 / 5              = x * 27.2384 + 102.4
// A2adcBig = ((A * .133) + .5) * 10 * 1024 / 5      = x * 272.384 + 1024

//const float ampConvFactor = 0.03671287593985;  
//const float ampConvFactorBig = 0.003671287593985; 
//const float ampSubtractFactor = 3.759398496240602; 


float adcBig2Amps(int adc){
  //return ((((float)adc)/10.0 * 5.0 / 1024.0) - 0.5) / 0.133;
  //return ((float)adc) * 0.003671287593985 - 3.759398496240602;
  return ((float)adc) * 0.003671287593985;
}
int amps2AdcBig(int amps){
  //return amps * 272.384 + 1024;
  return amps * 272.384;
}



/************************************* manual read *************************************/

//
//int adc2AmpsInt(int adc)
//{
//  return adc * ampConvFactor; 
//}
//
//
//
//float adc2Amps(int adc)
//{
//  return (float)adc * ampConvFactor;
//}
//
//float adc2Volts(int adc)
//{
//  return (float)adc * 55 / 1024; 
//}
//
//
//float adcF2Amps(float adc)
//{
//  return adc * ampConvFactor;
//}
//
//float adcF2Volts(float adc)
//{
//  return adc * 55 / 1024; 
//}
//
//
//void calcPower()
//{
//  volts = adcF2Volts(voltsAvg);
//  ampsAvg = amps1Avg + amps2Avg + amps3Avg + amps4Avg;
//  amps = adcF2Amps(ampsAvg);
//  power = volts * amps;
//  
//  //  ampsTotal = amps1Read + amps2Read + amps3Read + amps4Read;
//
//}

void readV(){
  voltsRead = analogRead(pinVoltage);
}

void readA(){
  amps1Read = analogRead(pinAmps1) + AMPS1_ADJUST;
  amps2Read = analogRead(pinAmps2) + AMPS2_ADJUST;
  amps3Read = analogRead(pinAmps3) + AMPS3_ADJUST;
  amps4Read = analogRead(pinAmps4) + AMPS4_ADJUST;
  amps5Read = analogRead(pinAmps5) + AMPS5_ADJUST;
}

void readA2(){
  amps1Read = analogRead(pinAmps1);
  amps2Read = analogRead(pinAmps2);
  amps3Read = analogRead(pinAmps3);
  amps4Read = analogRead(pinAmps4);
  amps5Read = analogRead(pinAmps5);
}



//////////////////////////////// Output ////////////////////////////////////





void sendRaw(){
  readV();
  readA2();
    Serial.write((byte)0x7E);
    Serial.write((byte)0x7E);
    Serial.write(voltsRead); // volts LSB
    Serial.write(voltsRead >> 8); // volts MSB
    Serial.write(amps1Read);
    Serial.write(amps1Read >> 8);
    Serial.write(amps2Read);
    Serial.write(amps2Read >> 8);
    Serial.write(amps3Read);
    Serial.write(amps3Read >> 8);
    Serial.write(amps4Read);
    Serial.write(amps4Read >> 8);
    Serial.write(amps5Read);
    Serial.write(amps5Read >> 8);
}

void calcPowerBig()
{
 voltsAvg = adcFloat2Volts(voltsReadAvg);
 amps1Avg = adcBig2Amps(amps1BigAvg);
 amps2Avg = adcBig2Amps(amps2BigAvg);
 amps3Avg = adcBig2Amps(amps3BigAvg);
 amps4Avg = adcBig2Amps(amps4BigAvg);
 amps5Avg = adcBig2Amps(amps5BigAvg);
 ampsAvg = amps1Avg + amps2Avg + amps3Avg + amps4Avg + amps5Avg;
 power = voltsAvg * ampsAvg;
}

float prevPower = 0;
void doPowerFlow(){
  if(!enablePowerFlow)
    return;
  calcPowerBig();
  if (abs(prevPower - power) > 10){
    printPower(); 
    prevPower = power;
  }
}

void printPower(){
  Serial.print("Volts: ");
  Serial.print(voltsAvg);
  Serial.print(", Amps: ");
  Serial.print(ampsAvg);
  Serial.print(", Watts: ");
  Serial.print(power);
  Serial.print(", Time: ");
  Serial.print(time);

  Serial.println("");
}

void printStuff(){
  
  Serial.print("Total Volts: ");
  Serial.print(voltsAvg);
  Serial.print(", Raw Volts: ");
  Serial.print(voltsRead);

  if(voltsAvg > 30)
    Serial.print(" ***OVER*** ");
  
  Serial.print(", Bike1: ");
  Serial.print(amps1Avg);
  Serial.print(", Bike2: ");
  Serial.print(amps2Avg);
  Serial.print(", Bike3: ");
  Serial.print(amps3Avg);
  Serial.print(", Bike4: ");
  Serial.print(amps4Avg);
  Serial.print(", Aux: ");
  Serial.print(amps5Avg);
  Serial.print(", Total Amps: ");
  Serial.print(ampsAvg);

  Serial.print("  Amps Raw: ");
  Serial.print(amps1Read);
  Serial.print(", ");
  Serial.print(amps2Read);
  Serial.print(", ");
  Serial.print(amps3Read);
  Serial.print(", ");
  Serial.print(amps4Read);
  Serial.print(", ");
  Serial.print(amps5Read);
  Serial.print(", ");
  Serial.print(ampsTotal);

  Serial.print(", Power: ");
  Serial.print(power);
  Serial.print(" W");

  Serial.print(", ReadCount: ");
  Serial.print(readCount);

  Serial.println("");
}

