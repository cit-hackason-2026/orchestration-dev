// clarinet_serial.pde
// ArduinoからバイナリSerialでNOTE_EVENTを受信し、
// Minimライブラリでクラリネット音を即時再生する
//
// 通信プロトコルは flute5_serial.pde に揃えている
// ─────────────────────────────────────────────────────────────

import ddf.minim.*;
import ddf.minim.ugens.*;
import processing.serial.*;

// ─── シリアルポート設定（環境に合わせて変更する）──────────────
// Mac: "/dev/cu.usbmodem****"
final String SERIAL_PORT = "/dev/cu.usbmodem1101";
final int BAUD_RATE = 115200;

// ─── バイナリプロトコル定数 ───────────────────────────────────
final int SERIAL_MARKER  = 0xAA;
final int INST_CLARINET  = 0x02; // フルート=0x01、クラリネット=0x02

// ─── 音色設計/clarinet2/clarinet.pde と揃えたADSR定数 ──────────
final float ATTACK  = 0.400f; // アタック: 0.4秒かけて音量が上がる
final float SUSTAIN = 0.95f;  // サスティン: 持続中はピーク音量の95%を保つ
final float RELEASE = 0.200f; // リリース: 0.2秒かけて音量がゼロになる

// ─── Minim関連 ────────────────────────────────────────────────
Minim minim;
AudioOutput out;

// ─── Serial関連 ───────────────────────────────────────────────
Serial myPort;

// バイナリパケット受信ステートマシン
// 状態0: マーカー(0xAA)待ち
// 状態1: 楽器種別バイト待ち
// 状態2: ペイロード3バイト受信中 (pitch, velocity, duration_8ms)
int   rxState  = 0;
int   rxInstId = 0;
int   rxCount  = 0;
int[] rxBuf    = new int[3]; // pitch, velocity, duration_8ms

// ─── デバッグ表示用 ──────────────────────────────────────────
int lastPitch = 0;
int lastDurMs = 0;

// ─── setup() ──────────────────────────────────────────────────
void setup() {
  size(512, 280);
  textSize(14);

  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(120);

  // シリアルポートを開く
  try {
    myPort = new Serial(this, SERIAL_PORT, BAUD_RATE);
  } catch (Exception e) {
  }
}

