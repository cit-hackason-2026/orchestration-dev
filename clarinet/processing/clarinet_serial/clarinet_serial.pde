// clarinet_serial.pde
// ArduinoからバイナリSerialでNOTE_EVENTを受信し、
// Minimライブラリでクラリネット音を即時再生する
//
// 通信プロトコルは flute5_serial.pde に揃えている
// 起動するとコンソールに利用可能なシリアルポート一覧が表示される。
// 番号を確認して SERIAL_PORT 定数を変更し再起動すること。
// ─────────────────────────────────────────────────────────────

import ddf.minim.*;
import ddf.minim.ugens.*;
import processing.serial.*;

// ─── シリアルポート設定（環境に合わせて変更する）──────────────
// Mac: "/dev/cu.usbmodem****"
// 起動時にコンソールに番号が出るので確認して書き換える
final String SERIAL_PORT = "/dev/cu.usbmodem1101";
final int BAUD_RATE = 115200;

// ─── バイナリプロトコル定数 ───────────────────────────────────
final int SERIAL_MARKER  = 0xAA;
final int INST_CLARINET  = 0x02; // フルート=0x01、クラリネット=0x02

// ─── ClarinetSerialSynth から引き継いだ音色設計用ADSR定数 ──────
final float ATTACK  = 0.400f; // アタック上限: 最大0.4秒かけて音量が上がる
final float SUSTAIN = 0.95f;  // サスティン: 持続中はピーク音量の95%を保つ
final float RELEASE = 0.300f; // リリース上限: 最大0.3秒かけて音量がゼロになる

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
int    noteCount = 0;
int    lastPitch = 0;
int    lastDurMs = 0;
String statusMsg = "Waiting for Arduino...";

// ─── setup() ──────────────────────────────────────────────────
void setup() {
  size(512, 280);
  textSize(14);

  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(120);

  // 利用可能なシリアルポートをコンソールに表示
  println("=== 利用可能なシリアルポート ===");
  String[] ports = Serial.list();
  for (int i = 0; i < ports.length; i++) {
    println("[" + i + "] " + ports[i]);
  }
  println("================================");
  println("SERIAL_PORT 定数を上記から選んで書き換えてください");

  // シリアルポートを開く
  try {
    myPort   = new Serial(this, SERIAL_PORT, BAUD_RATE);
    statusMsg = "接続済み: " + SERIAL_PORT;
  } catch (Exception e) {
    statusMsg = "Serial エラー: " + e.getMessage();
    println("シリアル接続失敗: " + e.getMessage());
  }
}

// ─── draw()：波形表示 + ステータス ────────────────────────────
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
  text(statusMsg, 10, 210);
  text("受信音符数: " + noteCount, 10, 230);

  if (lastPitch > 0) {
    text("最終音符: MIDI=" + lastPitch + "  " + midiName(lastPitch)
       + "  dur=" + lastDurMs + "ms", 10, 250);
  }
}

