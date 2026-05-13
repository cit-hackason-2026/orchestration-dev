// C++ code
//
#include <Wire.h>]
#include "Arduino_LED_Matrix.h"

ArduinoLEDMatrix matrix;

byte frame[8][12] = {
{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
{ 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1 },
{ 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
{ 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1 },
{ 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0 },
{ 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1 },
{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

const byte SlaveADR = 0x10;

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

uint16_t songBar = 0;
uint16_t bpmX10 = 1200;

unsigned long barStartUs = 0;
unsigned long barLengthUs = 2000000;

volatile unsigned long receivedTimeUs = 0;


int count = 0;

void setup()
{


  matrix.begin();

  Wire.begin(SlaveADR);
  Wire.onReceive(receiveEvent);

  Serial.begin(115200);
}

void loop()
{
  if (count % 2) {

    matrix.renderBitmap(frame, 8, 12);

  } else {
    matrix.clear();
  }
  if(newData) {
    noInterrupts();

    unsigned long rxTimeUs = receivedTimeUs;
    byte cmd = receivedCmd;
    uint16_t bar = receivedBar;
    uint16_t rxBpmX10 = receivedBpmX10;
    byte entryOffset = receivedEntryOffset;
    byte loopLength = receivedLoopLength;
    byte partId = receivedPartId;

    newData = false;

    interrupts();

    if(cmd == CMD_SYNC){
      count++;
      handleSync(bar, rxBpmX10, rxTimeUs);

      Serial.print("songBar=");
      Serial.println(songBar);
      Serial.print("BPM=");
      Serial.println(bpmX10 / 10.0);      

    }
    else if(cmd == CMD_START){
      Serial.println("START");
    }
    else if(cmd == CMD_CONFIG){
      Serial.print("entryOffset=");
      Serial.println(entryOffset);
      Serial.print("loopLength=");
      Serial.println(loopLength);
      Serial.print("partId=");
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
    receivedTimeUs = micros();
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

unsigned long calcBarUs(uint16_t bpm_x10) {
  return 60000000UL * 4UL * 10UL / bpm_x10;
}

void handleSync(uint16_t receivedBar, uint16_t receivedBpmX10, unsigned long rxTimeUs) {
  songBar = receivedBar;
  bpmX10 = receivedBpmX10;

  barStartUs = rxTimeUs;
  barLengthUs = calcBarUs(bpmX10);
}
