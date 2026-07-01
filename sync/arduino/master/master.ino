#include <Wire.h>
#include "HX711.h"   // Bogdan Necula の HX711 ライブラリが必要
#include <Servo.h>

const byte NUM_SLAVES = 4;
const byte slaveADRs[NUM_SLAVES] = {0x10, 0x11, 0x12, 0x13};

const byte CMD_SYNC   = 0x01;
const byte CMD_START  = 0x10;
const byte CMD_CONFIG = 0x11;

const int analogPin = A0;

// ロードセル（開始トリガ）
const int DT_PIN  = 3;
const int SCK_PIN = 2;
HX711 scale;

// サーボ
Servo servo;
const int SERVO_PIN = 9;
const float THRESHOLD = 50.0;   // この重さ(g)を超えている間だけ演奏。実測に合わせ調整
int MOVE_US = 1480;             // 回転速度（将来 BPM 連動の余地。今回は固定）
const int STOP_US = 1500;       // 停止

const int WEIGHT_SAMPLES = 3;   // start.ino の get_units(3) 相当の平滑化
float weightBuf[WEIGHT_SAMPLES] = {0, 0, 0};
int weightIdx = 0;
float lastWeight = 0.0f;        // 直近の重さ（3サンプル移動平均）
bool playing = false;           // 現在演奏中か（重さ > 閾値）
bool everStarted = false;       // 一度でも START を送ったか

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

  // ロードセル初期化（tare は小物を置く前＝電源投入時に実行）
  scale.begin(DT_PIN, SCK_PIN);
  scale.set_scale(2280);  // キャリブレーションで設定した値，必要があれば変更を加える
  scale.tare();

  // サーボは初期停止
  servo.attach(SERVO_PIN);
  servo.writeMicroseconds(STOP_US);

  delay(500);

  // 旋律スレーブ（2小節ずつずらして輪唱）
  for (byte i = 0; i < 3; i++) {
    sendConfig(slaveADRs[i], i * 2, 16, i + 1);
  }
  // ドラムスレーブ（遅延なしでメロディと同時スタート）
  sendConfig(slaveADRs[3], 0, 12, 4);

  delay(100);

  // START と同期開始はロードセルのトリガ時に行う（loop 参照）

  Serial.println("準備完了");
}

void loop() {
  // ロードセル非ブロッキング更新（3サンプル移動平均＋重さログ）
  if (scale.is_ready()) {
    weightBuf[weightIdx] = scale.get_units(1);
    weightIdx = (weightIdx + 1) % WEIGHT_SAMPLES;
    lastWeight = (weightBuf[0] + weightBuf[1] + weightBuf[2]) / 3.0f;

    Serial.print("重さ: ");
    Serial.print(lastWeight, 1);
    Serial.println(" g");
  }
  bool present = (lastWeight > THRESHOLD);

  // 置かれた瞬間: 演奏開始／再開
  if (present && !playing) {
    playing = true;
    servo.writeMicroseconds(MOVE_US);  // 演奏中はサーボ回転
    delay(2200);  // サーボが一周するのを待つ
    if (!everStarted) {          // 最初の1回だけ START でスレーブ初期化
      sendStartToAll();
      everStarted = true;
    }
    nextSyncUs = micros();       // 復帰時のバースト送信を防ぎ即再開
  }

  // 取り除かれた瞬間: 通信停止＋サーボ停止
  if (!present && playing) {
    playing = false;
    servo.writeMicroseconds(STOP_US);
  }

  if (!playing) return;          // 重さが無い間は SYNC を送らない＝通信停止

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
