// comm_offset_measure.ino
// 通信由来の固定オフセット(I2C逐次配信スキュー)のベースライン測定用 計測専用ファーム
// ─────────────────────────────────────────────────────────────
// 役割:
//   - 本番の master と同じ手順で 0x10→0x11→0x12→0x13 へ順番に SYNC(0x01) を送る
//   - その「各スレーブへの送信完了時刻」を master 自身の単一 micros() で打刻し、
//     スロット間の差(=各スレーブが SYNC を受け取る時刻のスキュー)を CSV で出力する
//   - これは drift_measure.ino(スレーブ側)の「通信版」にあたるマスター側ファーム
//
// なぜ master 単独で測れるか:
//   楽器間の絶対スキューは共通クロックが要る。master が全スレーブへ順番に送る
//   送信完了時刻を 1 本の micros() で打刻すれば、その差がそのままスキューになる。
//   同一小節内の差分しか使わないので、master のクリスタル/micros() ドリフトは
//   相殺され、純粋な I2C 送信時間(=通信オフセット)だけが残る。
//   → 既存 drift_measure.ino が「前後差で相殺されて測れない」と書いていた
//     固定オフセットを、こちらは正面から測る。
//
// 測れる範囲: I2C 逐次配信スキュー(支配的成分) / 各スロットの送信所要時間
//             (=削減プラン 変更4 の I2C_SLOT_US 実測値) / バー間のジッタ。
// 測れない範囲: 各スレーブ ISR 内の処理遅延(rxTimeUs を取るまでの ~450µs)。
//             ただし全スレーブほぼ等しい共通成分で、スレーブ"間"のスキューには
//             ほぼ効かないため、固定オフセット計測の目的には十分。
//
// 使い方:
//   1. このスケッチを master のボードに書き込む
//   2. スレーブ4台(実スレーブ or drift_measure ボード)をバスに接続し電源を入れる
//        ※ ACK が要るので 4 台ともバス上にいること
//   3. シリアルモニタ(115200)で目視、または端末で CSV にリダイレクトして収集
//        例(mac): cat /dev/cu.usbmodemXXXX > comm_offset_100k.csv
//   4. (任意)下の Wire.setClock(400000) のコメントを外すと 400kHz で再計測でき、
//        削減プラン 変更1 の効果(スキュー約 1/4)を実機で裏取りできる
//
// 出力フォーマット(CSV):
//   bar,slot,addr,tx_us,skew_us,err
//     bar     : master の global_bar
//     slot    : 送信順(0=flute / 1=clarinet / 2=organ / 3=drum)
//     addr    : スレーブの I2C アドレス(16進)
//     tx_us   : このスロットの I2C 送信所要時間(µs) = I2C_SLOT_US 実測値
//     skew_us : slot0(flute)の受信完了を 0 とした各スレーブの受信スキュー(µs)
//               ← これが通信由来の固定オフセットそのもの。drum の値が削減対象の主役
//     err     : Wire.endTransmission() の戻り値(0=ACK成功)。0以外=そのアドレスに
//               スレーブがいない(配線/アドレスミス)
// ─────────────────────────────────────────────────────────────

#include <Wire.h>

const byte NUM_SLAVES = 4;
const byte slaveADRs[NUM_SLAVES] = {0x10, 0x11, 0x12, 0x13};

const byte CMD_SYNC   = 0x01;
const byte CMD_START  = 0x10;
const byte CMD_CONFIG = 0x11;

uint16_t global_bar = 0;
uint16_t bpmX10 = 1200;

unsigned long nextSyncUs = 0;

void setup() {
  Wire.begin();
  Wire.setClock(400000); 
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

  Serial.println(F("bar,slot,addr,tx_us,skew_us,err"));  // CSVヘッダ

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

// 各スレーブへ順番に SYNC を送り、送信完了時刻を打刻して CSV を出す計測版
void sendSyncToAll(uint16_t song_bar, uint16_t bpm_x10) {
  unsigned long ta[NUM_SLAVES];   // 各スロットの endTransmission 完了時刻
  unsigned long tb[NUM_SLAVES];   // 各スロットの beginTransmission 直前時刻
  byte          err[NUM_SLAVES];  // endTransmission の戻り値(0=ACK成功)

  // ── 4スロットを連続送信し、各完了時刻を1本の micros() で打刻 ──
  //    （この4回の間に Serial.print を挟まない＝計測を歪めない）
  for (byte i = 0; i < NUM_SLAVES; i++) {
    tb[i] = micros();
    Wire.beginTransmission(slaveADRs[i]);
    Wire.write(CMD_SYNC);
    Wire.write(highByte(song_bar));
    Wire.write(lowByte(song_bar));
    Wire.write(highByte(bpm_x10));
    Wire.write(lowByte(bpm_x10));
    err[i] = Wire.endTransmission();
    ta[i] = micros();
  }

  // ── 4回ぜんぶ終わってから CSV を出力（次のSYNCまで約2秒あるので安全）──
  for (byte i = 0; i < NUM_SLAVES; i++) {
    long tx   = (long)(ta[i] - tb[i]);   // このスロットの送信所要時間 = I2C_SLOT_US実測
    long skew = (long)(ta[i] - ta[0]);   // slot0完了を基準にした受信スキュー
    Serial.print(song_bar);            Serial.print(',');
    Serial.print(i);                   Serial.print(',');
    Serial.print(slaveADRs[i], HEX);   Serial.print(',');
    Serial.print(tx);                  Serial.print(',');
    Serial.print(skew);                Serial.print(',');
    Serial.println(err[i]);
  }
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
