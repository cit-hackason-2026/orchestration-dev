import processing.sound.*;

SinOsc osc;
WhiteNoise noise;

// パーカッション設計に合わせたキックパラメータ
float startFreq = 150.0;   // 初期ピッチ（Hz）
float endFreq   = 50.0;    // 持続ピッチ（Hz）

float pitchDur  = 0.03;    // ピッチ下降に要する時間（秒） ≒ 30ms
float ampAttack = 0.001;   // 音量アタック（秒） ≒ 1ms
float ampDecay  = 0.300;   // 音量減衰（秒） ≒ 300ms
float clickDur  = 0.003;   // クリック（ノイズ）長さ（秒） ≒ 3ms

float peakLevel = 0.9;     // メインのピーク振幅（スケーリング）

float startTime;

void setup() {
  size(400, 200);

  osc = new SinOsc(this);
  osc.play();

  noise = new WhiteNoise(this);
  noise.play();

  trigger();
}

void draw() {
  float t = millis()/1000.0 - startTime;
  if (t < 0) t = 0;

  // --- ピッチエンベロープ（急速に下降） ---
  float pitchX = constrain(t / pitchDur, 0, 1);
  // exp を使って自然な下降に。coeff は 5 で 30ms 程度でほぼ終端になる。
  float pitchEnv = exp(-5.0 * pitchX);
  float freq = endFreq + (startFreq - endFreq) * pitchEnv;
  osc.freq(freq);

  // --- 音量エンベロープ（短いAttack + 長めDecay） ---
  float amp = 0;
  if (t < ampAttack) {
    // 線形で短いアタック（クリックノイズ防止）
    amp = peakLevel * (t / ampAttack);
  } else {
    // アタック後は指数的減衰（シンプルな実装）
    amp = peakLevel * exp(-(t - ampAttack) / ampDecay);
  }
  amp = constrain(amp, 0, 1);
  osc.amp(amp);

  // --- クリック（短いホワイトノイズ） ---
  float clickAmp = 0;
  if (t < clickDur) {
    // 先頭数msだけ短いノイズを加える（線形フェードアウト）
    float clickPeak = 0.6; // クリックの相対レベル
    clickAmp = clickPeak * (1.0 - (t / clickDur));
  }
  noise.amp(clickAmp);

  // --- 描画 ---
  background(0);
  fill(255);
  text("freq = " + nf(freq, 1, 1) + " Hz", 20, 20);
  text("amp = " + nf(amp, 1, 3), 20, 36);
  text("t = " + nf(t*1000.0, 1, 1) + " ms", 20, 52);
}

void mousePressed() {
  trigger();
}

void trigger() {
  // re-trigger: reset start time so envelopes restart
  startTime = millis()/1000.0;
}