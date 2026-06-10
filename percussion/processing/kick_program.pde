import processing.sound.*;

SinOsc kickOsc;       // 基音（ボディ）
SinOsc kickOsc2;      // 第2倍音（胴鳴り）
WhiteNoise kickNoise; // ビーターのクリック源
BandPass kickBp;      // クリック整形フィルタ

float kickStartFreq = 140.0;  // ピッチ降下の開始（頭のパンチ）
float kickEndFreq   = 52.0;   // 降下後の基音

float kickStartTime;
boolean kickPlaying = false;  // 発音中フラグ

void setup() {
  size(400, 200);

  kickOsc = new SinOsc(this);
  kickOsc.play();

  kickOsc2 = new SinOsc(this);
  kickOsc2.play();

  kickNoise = new WhiteNoise(this);
  kickNoise.play();

  // クリックを中域に整形（hihat と同じ process(入力, 中心周波数, 帯域幅) の順）
  // 中心1800Hz は「コツッ」狙いの初期値。耳で詰める前提。
  kickBp = new BandPass(this);
  kickBp.process(kickNoise, 1800, 1500);

  // 最初は無音
  kickOsc.amp(0);
  kickOsc2.amp(0);
  kickNoise.amp(0);

  trigger();
}

void draw() {
  background(0);

  if (kickPlaying) {

    // 生の経過時間（秒）。各エンベロープに秒単位の時定数を持たせる。
    float t = millis()/1000.0 - kickStartTime;

    // アタックランプ：最初の2msで0→1（発音開始のプチノイズ防止）
    float attack = min(1.0, t / 0.002);

    // =========================
    // ピッチ降下（約30msで降下しきる＝アコースティックのパンチ）
    // =========================
    float pitchEnv = exp(-t / 0.03);
    float freq = kickEndFreq + (kickStartFreq - kickEndFreq) * pitchEnv;
    kickOsc.freq(freq);
    kickOsc2.freq(freq * 2.0);   // 第2倍音は常に基音の2倍

    // =========================
    // 音量エンベロープ
    // =========================
    // ボディ（基音）：808より短い余韻。合算クリップを避けるため上限0.7。
    float bodyAmp = 0.7 * attack * exp(-t / 0.12);
    kickOsc.amp(bodyAmp);

    // 倍音：基音より速く減衰させ胴鳴り感を出す
    float harmAmp = 0.2 * attack * exp(-t / 0.05);
    kickOsc2.amp(harmAmp);

    // =========================
    // ビーターのクリック
    // =========================
    // 30msかけて減衰させてから0にする（途中で切ると段差ノイズが出るため、
    // exp が十分小さくなる時刻まで伸ばす）。上限0.6でヘッドルーム確保。
    float clickAmp = 0;
    if (t < 0.03) {
      clickAmp = 0.6 * exp(-t / 0.004);
    }
    kickNoise.amp(clickAmp);

    // =========================
    // 終了処理（hihat にならう）
    // ボディが十分小さくなったら全 amp を0にして発音停止。
    // t の下限ガードは、アタックランプで bodyAmp が0に近い発音直後の
    // 1フレームを誤って停止扱いしないため。
    // =========================
    if (t > 0.05 && bodyAmp < 0.001) {
      kickOsc.amp(0);
      kickOsc2.amp(0);
      kickNoise.amp(0);
      kickPlaying = false;
    }

    fill(255);
    text("freq = " + nf(freq, 1, 1), 20, 20);
  }
}

void mousePressed() {
  trigger();
}

void trigger() {
  kickStartTime = millis()/1000.0;
  kickPlaying = true;
}