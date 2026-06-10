#include <Wire.h>

const byte NUM_Slaves = 2;
const byte slaveADRs[NUM_Slaves] = {0x10, 0x11};

const byte CMD_SYNC = 0x01;
const byte CMD_START = 0x10;
const byte CMD_CONFIG = 0x11;

void setup() {
  Wire.begin();
  Serial.begin(115200);

  sendConfig(slaveADRs[0], 0, 16, 1);

  sendStartToAll();
}

void loop() {
  sendSyncToAll(8, 1200);
  delay(100); //連続送信を防ぐためウェイト
}

void sendStartToAll() {
  for (int i = 0; i < NUM_Slaves; i++) {
    sendStart(slaveADRs[i]);
  }
}

void sendSyncToAll(uint16_t global_bar, uint16_t bpm_x10) {
  for (int i = 0; i < NUM_Slaves; i++) {
    sendSync(slaveADRs[i], global_bar, bpm_x10);
  }
}

void sendSync(byte targetADR, uint16_t global_bar, uint16_t bpm_x10) {
  Wire.beginTransmission(targetADR);

  Wire.write(CMD_SYNC);

  Wire.write(highByte(global_bar));
  Wire.write(lowByte(global_bar));

  Wire.write(highByte(bpm_x10));
  Wire.write(lowByte(bpm_x10));

  Wire.endTransmission();
}

void sendStart(byte targetADR) {
  Wire.beginTransmission(targetADR);
  Wire.write(CMD_START);
  Wire.endTransmission();
}

void sendConfig(byte targetADR, byte entry_offset, byte loop_length, byte part_id) {
  Wire.beginTransmission(targetADR);
  Wire.write(CMD_CONFIG);
  Wire.write(entry_offset);
  Wire.write(loop_length);
  Wire.write(part_id);
  Wire.endTransmission();
}
