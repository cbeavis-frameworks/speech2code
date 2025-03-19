import Foundation
import Speech
import Combine
import AVFoundation

class SpeechRecognitionService: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    // Published properties
    @Published var isRecording = false
    @Published var currentAudioLevel: Float = 0.0
    @Published var transcribedText = ""
    @Published var error: Error?
    
    // Recognition components
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Callback closures
    var onPartialTranscription: ((String) -> Void)?
    var onTranscriptionComplete: ((String) -> Void)?
    
    // Silence detection
    private var silenceTimer: Timer?
    private let silenceTimeThreshold: TimeInterval = 2.0 // Reduced from 2.0 to 1.0 seconds for faster response
    
    // Error recovery
    private var isRecovering = false
    
    // MARK: - Initialization
    
    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.speechRecognizer?.delegate = self
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("✅ Speech recognition authorized")
            case .denied, .restricted, .notDetermined:
                print("❌ Speech recognition not authorized: \(status.rawValue)")
                DispatchQueue.main.async {
                    self.error = NSError(domain: "SpeechRecognitionErrorDomain", code: 1, 
                                      userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
                }
            @unknown default:
                print("❌ Unknown speech recognition authorization status")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        // Exit if already recording or recovering
        guard !isRecording && !isRecovering else {
            print("⚠️ Already recording or recovering from error")
            return
        }
        
        print("🎤 Starting listening")
        
        // Clear any existing recognition task
        resetRecognitionTask()
        
        // Clear the transcribed text
        transcribedText = ""
        
        // Set up and start audio engine
        if !setupAudioEngine() {
            print("❌ Failed to set up audio engine")
            return
        }
        
        isRecording = true
        print("🎙️ Started recording")
    }
    
    func stopRecording() {
        // Only attempt to stop if actually recording
        guard isRecording else {
            print("⚠️ Not stopping recording because we're not currently recording")
            return
        }
        
        print("🛑 Stopped recording")
        
        // Update state first to prevent overlap
        isRecording = false
        
        // Stop recognition
        recognitionTask?.finish()
        recognitionTask = nil
        
        // Stop audio
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Reset silence detection
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    // Force completion of the current transcription
    func forceCompleteTranscription() {
        guard isRecording else {
            print("⚠️ Cannot complete transcription when not recording")
            return
        }
        
        // Stop timer
        cancelSilenceTimer()
        
        // If there's transcribed text, handle it
        if !transcribedText.isEmpty {
            let finalText = transcribedText
            print("✅ Force completing transcription: \"\(finalText)\"")
            
            // Stop recording and clean up
            stopRecording()
            
            // Trigger the completion callback with the current transcription
            onTranscriptionComplete?(finalText)
            
            // Clear the transcribed text for next recording
            transcribedText = ""
        } else {
            print("⚠️ No text to complete")
            stopRecording()
        }
    }
    
    // Force immediate and complete stoppage of speech recognition
    func forceStopRecognition() {
        print("🛑 FORCE STOPPING all speech recognition")
        
        // First, update our state flag to prevent any callbacks
        isRecording = false
        
        // Cancel any silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Cancel recognition task
        recognitionTask?.finish()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Stop audio engine and remove tap
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Reset transcription
        transcribedText = ""
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() -> Bool {
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest, speechRecognizer?.isAvailable == true else {
            print("❌ Speech recognizer not available")
            self.error = NSError(domain: "SpeechRecognitionErrorDomain", code: 2, 
                              userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
            return false
        }
        
        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true
        
        // Get input node from audio engine
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // Get the transcribed text
                let transcription = result.bestTranscription.formattedString
                
                // Update the transcribed text
                self.transcribedText = transcription
                
                // Reset the silence timer whenever we get new text
                self.resetSilenceTimer()
                
                // Call the partial transcription handler
                DispatchQueue.main.async {
                    self.onPartialTranscription?(transcription)
                }
            }
            
            if let error = error {
                self.handleError(error)
            }
        }
        
        // Install tap on audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visualization
            self?.calculateAudioLevel(buffer: buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            return true
        } catch {
            print("❌ Audio engine start failed: \(error.localizedDescription)")
            self.error = error
            return false
        }
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frames = buffer.frameLength
        var sum: Float = 0
        
        // Calculate RMS (root mean square) of the audio buffer
        for i in 0..<Int(frames) {
            sum += channelData[i] * channelData[i]
        }
        
        let rms = sqrt(sum / Float(frames))
        
        // Convert to decibels with some scaling for better visualization
        let db = 20 * log10(rms)
        let normalizedValue = max(0, min(1, (db + 50) / 50))
        
        DispatchQueue.main.async {
            self.currentAudioLevel = normalizedValue
        }
    }
    
    private func resetRecognitionTask() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    // MARK: - Silence Detection
    
    private func resetSilenceTimer() {
        // Cancel existing timer
        cancelSilenceTimer()
        
        // Create new timer
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeThreshold, repeats: false) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            
            print("⏱️ Silence detected for \(self.silenceTimeThreshold) seconds")
            self.handleSilenceDetected()
        }
    }
    
    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func handleSilenceDetected() {
        guard !transcribedText.isEmpty else {
            print("⚠️ Silence detected but no transcription available")
            return
        }
        
        print("✅ Completing transcription after silence: \"\(transcribedText)\"")
        
        // Get final text before stopping
        let finalText = transcribedText
        
        // Stop recording
        stopRecording()
        
        // Trigger completion callback
        onTranscriptionComplete?(finalText)
        
        // Clear the transcribed text for next recording
        transcribedText = ""
    }
    
    // MARK: - SFSpeechRecognizerDelegate Methods
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("✅ Speech recognition available")
        } else {
            print("❌ Speech recognition unavailable")
            error = NSError(domain: "SpeechRecognitionError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is unavailable"])
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        print("❌ Recognition error: \(error.localizedDescription)")
        self.error = error
        
        // Cancel any existing tasks
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Stop the audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Reset state
        isRecording = false
        
        // Schedule a retry after a delay
        isRecovering = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Clear error after delay to allow for UI updates
            self.error = nil
            self.isRecovering = false
            
            // No need to auto-restart here - the ViewModel will handle it when appropriate
        }
    }
}