// ─── draw()：波形表示 ────────────────────────────────────────
void draw() {
  background(20);

  // 左右チャンネル波形
  stroke(0, 200, 100);
  noFill();
  for (int i = 0; i < out.bufferSize() - 1; i++) {
    line(i,     80 - out.left.get(i)     * 60,
         i + 1, 80 - out.left.get(i + 1) * 60);
    line(i,     170 - out.right.get(i)     * 60,
         i + 1, 170 - out.right.get(i + 1) * 60);
  }

  fill(255);
  noStroke();
  if (lastPitch > 0) {
    text("最終音符: MIDI=" + lastPitch + "  " + midiName(lastPitch)
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

    case 2:  // ペイロード3バイト受信中 (pitch, vel, dur8ms)
      rxBuf[rxCount++] = b;
      if (rxCount >= 3) {
        processNoteEvent(rxInstId, rxBuf[0], rxBuf[1], rxBuf[2]);
        rxState = 0;
      }
      break;

    default:
      rxState = 0;
  }
}

// ─── NOTE_EVENTパケット処理 ───────────────────────────────────
// instId: 楽器種別 (2=クラリネット)
// pitch:  MIDIノート番号
// vel:    velocity
// dur8ms: 演奏時間 ÷ 8 (×8してmsに戻す)
void processNoteEvent(int instId, int pitch, int vel, int dur8ms) {
  // pitch=0 または vel=0 は休符として無視
  if (pitch == 0 || vel == 0) return;

  int   durationMs  = dur8ms * 8;
  float durationSec = durationMs / 1000.0;
  float freqHz      = midiToHz(pitch);
  float amp         = map(constrain(vel, 1, 127), 1, 127, 0.08, 0.52); // ClarinetSerialSynthと同じ音量レンジ

  // デバッグ記録
  lastPitch = pitch;
  lastDurMs = durationMs;

  // Minimで即時再生 (startTime=0 → 即時)
  out.pauseNotes();
  if (instId == INST_CLARINET) {
    out.playNote(0.0, durationSec,
      new ClarinetInstrument(freqHz, amp));
  }
  out.resumeNotes();
}

// ─── クラリネット音声合成クラス（音色設計/clarinet2/clarinet.pdeから移植）──
class ClarinetInstrument implements Instrument {
  ADSR mainEnv;   // メイン波形の音量エンベロープ
  ADSR reedEnv;   // リードノイズの音量エンベロープ
  ADSR breathEnv; // ブレスノイズの音量エンベロープ
  float freq;     // この音の基本周波数。noteOn後も参照するためフィールドに保存

  ClarinetInstrument(float freq, float amp) { // 引数:周波数, 振幅
    this.freq = freq;

    // ── 波形・発振器 ──
    float[] harmonicAmp = {
      1.000f, 0.013f, 1.216f, 0.023f,    // h1(基音), h2, h3, h4
      0.447f, 0.011f, 0.132f, 0.039f,    // h5, h6, h7, h8
    };
    Waveform wf  = WavetableGenerator.gen10(8192, harmonicAmp);
    Oscil    osc = new Oscil(freq, amp, wf);

    // ── ビブラート（周波数合成）──
    float  wobbleDepth = freq * (pow(2, 5.0f / 1200.0f) - 1.0f); // 5セントをHz幅に変換
    Oscil  wobble      = new Oscil(5.0f, wobbleDepth, Waves.SINE);
    Summer freqSum     = new Summer();
    new Constant(freq).patch(freqSum); // ベース周波数
    wobble.patch(freqSum);             // ビブラート
    freqSum.patch(osc.frequency);

    // ── トーン系 ──
    float      cutoff = min(3000.0f, freq * 8.0f); // 音程連動: C4≈2090Hz，上限3000Hz（実測ベース）
    MoogFilter lpf    = new MoogFilter(cutoff, 0.0f, MoogFilter.Type.LP);
    mainEnv           = new ADSR(amp, ATTACK, 0.040f, SUSTAIN, RELEASE);

    // ── リードノイズ系（1200〜2800Hz）はじめの息の音──
    Noise      noise = new Noise(0.1f, Noise.Tint.WHITE);
    MoogFilter hpf   = new MoogFilter(1200.0f, 0.0f, MoogFilter.Type.HP);
    MoogFilter nlpf  = new MoogFilter(2800.0f, 0.0f, MoogFilter.Type.LP);
    reedEnv          = new ADSR(amp * 0.4f, 0.15f, 0.6f, 0.3f, 0.150f);

    // ── ブレスノイズ系（100Hz以下・1段LPF）低周波域の雑音調整──
    Noise      breathNoise = new Noise(0.02f, Noise.Tint.PINK);
    MoogFilter blpf        = new MoogFilter(100.0f, 0.25f, MoogFilter.Type.LP);
    breathEnv              = new ADSR(0.007f, ATTACK, 0.040f, SUSTAIN * 1.0f, RELEASE);

    // ── 配線 ──
    osc.patch(lpf);                    lpf.patch(mainEnv);
    noise.patch(hpf);   hpf.patch(nlpf);   nlpf.patch(reedEnv);
    breathNoise.patch(blpf);           blpf.patch(breathEnv);
  }

  void noteOn(float duration) {                          // 発音開始時にMinimが呼ぶ
    mainEnv.patch(out);
    reedEnv.patch(out);
    breathEnv.patch(out);

    mainEnv.unpatchAfterRelease(out);   // リリース後に自動切断する設定（フルートと同じ構造）
    reedEnv.unpatchAfterRelease(out);
    breathEnv.unpatchAfterRelease(out);

    mainEnv.noteOn();
    reedEnv.noteOn();
    breathEnv.noteOn();
  }

  void noteOff() {                                       // 発音終了時にMinimが呼ぶ
    mainEnv.noteOff();
    reedEnv.noteOff();
    breathEnv.noteOff();
  }
}

// ─── MIDIノート番号 → 周波数(Hz) 変換 ──────────────────────
float midiToHz(int midiNote) {
  // A4=440Hz = MIDIノート69
  return 440.0 * pow(2.0, (midiNote - 69) / 12.0);
}

// ─── MIDIノート番号 → 音名文字列（デバッグ表示用）───────────
String midiName(int n) {
  String[] names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
  return names[n % 12] + (n / 12 - 1);
}

// ─── stop() ───────────────────────────────────────────────────
void stop() {
  if (myPort != null) myPort.stop();
  minim.stop();
  super.stop();
}
