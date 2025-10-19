import Foundation
import Combine
import Speech
import AVFoundation
import os

@MainActor
final class SpeechRecognizer: ObservableObject {
    private let logger = Logger(subsystem: "com.caerusfund.busybee", category: "speech")
    @Published private(set) var transcript: String = ""
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "en_US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async {
        authorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func resetTranscript() {
        transcript = ""
    }

    func startTranscribing() throws {
        guard authorizationStatus == .authorized else { return }
        stopTranscribing()
        transcript = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate > 0 else {
            logger.error("Invalid audio input format - channels: \(recordingFormat.channelCount, privacy: .public), sampleRate: \(recordingFormat.sampleRate, privacy: .public)")
            stopTranscribing()
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        guard let speechRecognizer = speechRecognizer, let recognitionRequest else { return }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                stopTranscribing()
            }
        }
    }

    func stopTranscribing() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
