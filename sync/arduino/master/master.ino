#include <Wire.h>

const byte NUM_SLAVES = 4;
const byte slaveADRs[NUM_SLAVES] = {0x10, 0x11, 0x12, 0x13};

const byte CMD_SYNC   = 0x01;
const byte CMD_START  = 0x10;
const byte CMD_CONFIG = 0x11;

const int analogPin = A0;

float current_bpm = 120.0f;   // 現在適用中のBPM
float target_bpm  = 120.0f;   // ポテンショメータから得た目標BPM

const float BPM_MIN = 60.0f;
const float BPM_MAX = 180.0f;
const float BPM_DELTA_MAX = 10.0f;

uint16_t global_bar = 0;
uint16_t bpmX10 = 1200;

unsigned long nextSyncUs = 0;

float clamp_range(float v) {
  if (v < BPM_MIN) return BPM_MIN;
  if (v > BPM_MAX) return BPM_MAX;
  return v;
}

//ポテンショメータ読み取り
// 0〜1023 → 60〜180BPM
void readPotentiometer() {
  int val = analogRead(analogPin);
  target_bpm =
      BPM_MIN +
      ((float)val / 1023.0f) *
      (BPM_MAX - BPM_MIN);
  target_bpm = clamp_range(target_bpm);
}

void setup() {
  Wire.begin();
  Serial.begin(115200);
  pinMode(analogPin, INPUT);
  delay(500);

  // 旋律スレーブ（2小節ずつずらして輪唱）
  for (byte i = 0; i < 3; i++) {
    sendConfig(slaveADRs[i], i * 2, 16, i + 1);
  }
  // ドラムスレーブ（遅延なしでメロディと同時スタート）
  sendConfig(slaveADRs[3], 0, 12, 4);

  delay(100);

  sendStartToAll();

  nextSyncUs = micros() + 500000UL;
}

void loop() {
  readPotentiometer();
  unsigned long now = micros();

  if ((long)(now - nextSyncUs) >= 0) {

    //小節頭でのみBPM変更
    float delta = target_bpm - current_bpm;
    if (delta > BPM_DELTA_MAX)
      delta = BPM_DELTA_MAX;
    else if (delta < -BPM_DELTA_MAX)
      delta = -BPM_DELTA_MAX;
    current_bpm += delta;
    bpmX10 = (uint16_t)(current_bpm * 10.0f + 0.5f);

    sendSyncToAll(global_bar, bpmX10);

    global_bar++;
    nextSyncUs += calcBarUs(bpmX10);
  }

  Serial.print("BPM:");
  Serial.println(bpmX10 / 10);
}

unsigned long calcBarUs(uint16_t bpm_x10) {
  if (bpm_x10 == 0) return 2000000UL;
  return 60000000UL * 4UL * 10UL / bpm_x10;
}

void sendStartToAll() {
  for (byte i = 0; i < NUM_SLAVES; i++) {
    sendStart(slaveADRs[i]);
  }
}

void sendSyncToAll(uint16_t song_bar, uint16_t bpm_x10) {
  for (byte i = 0; i < NUM_SLAVES; i++) {
    sendSync(slaveADRs[i], song_bar, bpm_x10);
  }
}

void sendSync(byte targetADR, uint16_t song_bar, uint16_t bpm_x10) {
  Wire.beginTransmission(targetADR);
  Wire.write(CMD_SYNC);
  Wire.write(highByte(song_bar));
  Wire.write(lowByte(song_bar));
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
