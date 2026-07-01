// drum.pde
// ArduinoからバイナリSerialでドラムイベントを受信し、
// processing.soundライブラリでキック・ハイハットを再生する
// ─────────────────────────────────────────────────────────────

import processing.sound.*;
import processing.serial.*;

// ─── シリアルポート設定（環境に合わせて変更する）──────────────
final String SERIAL_PORT = "/dev/cu.usbmodem34B7DA636BDC2";
final int BAUD_RATE = 115200;

// ─── バイナリプロトコル定数 ───────────────────────────────────
final int SERIAL_MARKER = 0xAA;
final int INST_DRUM     = 0x04;
final int DRUM_KICK     = 36;
final int DRUM_HIHAT    = 42;

// ─── Serial関連 ───────────────────────────────────────────────
Serial myPort;

// バイナリパケット受信ステートマシン
// 状態0: マーカー(0xAA)待ち
// 状態1: 楽器種別バイト待ち
// 状態2: ペイロード3バイト受信中 (pitch, velocity, duration_8ms)
int   rxState  = 0;
int   rxInstId = 0;
int   rxCount  = 0;
int[] rxBuf    = new int[3];

// ─── デバッグ表示用 ──────────────────────────────────────────
int lastPitch = 0;
int lastDurMs = 0;

// ─── 疑似波形バッファ ─────────────────────────────────────────
// processing.sound はマスター出力バッファを直接読めないため、
// 発音中の振幅にホワイトノイズを乗せて循環バッファに書き込み、
// Minim 系スケッチと同じ緑色の 2 段波形として描画する。
final int WAVE_LEN = 512;
float[]   waveBuf  = new float[WAVE_LEN];
int       waveIdx  = 0;

// ─── キック =====
SinOsc     kickOsc;
WhiteNoise kickNoise;
boolean    kickHit       = false;
float      kickStart     = -1;
float      kickStartFreq = 240.0;
float      kickEndFreq   = 55.0;
float      kickEnvLen    = 0.5;

// ─── ハイハット =====
WhiteNoise hihatNoise;
BandPass   hihatBP;
boolean    hihatHit   = false;
float      hihatStart = -1;

// ─── setup() ──────────────────────────────────────────────────
void setup() {
  size(512, 280);
  textSize(14);

  // キック
  kickOsc = new SinOsc(this);
  kickOsc.play();
  kickOsc.amp(0);

  kickNoise = new WhiteNoise(this);
  kickNoise.play();
  kickNoise.amp(0);

  // ハイハット
  hihatNoise = new WhiteNoise(this);
  hihatNoise.play();
  hihatNoise.amp(0);

  hihatBP = new BandPass(this);
  hihatBP.process(hihatNoise, 7000, 4000);

  // シリアルポートを開く
  try {
    myPort = new Serial(this, SERIAL_PORT, BAUD_RATE);
  } catch (Exception e) {
  }
}

