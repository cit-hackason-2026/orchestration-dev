#include <Wire.h>

byte SlaveADR = 0x11;

volatile byte receiveData = 0;
volatile bool newData = false;

void setup()
{
  Wire.begin(SlaveADR);
  Wire.onReceive(receiveEvent);
  Wire.onRequest(requestEvent);
  Serial.begin(115200);
}

void loop()
{
  if(newData == true) {
    Serial.println(receiveData);
    newData = false;
  }
  delay(100);
    
}

void receiveEvent(int howMany){
  while(Wire.available()){
    receiveData = Wire.read();
    newData = true;
  }
}

void requestEvent(){
  Wire.write(receiveData);
}