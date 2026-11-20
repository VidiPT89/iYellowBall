import AVFoundation

enum ToneShape {
    case square, sawtooth
}

/// Tiny real-time synth: short square/sawtooth notes with an exponential
/// decay envelope. All sound effects are generated, no audio files.
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
        didSet { UserDefaults.standard.set(isOn, forKey: "iyellowball.sound") }
    }

    private init() {
        isOn = UserDefaults.standard.object(forKey: "iyellowball.sound") == nil ? true : UserDefaults.standard.bool(forKey: "iyellowball.sound")

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

    func playGem(alt: Bool) { playTone(freq: alt ? 1320 : 1175, duration: 0.035, gain: 0.08) }
    func playFreeze() {
        playSequence([(1568, 0, 0.08, .square, 0.12), (1319, 50, 0.08, .square, 0.12), (1047, 100, 0.08, .square, 0.12), (784, 150, 0.2, .square, 0.12)])
    }
    func playSmash() { playSequence([(180, 0, 0.08, .sawtooth, 0.2), (1400, 30, 0.05, .square, 0.12), (1800, 70, 0.07, .square, 0.12)]) }
    func playPop() {
        playSequence([(880, 0, 0.08, .square, 0.16), (440, 70, 0.1, .sawtooth, 0.18), (220, 160, 0.16, .sawtooth, 0.18), (110, 300, 0.3, .sawtooth, 0.18)])
    }
    func playLevelClear() {
        playSequence([(587, 0, 0.12, .square, 0.16), (740, 90, 0.12, .square, 0.16), (880, 180, 0.12, .square, 0.16), (1175, 300, 0.12, .square, 0.16), (880, 400, 0.1, .square, 0.12), (1175, 480, 0.3, .square, 0.16)])
    }
    func playExtraLife() {
        playSequence([(784, 0, 0.1, .square, 0.16), (988, 80, 0.1, .square, 0.16), (1319, 160, 0.2, .square, 0.16)])
    }
}
