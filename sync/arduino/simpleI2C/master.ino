#include <Wire.h>

void setup()
{
  Wire.begin();
  Serial.begin(115200);
}

void loop()
{
  Wire.beginTransmission(0x11);
  Wire.write(0x01);
  Wire.endTransmission();

  
  Wire.requestFrom(0x11,1,true);
  
  byte val = Wire.read();
  Serial.println(val);
  
  delay(500);
  
  
}