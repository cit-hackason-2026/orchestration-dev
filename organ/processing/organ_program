import ddf.minim.*;
import ddf.minim.ugens.*;

Minim minim;
AudioOutput out;
Waveform currentWaveform;

String[] melody = {
  "C2"
};

float[] duration = {
  20f
};

float[] startTime = {
  0.0f
};

class HackInstrument implements Instrument
{
  Summer mix;
  ADSR adsr;

  HackInstrument(float frequency, float maxAmp, Waveform wf)
  {
    mix = new Summer();

    float f1 = frequency * pow(2, -6.0f / 1200.0f);
    float f2 = frequency * pow(2, -2.0f / 1200.0f);
    float f3 = frequency * pow(2, 2.0f / 1200.0f);
    float f4 = frequency * pow(2, 6.0f / 1200.0f);
    //デチューン(pow関数内)は後に調整予定

    Oscil osc1 = new Oscil(f1, maxAmp/4.0f, wf);
    Oscil osc2 = new Oscil(f2, maxAmp/4.0f, wf);
    Oscil osc3 = new Oscil(f3, maxAmp/4.0f, wf);
    Oscil osc4 = new Oscil(f4, maxAmp/4.0f, wf);

    osc1.patch(mix);
    osc2.patch(mix);
    osc3.patch(mix);
    osc4.patch(mix);

    adsr = new ADSR(maxAmp, 0.08f, 0.0f, 1.0f, 0.3f);

    mix.patch(adsr);
  }

  void noteOn(float duration)
  {
    adsr.patch(out);
    adsr.noteOn();
  }

  void noteOff()
  {
    adsr.noteOff();
  }
}

void setup()
{
  size(512, 200);
  minim = new Minim(this);
  out = minim.getLineOut();
  out.setTempo(120);
  currentWaveform = Waves.SINE;
}

void playSong()
{
  out.pauseNotes();
  for (int i = 0; i < melody.length; i++)
  {
    out.playNote(
      startTime[i],
      duration[i],
      new HackInstrument(
      Frequency.ofPitch(melody[i]).asHz(),
      0.5f,
      currentWaveform
      )
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
    line(i, 50 - out.left.get(i) * 50,
      i + 1, 50 - out.left.get(i + 1) * 50);

    line(i, 150 - out.right.get(i) * 50,
      i + 1, 150 - out.right.get(i + 1) * 50);
  }
}

void keyPressed()
{
  switch(key)
  {
  case '1':
    currentWaveform = WavetableGenerator.gen10(
      8192,
      new float[] {0.5f, 0.8f, 0.5f, 0.8f, 0.5f, 0.65f, 0.5f, 0.9f}
      );
    break;
  case 'p':
    playSong();
    break;
  }
}