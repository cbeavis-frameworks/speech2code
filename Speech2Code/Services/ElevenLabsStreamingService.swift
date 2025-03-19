import Foundation
import AVFoundation
import Combine

class ElevenLabsStreamingService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // MARK: - Properties
    // API configuration
    private let apiBaseUrl = "https://api.elevenlabs.io/v1/text-to-speech"
    private let apiKey = "sk_12393152518c550f5428de44669eaaef1ec1de46487644ad"
    
    // Voice configuration 
    private var voiceId = "or03gN1gc1Z0lccMLxD2" // Default voice ID
    
    // Audio playback
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [Data] = []
    private var isAudioPlaying = false
    
    // State management
    @Published var isPlaying = false
    @Published var errorMessage: String?
    
    // Text buffering
    private var textBuffer = ""           // Buffer to accumulate small text chunks
    private var textQueue = ""            // Queue for text after current playback
    private var accumulatedText = ""      // Track all text for debugging
    private var bufferTimer: Timer?       // Timer to flush buffer after a delay
    private let bufferTimeInterval = 1.0  // Time to wait before sending buffer (seconds)
    private var completeMessageBuffer = ""// Buffer for collecting the complete message
    private var isBufferingCompleteMessage = false // Flag to indicate we're waiting for complete message
    
    // Callbacks
    var onSpeakingStateChange: ((Bool) -> Void)?
    private var streamingCompletion: ((Bool) -> Void)?
    
    // MARK: - Public Methods
    
    /// Process the complete message from OpenAI
    func speakCompleteMessage(_ message: String, completion: @escaping (Bool) -> Void) {
        print("🔈 Speaking complete message: \"\(message)\"")
        
        // If already speaking, stop
        if isPlaying {
            stopStreaming()
        }
        
        // Start speaking
        isPlaying = true
        DispatchQueue.main.async {
            self.onSpeakingStateChange?(true)
        }
        
        // Save completion handler
        streamingCompletion = completion
        
        // Convert the full message to speech
        convertTextToSpeech(message) { success in
            if !success {
                // On failure, reset state
                self.isPlaying = false
                DispatchQueue.main.async {
                    self.onSpeakingStateChange?(false)
                    completion(false)
                }
            }
            // Otherwise, audio playback will handle completion
        }
    }
    
    /// Process streaming chunks of text from OpenAI
    func streamText(_ text: String, completion: @escaping (Bool) -> Void) {
        print("🔊 ElevenLabs Streaming: \"\(text)\"")
        
        // Track the text we're sending for debugging
        accumulatedText += text
        completeMessageBuffer += text
        
        // Add text to buffer
        textBuffer += text
        
        // If this is likely a partial sentence (small chunk), buffer it
        if text.count < 10 && !text.contains(".") && !text.contains("!") && !text.contains("?") {
            // Reset the buffer timer
            bufferTimer?.invalidate()
            
            // Start a new timer to flush buffer after delay
            bufferTimer = Timer.scheduledTimer(withTimeInterval: bufferTimeInterval, repeats: false) { [weak self] _ in
                self?.flushTextBuffer(completion: completion)
            }
            return
        }
        
        // Check if this chunk contains an ending punctuation mark
        let containsEndPunctuation = text.contains(".") || text.contains("!") || text.contains("?")
        
        // If we get here, either the text is substantial or contains sentence endings
        // Flush the buffer immediately if it contains ending punctuation
        if containsEndPunctuation {
            flushTextBuffer(completion: completion)
        } else {
            // Otherwise, continue buffering with a timer
            bufferTimer?.invalidate()
            bufferTimer = Timer.scheduledTimer(withTimeInterval: bufferTimeInterval, repeats: false) { [weak self] _ in
                self?.flushTextBuffer(completion: completion)
            }
        }
    }
    
    private func flushTextBuffer(completion: @escaping (Bool) -> Void) {
        // Cancel any pending timer
        bufferTimer?.invalidate()
        bufferTimer = nil
        
        // If buffer is empty, nothing to do
        guard !textBuffer.isEmpty else {
            return
        }
        
        // Save completion handler (the last one wins if multiple chunks were buffered)
        streamingCompletion = completion
        
        print("📢 Flushing text buffer: \"\(textBuffer)\"")
        
        // If already speaking, queue this text for later
        if isPlaying {
            textQueue += textBuffer
            textBuffer = ""
            return
        }
        
        // Get text from buffer and clear it
        let textToSpeak = textBuffer
        textBuffer = ""
        
        // Start speaking
        isPlaying = true
        DispatchQueue.main.async {
            self.onSpeakingStateChange?(true)
        }
        
        // Convert text to speech using REST API
        convertTextToSpeech(textToSpeak) { success in
            if !success {
                // If failed, try again with any queued text
                if !self.textQueue.isEmpty {
                    let queuedText = self.textQueue
                    self.textQueue = ""
                    
                    self.convertTextToSpeech(queuedText) { _ in
                        // Even if this fails, we're done with the streaming attempt
                        if let completion = self.streamingCompletion {
                            DispatchQueue.main.async {
                                self.streamingCompletion = nil
                                completion(false)
                            }
                        }
                    }
                } else if let completion = self.streamingCompletion {
                    DispatchQueue.main.async {
                        self.streamingCompletion = nil
                        completion(false)
                    }
                }
            }
            // If successful, audio will play and completion will be called when done
        }
    }
    
    func stopStreaming() {
        print("🔊 Stopping ElevenLabs streaming")
        
        // Clear audio queue and stop playback
        bufferTimer?.invalidate()
        bufferTimer = nil
        textBuffer = ""
        audioQueue.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        isAudioPlaying = false
        isPlaying = false
        
        // Notify about speech state change
        DispatchQueue.main.async {
            self.onSpeakingStateChange?(false)
        }
        
        // Reset stored text
        textQueue = ""
        accumulatedText = ""
        completeMessageBuffer = ""
    }
    
    // MARK: - Private Methods
    
    private func convertTextToSpeech(_ text: String, completion: @escaping (Bool) -> Void) {
        // Make sure we have text to speak
        guard !text.isEmpty else {
            print("⚠️ Empty text, not speaking")
            isPlaying = false
            DispatchQueue.main.async {
                self.onSpeakingStateChange?(false)
            }
            completion(false)
            return
        }
        
        // Create URL for API request
        let url = URL(string: "\(apiBaseUrl)/\(voiceId)/stream")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // Create JSON payload
        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.9,
                "similarity_boost": 0.95,
                "style": 0.1,
                "use_speaker_boost": true,
                "speed": 0.9
            ]
        ]
        
        do {
            // Convert payload to JSON data
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // Start API request
            print("🎙️ Sending TTS request to ElevenLabs for text: \"\(text)\"")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                // Check for errors
                if let error = error {
                    print("❌ TTS request failed: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "TTS request failed: \(error.localizedDescription)"
                        self.isPlaying = false
                        self.onSpeakingStateChange?(false)
                        completion(false)
                    }
                    return
                }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse, 
                   !(200...299).contains(httpResponse.statusCode) {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    
                    // Try to extract error message from response
                    var errorMsg = "HTTP Error: \(httpResponse.statusCode)"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? [String: Any],
                       let message = detail["message"] as? String {
                        errorMsg = message
                    }
                    
                    DispatchQueue.main.async {
                        self.errorMessage = errorMsg
                        self.isPlaying = false
                        self.onSpeakingStateChange?(false)
                        completion(false)
                    }
                    return
                }
                
                // Process the audio data
                guard let data = data, !data.isEmpty else {
                    print("❌ No audio data received")
                    DispatchQueue.main.async {
                        self.errorMessage = "No audio data received"
                        self.isPlaying = false
                        self.onSpeakingStateChange?(false)
                        completion(false)
                    }
                    return
                }
                
                // All good, play audio
                DispatchQueue.main.async {
                    do {
                        // Create audio player
                        print("🔈 Creating audio player with \(data.count) bytes of audio data")
                        self.audioPlayer = try AVAudioPlayer(data: data)
                        self.audioPlayer?.delegate = self
                        
                        // Successful setup
                        if self.audioPlayer?.prepareToPlay() == true && self.audioPlayer?.play() == true {
                            print("▶️ Audio playback started")
                            self.isAudioPlaying = true
                            completion(true)
                        } else {
                            print("❌ Failed to play audio")
                            self.errorMessage = "Failed to play audio"
                            self.isPlaying = false
                            self.onSpeakingStateChange?(false)
                            completion(false)
                        }
                    } catch {
                        // Error creating audio player
                        print("❌ Error creating audio player: \(error)")
                        self.errorMessage = "Error creating audio player: \(error.localizedDescription)"
                        self.isPlaying = false
                        self.onSpeakingStateChange?(false)
                        completion(false)
                    }
                }
            }.resume() // Start the data task
        } catch {
            // Error creating the request
            print("❌ Error creating TTS request: \(error)")
            self.errorMessage = "Error creating TTS request: \(error.localizedDescription)"
            isPlaying = false
            DispatchQueue.main.async {
                self.onSpeakingStateChange?(false)
            }
            completion(false)
        }
    }
    
    // Handle queued text after current speech finishes
    private func handleTextQueue() {
        // If we have queued text and we're not currently playing, speak it
        guard !textQueue.isEmpty, !isPlaying, !isAudioPlaying else { 
            return 
        }
        
        let queuedText = textQueue
        textQueue = ""
        
        // Start the new speech
        isPlaying = true
        convertTextToSpeech(queuedText) { [weak self] success in
            print("🔄 Queued text streaming completed with success = \(success)")
            if !success {
                // On failure, clear the speaking state
                self?.isPlaying = false
                DispatchQueue.main.async {
                    self?.onSpeakingStateChange?(false)
                }
            }
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 Audio playback finished")
        
        // Reset current player
        audioPlayer = nil
        isAudioPlaying = false
        
        // If there's more audio in the queue, play it
        if !audioQueue.isEmpty {
            playNextAudio()
        } else if !textQueue.isEmpty {
            // If we have more text queued, process it
            handleTextQueue()
        } else if !textBuffer.isEmpty {
            // If we have buffered text, process it
            flushTextBuffer { _ in }
        } else {
            // No more audio to play or text to process, we're done
            isPlaying = false
            
            // Update UI speaking state
            DispatchQueue.main.async {
                self.onSpeakingStateChange?(false)
                
                // Call completion handler if this was the last chunk
                if let completion = self.streamingCompletion {
                    print("✅ TTS Streaming completed")
                    self.streamingCompletion = nil
                    completion(true)
                }
            }
        }
    }
    
    private func playNextAudio() {
        // If no audio in queue or already playing, return
        guard !audioQueue.isEmpty, !isAudioPlaying else {
            return
        }
        
        // Get next audio data
        let audioData = audioQueue.removeFirst()
        
        // Try to play it
        do {
            // Create player and play
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            
            if audioPlayer?.prepareToPlay() == true && audioPlayer?.play() == true {
                print("▶️ Playing audio chunk: \(audioData.count) bytes")
                isAudioPlaying = true
                isPlaying = true
                
                // Notify about speech state (first audio packet)
                if audioQueue.isEmpty {
                    DispatchQueue.main.async {
                        self.onSpeakingStateChange?(true)
                    }
                }
            } else {
                print("❌ Failed to play audio")
                isAudioPlaying = false
                playNextAudio() // Try next in queue
            }
        } catch {
            print("❌ Error creating audio player: \(error)")
            isAudioPlaying = false
            playNextAudio() // Try next in queue
        }
    }
}
