// C++ code
//
#include <Wire.h>

const byte SlaveADR = 0x11;

const byte CMD_SYNC = 0x01;
const byte CMD_START = 0x10;
const byte CMD_CONFIG = 0x11;

volatile byte receivedCmd = 0; // receiveCmd から修正
volatile bool newData = false;

volatile uint16_t receivedBar = 0;
volatile uint16_t receivedBpmX10 = 0;

volatile byte receivedEntryOffset = 0;
volatile byte receivedLoopLength = 0;
volatile byte receivedPartId = 0;

int led = 7;

void setup()
{
  pinMode(led, OUTPUT);
  
  Wire.begin(SlaveADR);
  Wire.onReceive(receiveEvent);

  Serial.begin(115200);
}

void loop()
{
  if(newData) {
    noInterrupts(); // noInterrupt から修正
    
    byte cmd = receivedCmd;
    uint16_t bar = receivedBar;
    uint16_t bpmX10 = receivedBpmX10; // receibedBpmX10 から修正
    byte entryOffset = receivedEntryOffset;
    byte loopLength = receivedLoopLength;
    byte partId = receivedPartId;
    
    newData = false;
    
    interrupts();
    
    if(cmd == CMD_SYNC){
      Serial.println(bar);
      Serial.println(bpmX10 / 10.0); // bpm10 から修正
      digitalWrite(led, HIGH);
      delay(10);
      digitalWrite(led, LOW);
    }else if(cmd == CMD_START){
      Serial.println("START");
    }else if(cmd == CMD_CONFIG){
      Serial.println(entryOffset); // entryOfsset から修正
      Serial.println(loopLength);
      Serial.println(partId);
    }
  }
}

void receiveEvent(int howMany)
{
  if (howMany < 1) {
    return;
  }

  byte cmd = Wire.read();

  if (cmd == CMD_SYNC && howMany == 5) {
    byte barHigh = Wire.read();
    byte barLow  = Wire.read();
    byte bpmHigh = Wire.read();
    byte bpmLow  = Wire.read();

    receivedCmd = cmd;
    receivedBar = ((uint16_t)barHigh << 8) | barLow;
    receivedBpmX10 = ((uint16_t)bpmHigh << 8) | bpmLow;
    newData = true;
  }
  else if (cmd == CMD_START && howMany == 1) {
    receivedCmd = cmd;
    newData = true;
  }
  else if (cmd == CMD_CONFIG && howMany == 4) {
    receivedCmd = cmd;
    receivedEntryOffset = Wire.read();
    receivedLoopLength = Wire.read();
    receivedPartId = Wire.read();
    newData = true;
  }
  else {
    while (Wire.available()) {
      Wire.read();
    }
  }
}