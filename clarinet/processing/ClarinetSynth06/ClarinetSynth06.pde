import ddf.minim.*;
import ddf.minim.ugens.*;

Minim       minim;
AudioOutput out;

String[] melody = { "C4" };

// ここで音の性格を切り替える
// true  = 本物に近い（素早い立ち上がり・ガレバン寄り）
// false = ぷぉ〜感あり（ゆっくり膨らむ）
final boolean REALISTIC = false;

final float ATTACK  = REALISTIC ? 0.070f : 0.400f;
final float DECAY   = REALISTIC ? 0.100f : 0.040f;
final float SUSTAIN = REALISTIC ? 0.88f  : 0.95f;
final float RELEASE = REALISTIC ? 0.200f : 0.300f;

class ClarinetInstrument implements Instrument {
  ADSR mainEnv;
  ADSR reedEnv;
  ADSR breathEnv; // 低域の空気感（20〜50Hz）

  ClarinetInstrument(float freq, float amp) {

    // ===== トーン =====
    float[] harmonicAmp = {
      1.000f, 0.013f, 1.216f, 0.023f,
      0.447f, 0.011f, 0.132f, 0.039f,
      0.070f, 0.007f, 0.045f, 0.005f,
      0.028f, 0.004f, 0.018f, 0.003f,
      0.012f, 0.002f, 0.008f, 0.001f,
      0.006f, 0.001f, 0.004f, 0.001f
    };
    Waveform wf  = WavetableGenerator.gen10(8192, harmonicAmp);
    Oscil    osc = new Oscil(freq, amp, wf);

    MoogFilter lpf = new MoogFilter(min(12000.0f, freq * 18.0f), 0.0f, MoogFilter.Type.LP);
    osc.patch(lpf);
    mainEnv = new ADSR(amp, ATTACK, DECAY, SUSTAIN, RELEASE);
    lpf.patch(mainEnv);

    // ===== リードノイズ（1200〜2800Hz）=====
    Noise      noise = new Noise(0.0003f, Noise.Tint.WHITE);
    MoogFilter hpf   = new MoogFilter(1200.0f, 0.0f, MoogFilter.Type.HP);
    MoogFilter nlpf  = new MoogFilter(2800.0f, 0.0f, MoogFilter.Type.LP);
    noise.patch(hpf);
    hpf.patch(nlpf);
    reedEnv = new ADSR(0.0003f, 0.010f, 0.150f, 0.05f, 0.080f);
    nlpf.patch(reedEnv);

    // ===== 低域の空気感（20〜50Hz）=====
    // 本物のスペクトルで -60dB 前後に見える広いこぶの再現
    Noise      breathNoise = new Noise(0.002f, Noise.Tint.PINK);
    MoogFilter blpf = new MoogFilter(80.0f, 0.0f, MoogFilter.Type.LP);
    breathNoise.patch(blpf);
    // mainEnvと同じ形で徐々に膨らむ
    breathEnv = new ADSR(0.002f, ATTACK, DECAY, SUSTAIN * 0.8f, RELEASE);
    blpf.patch(breathEnv);
  }

  void noteOn(float duration) {
    mainEnv.patch(out);   mainEnv.noteOn();
    reedEnv.patch(out);   reedEnv.noteOn();
    breathEnv.patch(out); breathEnv.noteOn();
  }

  void noteOff() {
    mainEnv.noteOff();   mainEnv.unpatchAfterRelease(out);
    reedEnv.noteOff();   reedEnv.unpatchAfterRelease(out);
    breathEnv.noteOff(); breathEnv.unpatchAfterRelease(out);
  }
}

void setup() {
  size(400, 120);
  textFont(createFont("Arial", 14));
  minim = new Minim(this);
  out   = minim.getLineOut();
  out.setTempo(100);
}

void draw() {
  background(24, 22, 32);
  fill(160, 130, 255);
  text("p キーで再生", 20, 44);
  fill(100, 90, 140);
  text("Attack: " + ATTACK + "s  |  " + (REALISTIC ? "本物寄り" : "ぷぉ〜"), 20, 70);
}

void playSong() {
  out.pauseNotes();
  for (int i = 0; i < melody.length; i++) {
    out.playNote(i * 1.0f, 2.0f,
      new ClarinetInstrument(Frequency.ofPitch(melody[i]).asHz(), 0.5f));
  }
  out.resumeNotes();
}

void keyPressed() {
  if (key == 'p') playSong();
}

void stop() {
  out.close();
  minim.stop();
  super.stop();
}
