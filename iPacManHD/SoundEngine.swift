import AVFoundation

enum ToneShape {
    case square, sawtooth
}

/// Tiny real-time synth that reproduces the original Web Audio `playTone`
/// beeps: short square/sawtooth notes with an exponential decay envelope.
final class SoundEngine {
    static let shared = SoundEngine()

    private struct Voice {
        let freq: Double
        let shape: ToneShape
        let gain: Double
        let startSample: Int64
        let durationSamples: Int64
    }

    private let engine = AVAudioEngine()
    private let sampleRate = 44100.0
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var sampleClock: Int64 = 0
    private(set) var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: "pacmanhd.sound") }
    }

    private init() {
        isOn = UserDefaults.standard.object(forKey: "pacmanhd.sound") == nil ? true : UserDefaults.standard.bool(forKey: "pacmanhd.sound")

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = abl[0]
            let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)

            self.lock.lock()
            let localVoices = self.voices
            let startClock = self.sampleClock
            self.lock.unlock()

            for frame in 0..<Int(frameCount) {
                let now = startClock + Int64(frame)
                var sample: Float = 0
                for i in 0..<localVoices.count {
                    let v = localVoices[i]
                    guard now >= v.startSample, now < v.startSample + v.durationSamples else { continue }
                    let elapsed = Double(now - v.startSample)
                    let t = elapsed / self.sampleRate
                    let ph = (elapsed * v.freq / self.sampleRate).truncatingRemainder(dividingBy: 1)
                    let raw: Double
                    switch v.shape {
                    case .square: raw = ph < 0.5 ? 1.0 : -1.0
                    case .sawtooth: raw = 2.0 * ph - 1.0
                    }
                    let durationSec = Double(v.durationSamples) / self.sampleRate
                    let envelope = v.gain * exp(-4.5 * (t / max(durationSec, 0.001)))
                    sample += Float(raw * envelope)
                }
                ptr[frame] = max(-1, min(1, sample))
            }

            self.lock.lock()
            self.sampleClock += Int64(frameCount)
            self.voices.removeAll { $0.startSample + $0.durationSamples < self.sampleClock }
            self.lock.unlock()

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        try? engine.start()
    }

    func toggleSound() -> Bool {
        isOn.toggle()
        if !isOn { lock.lock(); voices.removeAll(); lock.unlock() }
        return isOn
    }

    func playTone(freq: Double, duration: Double, shape: ToneShape = .square, gain: Double = 0.18, delay: Double = 0) {
        guard isOn else { return }
        if !engine.isRunning { try? engine.start() }
        lock.lock()
        let start = sampleClock + Int64(delay * sampleRate)
        voices.append(Voice(freq: freq, shape: shape, gain: gain, startSample: start, durationSamples: Int64(duration * sampleRate)))
        lock.unlock()
    }

    func playSequence(_ notes: [(freq: Double, delayMs: Double, duration: Double, shape: ToneShape, gain: Double)]) {
        for n in notes {
            playTone(freq: n.freq, duration: n.duration, shape: n.shape, gain: n.gain, delay: n.delayMs / 1000)
        }
    }

    func playChomp(alt: Bool) { playTone(freq: alt ? 240 : 200, duration: 0.045, gain: 0.16) }
    func playPower() { playSequence([(330, 0, 0.09, .square, 0.18), (415, 60, 0.09, .square, 0.18), (523, 120, 0.14, .square, 0.18)]) }
    func playEatGhost() { playSequence([(600, 0, 0.06, .square, 0.18), (900, 50, 0.06, .square, 0.18), (1300, 100, 0.1, .square, 0.18)]) }
    func playDeath() {
        playSequence([(300, 0, 0.14, .sawtooth, 0.18), (230, 140, 0.16, .sawtooth, 0.18), (170, 300, 0.2, .sawtooth, 0.18), (110, 480, 0.4, .sawtooth, 0.18)])
    }
    func playLevelClear() {
        playSequence([(523, 0, 0.15, .square, 0.18), (659, 110, 0.15, .square, 0.18), (784, 220, 0.15, .square, 0.18), (1047, 360, 0.3, .square, 0.18)])
    }
    func playExtraLife() {
        playSequence([(660, 0, 0.1, .square, 0.18), (880, 90, 0.1, .square, 0.18), (1100, 180, 0.18, .square, 0.18)])
    }
}
