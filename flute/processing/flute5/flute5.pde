import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;
Waveform currentWaveform;

String[] melody = {
  "C4"
};

float[] duration = {
  5.0f
};

float[] startTime = {
  0.0f
};

class FluteInstrument implements Instrument
{
  ADSR toneEnv;
  ADSR breathEnv;
  ADSR breathEnv2;

  FluteInstrument(float frequency, float maxAmp, Waveform wf)
  {
    float cutoff = (float)Math.min(9000.0, frequency * 9.0);

    Oscil tone = new Oscil(frequency, 1.0f, wf);

    float vibrateSpeed = 4.3f;
    float vibratoSize = 15.0f;
    float vibratoNow = frequency * (pow(2, vibratoSize / 1200.0f) - 1.0f);

    Oscil vibrato = new Oscil(vibrateSpeed, vibratoNow, Waves.SINE);
    vibrato.offset.setLastValue(frequency);
    vibrato.patch(tone.frequency);

    MoogFilter toneLPF = new MoogFilter(cutoff, 0.0f, MoogFilter.Type.LP);

    Noise breath = new Noise(1.0f, Noise.Tint.WHITE);
    MoogFilter breathBand = new MoogFilter(2000.0f, 0.15f, MoogFilter.Type.BP);

    toneEnv = new ADSR(maxAmp, 0.08f, 0.14f, 0.82f, 0.16f);
    breathEnv = new ADSR(maxAmp * 0.14f, 0.015f, 0.12f, 0.04f, 0.10f);
    
    Noise breath2 = new Noise(1.0f, Noise.Tint.WHITE);
    MoogFilter breathBand2 = new MoogFilter(700.0f, 0.2f, MoogFilter.Type.BP);
    breathEnv2 = new ADSR(maxAmp * 0.11f, 0.015f, 0.12f, 0.07f, 0.10f);


    tone.patch(toneLPF);
    toneLPF.patch(toneEnv);

    breath.patch(breathBand);
    breathBand.patch(breathEnv);
    
    breath2.patch(breathBand2);
    breathBand2.patch(breathEnv2);
  }

  void noteOn(float duration)
  {
    toneEnv.patch(out);
    breathEnv.patch(out);
    breathEnv2.patch(out);

    toneEnv.unpatchAfterRelease(out);
    breathEnv.unpatchAfterRelease(out);
    breathEnv2.unpatchAfterRelease(out);

    toneEnv.noteOn();
    breathEnv.noteOn();
    breathEnv2.noteOn();
  }

  void noteOff()
  {
    toneEnv.noteOff();
    breathEnv.noteOff();
    breathEnv2.noteOff();
  }
}


void setup()
{
  size(512, 220);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);

  currentWaveform = makeFluteWaveform();
}

Wavetable makeFluteWaveform()
{
  Wavetable wf = WavetableGenerator.gen10(
    8192,
    new float[] {
      1.00f, 0.35f, 0.14f, 0.12f,
      0.08f, 0.04f, 0.025f, 0.02f, 0.015f, 0.010f
    }
  );

  wf.normalize();
  wf.scale(0.75f);
  return wf;
}

void playSong()
{
  out.pauseNotes();

  for (int i = 0; i < melody.length; i++)
  {
    out.playNote(
      startTime[i],
      duration[i],
      new FluteInstrument(
        Frequency.ofPitch( melody[i] ).asHz(), 0.20f, currentWaveform)
        );
  }

  out.resumeNotes();
}

void draw()
{
  background(0);
  stroke(255);

  for (int i = 0; i < out.bufferSize() - 1; i++)
  {
    line(i, 70 - out.left.get(i) * 60,
         i + 1, 70 - out.left.get(i + 1) * 60);

    line(i, 160 - out.right.get(i) * 60,
         i + 1, 160 - out.right.get(i + 1) * 60);
  }

  fill(255);

}

void keyPressed()
{
  switch(key)
  {
  case 'p':
    playSong();
    break;

  case '1':
    currentWaveform = makeFluteWaveform();
    break;

  }
}

void stop()
{
  minim.stop();
  super.stop();
}
