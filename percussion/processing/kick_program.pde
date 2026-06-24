import processing.sound.*;

final int NUM_VOICES = 20;

// =====================
// 音源（20セット）
// =====================
SinOsc[] kickOsc = new SinOsc[NUM_VOICES];
SinOsc[] kickOsc2 = new SinOsc[NUM_VOICES];

WhiteNoise[] kickNoise = new WhiteNoise[NUM_VOICES];
BandPass[] kickBp = new BandPass[NUM_VOICES];

// =====================
// 各セットの状態
// =====================
float[] kickStartTime = new float[NUM_VOICES];
boolean[] kickPlaying = new boolean[NUM_VOICES];

// 次に使用するセット番号
int currentVoice = 0;

// =====================
// キックのパラメータ
// =====================
float kickStartFreq = 140.0;
float kickEndFreq   = 52.0;

// ==================================================
// 初期化
// ==================================================
void setup() {
  size(400, 200);

  for (int i = 0; i < NUM_VOICES; i++) {

    // 基音
    kickOsc[i] = new SinOsc(this);
    kickOsc[i].play();

    // 第2倍音
    kickOsc2[i] = new SinOsc(this);
    kickOsc2[i].play();

    // ホワイトノイズ
    kickNoise[i] = new WhiteNoise(this);
    kickNoise[i].play();

    // ノイズ整形用フィルタ
    kickBp[i] = new BandPass(this);
    kickBp[i].process(kickNoise[i], 1600, 1200);

    // 初期状態は無音
    kickOsc[i].amp(0);
    kickOsc2[i].amp(0);
    kickNoise[i].amp(0);

    kickPlaying[i] = false;
  }

  trigger();
}

// ==================================================
// 毎フレーム実行
// ==================================================
void draw() {
  background(0);

  for (int i = 0; i < NUM_VOICES; i++) {

    if (!kickPlaying[i]) continue;

    float t = millis()/1000.0 - kickStartTime[i];

    // ------------------
    // Attack
    // ------------------
    float attack = min(1.0, t / 0.08);

    // ------------------
    // Pitch Envelope
    // ------------------
    float pitchEnv = exp(-t / 0.03);

    float freq =
      kickEndFreq +
      (kickStartFreq - kickEndFreq) * pitchEnv;

    kickOsc[i].freq(freq);
    kickOsc2[i].freq(freq * 2.0);

    // ------------------
    // Amplitude Envelope
    // ------------------
    float bodyAmp =
      0.9 * attack * exp(-t / 0.12);

    float harmAmp =
      0.3 * attack * exp(-t / 0.05);

    kickOsc[i].amp(bodyAmp);
    kickOsc2[i].amp(harmAmp);

    // ------------------
    // Click Noise
    // ------------------
    float clickAmp = 0;

    if (t < 0.03) {
      clickAmp =
        0.25 * attack * exp(-t / 0.004);
    }

    kickNoise[i].amp(clickAmp);

    // ------------------
    // 終了判定
    // ------------------
    if (t > 0.05 && bodyAmp < 0.001) {

      kickOsc[i].amp(0);
      kickOsc2[i].amp(0);
      kickNoise[i].amp(0);

      kickPlaying[i] = false;
    }
  }

  fill(255);
  text("Current Voice : " + currentVoice, 20, 20);
}

// ==================================================
// マウスクリック
// ==================================================
void mousePressed() {
  trigger();
}

// ==================================================
// 発音開始
// ==================================================
void trigger() {

  kickStartTime[currentVoice] =
    millis()/1000.0;

  kickPlaying[currentVoice] = true;

  // 次のセットへ
  currentVoice =
    (currentVoice + 1) % NUM_VOICES;
}