// ─── draw()：波形表示 ────────────────────────────────────────
void draw() {
  background(20);

  // ─── キック処理 ─────────────────────────────────────────────
  float kickAmp      = 0;
  float kickClickAmp = 0;
  if (kickHit) {
    float t = millis() / 1000.0 - kickStart;
    float x = constrain(t / kickEnvLen, 0, 1);

    float pitchEnv = exp(-18.0 * x);
    float freq = kickEndFreq + (kickStartFreq - kickEndFreq) * pitchEnv;
    kickOsc.freq(freq);

    kickAmp = 0.9 * exp(-4.0 * x);
    kickOsc.amp(kickAmp);

    kickClickAmp = (t < 0.003) ? 1.0 * (1.0 - t / 0.003) : 0;
    kickNoise.amp(kickClickAmp);

    if (kickAmp < 0.001) {
      kickOsc.amp(0);
      kickNoise.amp(0);
      kickHit = false;
    }
  }

  // ─── ハイハット処理 ──────────────────────────────────────────
  float hihatAmp = 0;
  if (hihatHit) {
    float t = (millis() - hihatStart) / 1000.0;

    float attack = min(1.0, t * 200.0);
    float decay  = exp(-20 * t);
    hihatAmp = attack * decay;
    hihatNoise.amp(hihatAmp * 5);

    float freq = lerp(8000, 5000, t * 2.0);
    hihatBP.freq(freq);

    if (hihatAmp < 0.001) {
      hihatNoise.amp(0);
      hihatHit = false;
    }
  }

  // ─── 疑似波形サンプルを循環バッファに 1 サンプル書き込む ───────
  float amp = kickAmp + kickClickAmp + hihatAmp;
  waveBuf[waveIdx] = amp * (random(2) - 1);
  waveIdx = (waveIdx + 1) % WAVE_LEN;

  // 左右チャンネル波形（同じデータを 2 段描画）
  stroke(0, 200, 100);
  noFill();
  for (int i = 0; i < WAVE_LEN - 1; i++) {
    int a = (waveIdx + i)     % WAVE_LEN;
    int b = (waveIdx + i + 1) % WAVE_LEN;
    line(i,     80  - waveBuf[a] * 60,
         i + 1, 80  - waveBuf[b] * 60);
    line(i,     170 - waveBuf[a] * 60,
         i + 1, 170 - waveBuf[b] * 60);
  }

  fill(255);
  noStroke();
  if (lastPitch > 0) {
    text("最終音符: MIDI=" + lastPitch + "  " + drumName(lastPitch)
       + "  dur=" + lastDurMs + "ms", 10, 220);
  }
}

// ─── serialEvent()：Processingのシリアルコールバック ─────────
void serialEvent(Serial port) {
  while (port.available() > 0) {
    int b = port.read() & 0xFF;
    parseSerialByte(b);
  }
}

// ─── バイナリパケット解析ステートマシン ──────────────────────
void parseSerialByte(int b) {
  switch (rxState) {

    case 0:  // マーカー(0xAA)待ち
      if (b == SERIAL_MARKER) {
        rxState = 1;
      }
      break;

    case 1:  // 楽器種別バイト
      rxInstId = b;
      rxCount  = 0;
      rxState  = 2;
      break;

    case 2:  // ペイロード3バイト受信中 (pitch=ドラム種別, vel, dur8ms)
      rxBuf[rxCount++] = b;
      if (rxCount >= 3) {
        if (rxInstId == INST_DRUM) {
          processDrumEvent(rxBuf[0], rxBuf[1], rxBuf[2]);
        }
        rxState = 0;
      }
      break;

    default:
      rxState = 0;
  }
}

// ─── ドラムイベント処理 ──────────────────────────────────────
// drumType: ドラム種別 (36=KICK, 42=HIHAT) — MIDIノート番号を流用
// vel:      velocity (未使用、将来の音量制御用)
// dur8ms:   演奏時間 ÷ 8 (×8してmsに戻す、表示のみ)
void processDrumEvent(int drumType, int vel, int dur8ms) {
  if (vel == 0) return;

  int durationMs = dur8ms * 8;

  lastPitch = drumType;
  lastDurMs = durationMs;

  if (drumType == DRUM_KICK) {
    kickStart = millis() / 1000.0;
    kickHit   = true;
  } else if (drumType == DRUM_HIHAT) {
    hihatStart = millis();
    hihatHit   = true;
  }
}

// ─── マウスクリックでも鳴らせる（テスト用）─────────────────
void mousePressed() {
  if (mouseX < width / 2) {
    kickStart = millis() / 1000.0;
    kickHit   = true;
    lastPitch = DRUM_KICK;
    lastDurMs = 0;
  } else {
    hihatStart = millis();
    hihatHit   = true;
    lastPitch = DRUM_HIHAT;
    lastDurMs = 0;
  }
}

// ─── ドラム種別（MIDIノート番号）→ 名前文字列（表示用）──────
String drumName(int n) {
  if (n == DRUM_KICK)  return "KICK";
  if (n == DRUM_HIHAT) return "HI-HAT";
  return "?";
}

// ─── stop() ───────────────────────────────────────────────────
void stop() {
  if (myPort != null) myPort.stop();
  super.stop();
}
