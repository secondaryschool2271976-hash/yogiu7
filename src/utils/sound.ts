let audioCtx: AudioContext | null = null;

function getContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  if (!audioCtx) {
    const AudioContextClass =
      window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume().catch(() => {});
  }
  return audioCtx;
}

function playTone(
  freq: number,
  durationSec: number,
  type: OscillatorType,
  gainPeak: number,
  endFreq?: number,
  delaySec = 0
): void {
  const ctx = getContext();
  if (!ctx) return;

  const now = ctx.currentTime + delaySec;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  osc.type = type;
  osc.frequency.setValueAtTime(freq, now);
  if (endFreq !== undefined) {
    osc.frequency.exponentialRampToValueAtTime(Math.max(20, endFreq), now + durationSec);
  }

  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(gainPeak, now + 0.015);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + durationSec);

  osc.connect(gain);
  gain.connect(ctx.destination);

  osc.start(now);
  osc.stop(now + durationSec + 0.02);
}

export const soundFx = {
  draw(muted: boolean) {
    if (muted) return;
    playTone(420, 0.09, 'triangle', 0.06, 680);
  },
  summon(muted: boolean) {
    if (muted) return;
    playTone(260, 0.14, 'triangle', 0.08, 390);
    playTone(520, 0.18, 'sine', 0.07, 620, 0.07);
  },
  spell(muted: boolean) {
    if (muted) return;
    playTone(520, 0.14, 'sine', 0.07, 880);
    playTone(740, 0.16, 'triangle', 0.05, 1100, 0.06);
  },
  attack(muted: boolean) {
    if (muted) return;
    playTone(170, 0.16, 'sawtooth', 0.08, 55);
    playTone(95, 0.14, 'square', 0.05, 42, 0.04);
  },
  trap(muted: boolean) {
    if (muted) return;
    playTone(620, 0.1, 'square', 0.06, 310);
    playTone(460, 0.16, 'sawtooth', 0.05, 220, 0.08);
  },
  victory(muted: boolean) {
    if (muted) return;
    playTone(440, 0.16, 'triangle', 0.08, 440, 0);
    playTone(554.37, 0.16, 'triangle', 0.08, 554.37, 0.12);
    playTone(659.25, 0.28, 'triangle', 0.09, 659.25, 0.24);
  },
  defeat(muted: boolean) {
    if (muted) return;
    playTone(320, 0.2, 'sawtooth', 0.06, 260, 0);
    playTone(220, 0.3, 'sawtooth', 0.06, 150, 0.16);
  },
};