// ─── serialEvent()：Processingのシリアルコールバック ─────────
void serialEvent(Serial port) {
  while (port.available() > 0) {
    int b = port.read() & 0xFF;
    println("rx: " + hex(b));  // ← 追加: バイトが届いているか確認
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
  lastPitch  = pitch;
  lastDurMs  = durationMs;
  noteCount++;
  statusMsg = "Playing MIDI " + pitch + " (" + midiName(pitch) + ")  " + durationMs + "ms";

  // Minimで即時再生 (startTime=0 → 即時)
  out.pauseNotes();
  if (instId == INST_CLARINET) {
    println("playNote called");  // ← 追加s
    out.playNote(0.0, durationSec,
      new ClarinetInstrument(freqHz, amp, durationSec));
  }
  out.resumeNotes();
}

// ─── クラリネット音声合成クラス（ClarinetSerialSynth.pdeから移植）──
class ClarinetInstrument implements Instrument {
  ADSR mainEnv;   // メイン波形の音量包絡
  ADSR reedEnv;   // リードノイズの音量包絡
  ADSR breathEnv; // ブレスノイズの音量包絡
  ADSR formEnv1;  // フォルマント1（500Hz付近）の音量包絡
  ADSR formEnv2;  // フォルマント2（1200Hz付近）の音量包絡
  Line pitchDrop; // アタック直後のピッチ変動を時間で制御するUGen
  float freq;     // noteOn後も参照するためフィールドに保存

  ClarinetInstrument(float freq, float amp, float durationSec) {
    this.freq = freq;

    // 短い音でも立ち上がり切るように、音長に応じてADSRを圧縮する
    float scaledAttack  = min(ATTACK, max(0.020f, durationSec * 0.35f));  // 最短20ms・音長の35%以下
    float scaledRelease = min(RELEASE, max(0.030f, durationSec * 0.30f)); // 最短30ms・音長の30%以下
    float scaledDecay   = min(0.040f, max(0.010f, durationSec * 0.15f));  // 最短10ms・最長40ms
    float reedDecay     = min(0.150f, max(0.020f, durationSec * 0.35f));  // リードノイズは少し長めに残す
    float breathSustain = max(0.15f, SUSTAIN * 0.8f);                     // 息成分のサスティンはメインより少し小さくする

    // 奇数倍音を中心に強めたクラリネット倍音設計
    float[] harmonicAmp = {
      1.000f, 0.013f, 1.216f, 0.023f, // 1f(基音), 2f, 3f(3倍音が基音より強い), 4f
      0.447f, 0.011f, 0.132f, 0.039f, // 5f, 6f, 7f, 8f
      0.070f, 0.007f, 0.045f, 0.005f, // 9f, 10f, 11f, 12f
      0.028f, 0.004f, 0.018f, 0.003f  // 13f, 14f, 15f, 16f
    };
    Waveform wf = WavetableGenerator.gen10(8192, harmonicAmp); // 倍音配列から8192点のウェーブテーブルを生成する
    Oscil osc = new Oscil(freq, amp, wf);                      // 生成した波形で基本発振器を作る

    // ビブラート: 4.5Hz / 15セント (控えめな深さ)
    float wobbleDepth = freq * (pow(2, 15.0f / 1200.0f) - 1.0f); // 15セントをHz幅に変換する
    Oscil wobble = new Oscil(4.5f, wobbleDepth, Waves.SINE);

    // アタック時のピッチ変動(pitchDrop)とビブラートをSummerでベース周波数に合成する
    pitchDrop = new Line();
    Summer freqSum = new Summer();
    new Constant(freq).patch(freqSum); // ベース周波数（固定値）をSummerに入力する
    pitchDrop.patch(freqSum);          // ピッチ変動オフセット（アタック後にゼロになる）をSummerに入力する
    wobble.patch(freqSum);             // ビブラートをSummerに入力する
    freqSum.patch(osc.frequency);      // 合成した周波数値を発振器の周波数入力に接続する

    // 音域による音色変化: C4付近は暗め、A4付近は明るめ
    float cutoff    = constrain(map(freq, 261.0f, 880.0f, freq * 6.0f, freq * 16.0f), 600.0f, 11000.0f);
    float resonance = map(freq, 261.0f, 880.0f, 0.0f, 0.15f);
    MoogFilter lpf  = new MoogFilter(cutoff, resonance, MoogFilter.Type.LP);
    osc.patch(lpf);
    mainEnv = new ADSR(amp, scaledAttack, scaledDecay, SUSTAIN, scaledRelease);
    lpf.patch(mainEnv);

    // フォルマント1 (500Hz付近: 管体の低域共鳴・シャルモー感)
    Oscil fOsc1 = new Oscil(freq, amp * 0.06f, wf);
    MoogFilter bp1 = new MoogFilter(500.0f, 0.6f, MoogFilter.Type.BP);
    fOsc1.patch(bp1);
    formEnv1 = new ADSR(amp * 0.06f, scaledAttack, scaledDecay, SUSTAIN * 0.7f, scaledRelease);
    bp1.patch(formEnv1);

    // フォルマント2 (1200Hz付近: 木管らしい明るさ)
    Oscil fOsc2 = new Oscil(freq, amp * 0.04f, wf);
    MoogFilter bp2 = new MoogFilter(1200.0f, 0.5f, MoogFilter.Type.BP);
    fOsc2.patch(bp2);
    formEnv2 = new ADSR(amp * 0.04f, scaledAttack, scaledDecay, SUSTAIN * 0.5f, scaledRelease);
    bp2.patch(formEnv2);

    // リードノイズ: 1200〜2800Hzに絞ったホワイトノイズでリードの擦れ感を足す
    Noise noise = new Noise(0.0003f, Noise.Tint.WHITE);
    MoogFilter hpf = new MoogFilter(1200.0f, 0.0f, MoogFilter.Type.HP);
    MoogFilter nlpf = new MoogFilter(2800.0f, 0.0f, MoogFilter.Type.LP);
    noise.patch(hpf);
    hpf.patch(nlpf);
    reedEnv = new ADSR(0.0003f, min(0.010f, scaledAttack * 0.5f), reedDecay, 0.05f, min(0.080f, scaledRelease));
    nlpf.patch(reedEnv);

    // ブレスノイズ: 80Hz以下のピンクノイズで息のふくらみを足す
    Noise breathNoise = new Noise(0.002f, Noise.Tint.PINK);
    MoogFilter blpf = new MoogFilter(80.0f, 0.0f, MoogFilter.Type.LP);
    breathNoise.patch(blpf);
    breathEnv = new ADSR(0.002f, scaledAttack, scaledDecay, breathSustain, scaledRelease);
    blpf.patch(breathEnv);
  }

  void noteOn(float duration) {
    // アタック前半でピッチが2.5%上からずり落ちる(リードが鳴り始めの不安定感)
    pitchDrop.activate(min(0.06f, duration * 0.15f), freq * 0.025f, 0.0f);

    mainEnv.patch(out);
    reedEnv.patch(out);
    breathEnv.patch(out);
    formEnv1.patch(out);
    formEnv2.patch(out);

    mainEnv.unpatchAfterRelease(out);
    reedEnv.unpatchAfterRelease(out);
    breathEnv.unpatchAfterRelease(out);
    formEnv1.unpatchAfterRelease(out);
    formEnv2.unpatchAfterRelease(out);

    mainEnv.noteOn();
    reedEnv.noteOn();
    breathEnv.noteOn();
    formEnv1.noteOn();
    formEnv2.noteOn();
  }

  void noteOff() {
    mainEnv.noteOff();
    reedEnv.noteOff();
    breathEnv.noteOff();
    formEnv1.noteOff();
    formEnv2.noteOff();
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
