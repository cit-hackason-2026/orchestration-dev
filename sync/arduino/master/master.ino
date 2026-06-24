#include <Wire.h>

const byte NUM_SLAVES = 4;
const byte slaveADRs[NUM_SLAVES] = {0x10, 0x11, 0x12, 0x13};

const byte CMD_SYNC   = 0x01;
const byte CMD_START  = 0x10;
const byte CMD_CONFIG = 0x11;

uint16_t global_bar = 0;
uint16_t bpmX10 = 1200;

unsigned long nextSyncUs = 0;

// --- BPM 管理（master.ino に追記） ---
float current_bpm = 120.0f;
float target_bpm  = 120.0f;
const float BPM_MIN = 60.0f;
const float BPM_MAX = 180.0f;
const float BPM_DELTA_MAX = 10.0f; // 1小節あたり
   
float clamp_range(float v){
  if (v < BPM_MIN) return BPM_MIN;
  if (v > BPM_MAX) return BPM_MAX;
  return v;
}
   
uint16_t encode_bpm10(float bpm){
  bpm = clamp_range(bpm);
  return (uint16_t)(bpm * 10.0f + 0.5f);
}

void setup() {
  Wire.begin();
  Serial.begin(115200);

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
  unsigned long now = micros();

  if ((long)(now - nextSyncUs) >= 0) {
    sendSyncToAll(global_bar, bpmX10);

    global_bar++;
    nextSyncUs += calcBarUs(bpmX10);
  }
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

// 実装：SYNC ペイロードを送る（Serial / RF に合わせて書く）
void send_sync_payload(uint8_t h, uint8_t l){
  // 例: Serial1.write(h); Serial1.write(l);
  // または radio.send(...) へパッケージ化して送信
}
   
// センサ読み取り時に呼ぶ（即時 target に保存）
void onSensorRead(float sensor_bpm){
  target_bpm = clamp_range(sensor_bpm);
}

// 小節頭で呼ぶ（既存のタイミング検出に追加）
void onMeasureStart_bpm_master(){
  float delta = target_bpm - current_bpm;
  if (delta > BPM_DELTA_MAX) delta = BPM_DELTA_MAX;
  else if (delta < -BPM_DELTA_MAX) delta = -BPM_DELTA_MAX;
  current_bpm += delta;
  uint16_t bpm10 = encode_bpm10(current_bpm);
  uint8_t payload_h = (uint8_t)(bpm10 >> 8);
  uint8_t payload_l = (uint8_t)(bpm10 & 0xFF);
  send_sync_payload(payload_h, payload_l);
}