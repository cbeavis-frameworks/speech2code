import Foundation
import Combine
import SwiftUI

class ConversationViewModel: ObservableObject {
    // MARK: - Dependencies
    private let conversationModel: ConversationModel
    private let speechService: SpeechRecognitionService
    private let openAIService: OpenAIChatService
    private let streamingTTSService: ElevenLabsStreamingService
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State
    @Published var messages: [Message] = []
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var currentTranscription: String = "" // Track current partial transcription
    
    // Response accumulation
    private var accumulatedAIResponse = ""
    private var isFirstChunk = true
    private var progressiveUserMessageId: UUID? = nil // Track the ID of progressive user message
    private var aiResponseMessageId: UUID? = nil // Track the ID of the current AI response message
    
    // TTS mode: true = stream chunks, false = wait for complete message
    private var useStreamingTTS = false
    
    // Auto-restart listening after AI response
    private var autoRestart = true
    
    // Auto-restart listening after processing
    private var autoRestartListening = true
    
    // Init
    init() {
        self.conversationModel = ConversationModel()
        self.speechService = SpeechRecognitionService()
        self.openAIService = OpenAIChatService()
        self.streamingTTSService = ElevenLabsStreamingService(apiKey: APIConfig.shared.elevenLabsKey)
        
        setupBindings()
        setupHandlers()
        setupOpenAIService()
        
        // Auto-start listening when app launches
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startListening()
        }
    }
    
    // MARK: - Setup
    
    private func setupOpenAIService() {
        // Set up chat service callbacks
        openAIService.onResponseReceived = { [weak self] text in
            guard let self = self else { return }
            self.handleAIResponse(text: text)
            
            // If streaming TTS is enabled, send each chunk to TTS
            if self.useStreamingTTS {
                self.streamTextToTTS(text)
            }
        }
        
        openAIService.onResponseCompleted = { [weak self] finalText in
            guard let self = self else { return }
            // Pass the final text to the completion handler for a final check
            self.completeAIResponse()
            
            // Reset for next message
            DispatchQueue.main.async {
                self.isFirstChunk = true
            }
        }
        
        // Set up handler for complete messages - ONLY FOR TEXT-TO-SPEECH
        // No message creation or updating should happen here
        openAIService.fullMessageHandler = { [weak self] completeMessage in
            guard let self = self else { return }
            
            // If not using streaming TTS, send the complete message to TTS
            if !self.useStreamingTTS {
                self.speakCompleteMessage(completeMessage)
            }
        }
        
        // Set up streaming TTS callbacks
        streamingTTSService.onSpeakingStateChange = { [weak self] isSpeaking in
            guard let self = self else { return }
            DispatchQueue.main.async {
                print("🔊 TTS speaking state: \(isSpeaking ? "Speaking" : "Silent")")
                self.isSpeaking = isSpeaking
                
                // If speech finished and we're not processing, restart listening
                if !isSpeaking && !self.isProcessing && self.autoRestartListening {
                    print("🎤 Auto-restarting listening after speech completed")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.startListening()
                    }
                }
            }
        }
    }
    
    private func setupHandlers() {
        // Set up OpenAI response handlers
        openAIService.chunkHandler = { [weak self] chunk in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Set processing state
                self.isProcessing = true
                
                // Handle the chunk
                self.handleAIResponseChunk(chunk)
            }
        }
        
        openAIService.fullMessageHandler = { [weak self] message in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Message is complete, process it if needed
                print("📝 Full AI message received: \(message.prefix(30))...")
                
                // Use the complete message for TTS if not in streaming mode
                if !self.useStreamingTTS {
                    self.speakCompleteMessage(message)
                }
            }
        }
        
        openAIService.completionHandler = { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Processing complete
                self.isProcessing = false
                
                // Complete the response for TTS
                self.completeAIResponse()
            }
        }
        
        // Set up speech recognition handlers
        
        // Handle partial transcriptions
        speechService.onPartialTranscription = { [weak self] text in
            guard let self = self else { return }
            
            // Skip processing if we're already handling an AI response
            guard !self.isProcessing else { return }
            
            DispatchQueue.main.async {
                print("🗣️ Partial: \"\(text)\"")
                
                // Update the current transcription
                self.currentTranscription = text
                
                // Progressive message approach: update or create message
                if let messageId = self.progressiveUserMessageId {
                    // Update existing progressive message
                    self.conversationModel.updateMessageWithId(messageId, content: text)
                } else {
                    // First partial, create new message and track its ID
                    let message = self.conversationModel.addMessage(text, isFromUser: true)
                    self.progressiveUserMessageId = message.id
                }
            }
        }
        
        // Handle final transcriptions
        speechService.onTranscriptionComplete = { [weak self] text in
            guard let self = self else { return }
            
            // Skip processing if we're already handling an AI response
            guard !self.isProcessing else { 
                print("⚠️ Already processing a response, ignoring final transcription")
                return 
            }
            
            // Stop listening temporarily while we process this
            self.isListening = false
            
            DispatchQueue.main.async {
                print("🗣️ Final: \"\(text)\"")
                
                // Clear the current transcription
                self.currentTranscription = ""
                
                // Only process non-empty text
                if !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    // Check if identical message already exists in recent messages
                    let recentDuplicateExists = self.messages.suffix(3).contains { message in 
                        message.isFromUser && message.content == text
                    }
                    
                    if recentDuplicateExists {
                        print("⚠️ Duplicate final transcription detected, not adding: \"\(text)\"")
                        
                        // If we have a progressive message that turned out to be a duplicate, delete it
                        if let messageId = self.progressiveUserMessageId {
                            self.conversationModel.deleteMessageWithId(messageId)
                        }
                        
                        // Reset state
                        self.progressiveUserMessageId = nil
                        
                        // Still send to OpenAI (user meant to send it)
                        self.sendMessage(text)
                    } else {
                        // Finalize the message
                        if let messageId = self.progressiveUserMessageId {
                            // Update existing message with final text
                            self.conversationModel.updateMessageWithId(messageId, content: text)
                            
                            // Reset the progressive message ID before sending to avoid duplication
                            self.progressiveUserMessageId = nil
                            
                            // Send to OpenAI
                            self.sendMessage(text)
                        } else {
                            // No progressive ID, create new message through sendMessage
                            self.sendMessage(text)
                        }
                    }
                } else {
                    // Empty transcription, restart listening
                    self.startListening()
                }
            }
        }
        
        // Bind to audio level updates
        speechService.$currentAudioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Handle recognition errors
        speechService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("🐞 Speech recognition error: \(error.localizedDescription)")
                    
                    // On error, restart listening
                    self?.startListening()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
        // Bind to the conversation model messages
        conversationModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                guard let self = self else { return }
                // Force update of the published property
                self.objectWillChange.send()
                self.messages = messages
                
                // Debug print to verify message count
                print("📱 UI Messages updated: \(messages.count) messages in conversation")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startListening() {
        // Don't restart if we're already listening or processing a response
        guard !isListening && !isProcessing && !isSpeaking else {
            print("⚠️ Can't start listening: already active")
            return
        }
        
        print("🎤 Starting speech recognition")
        speechService.startRecording()
        
        // Update UI state
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    func stopListening() {
        // Don't stop if we're already processing a response
        guard !isProcessing else {
            print("⚠️ Can't stop listening: currently processing")
            return
        }
        
        print("🛑 Stopping speech recognition")
        forceStopListening()
    }
    
    func forceStopListening() {
        // This method stops listening regardless of state
        print("🛑 Force stopping speech recognition")
        speechService.forceStopRecognition()
        
        // Update UI state
        DispatchQueue.main.async {
            self.isListening = false
            
            // Clear progressive message if it exists but empty
            if let _ = self.progressiveUserMessageId, 
               self.currentTranscription.trimmingCharacters(in: .whitespaces).isEmpty {
                // There's no direct removeMessage method, so we'll handle this differently
                // Instead of removing, we'll just reset the progressive ID
                self.progressiveUserMessageId = nil
            }
            
            // Clear current transcription
            self.currentTranscription = ""
        }
    }
    
    // MARK: - Private Methods
    
    func handleAIResponse(text: String) {
        DispatchQueue.main.async {
            // For the first chunk, add a new message
            if self.isFirstChunk {
                print("💬 Adding initial AI message to conversation")
                
                // If there's an existing AI message, delete it to prevent duplication
                if let existingId = self.aiResponseMessageId {
                    self.conversationModel.deleteMessageWithId(existingId)
                }
                
                // Create a new message for the AI response
                let message = self.conversationModel.addMessage(text, isFromUser: false)
                self.aiResponseMessageId = message.id
                
                // We've processed the first chunk
                self.isFirstChunk = false
                self.accumulatedAIResponse = text
            } else {
                // For subsequent chunks, update the existing message
                if let messageId = self.aiResponseMessageId {
                    // Add the new text to our accumulated response
                    self.accumulatedAIResponse += text
                    
                    // Update the message with the full accumulated response
                    self.conversationModel.updateMessageWithId(messageId, content: self.accumulatedAIResponse)
                }
            }
        }
    }
    
    func handleAIResponseChunk(_ chunk: String) {
        // Make sure we force stop listening during AI response
        forceStopListening()
        
        // For the first chunk, create a new message
        if isFirstChunk {
            print("💬 Adding initial AI message to conversation")
            // Reset the accumulated response for the new message
            accumulatedAIResponse = ""
            
            // Create a new, empty AI message
            let newMessage = conversationModel.addMessage("", isFromUser: false)
            aiResponseMessageId = newMessage.id
            isFirstChunk = false
            
            // Set processing flag to true
            self.isProcessing = true
        }
        
        // Add this chunk to our accumulated response
        if !chunk.isEmpty {
            // Add the new chunk to our accumulated response
            accumulatedAIResponse += chunk
            
            // Update the message with the full accumulated text
            if let messageId = aiResponseMessageId {
                // Replace the content with the complete accumulated response so far
                conversationModel.updateMessageWithId(messageId, content: accumulatedAIResponse)
                
                // If we're using streaming TTS mode, speak this chunk
                if useStreamingTTS {
                    streamTextToTTS(chunk)
                }
            }
        }
    }
    
    func completeAIResponse() {
        // Make sure we're on the main thread
        DispatchQueue.main.async {
            print("✅ AI response completed: \"\(self.accumulatedAIResponse)\"")
            
            // Make sure the message is properly finalized in the model
            if let messageId = self.aiResponseMessageId {
                self.conversationModel.updateMessageWithId(messageId, content: self.accumulatedAIResponse)
            }
        }
    }
    
    private func streamTextToTTS(_ text: String) {
        // Only speak non-empty text
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        // For empty/first chunks, use regular TTS
        if self.accumulatedAIResponse == text {
            print("🔊 Sending first chunk to TTS: \"\(text)\"")
        }
        
        // Always use streaming for all chunks for better performance
        self.speakWithStreaming(text)
    }
    
    private func speakCompleteMessage(_ text: String) {
        // Always force stop listening before TTS
        self.forceStopListening()
        
        // Use the complete message TTS feature
        print("🔊 Sending complete message to TTS: \"\(text)\"")
        streamingTTSService.speakCompleteMessage(text) { success in
            if !success {
                print("⚠️ Failed to speak complete message")
                // Handle the error by showing it to the user
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to convert text to speech. Please try again."
                }
            }
        }
    }
    
    private func speakWithStreaming(_ text: String) {
        // Always force stop listening before TTS
        self.forceStopListening()
        
        // Use the streaming TTS service
        print("🔊 Sending chunk to streaming TTS: \"\(text)\"")
        streamingTTSService.streamText(text) { success in
            if !success {
                print("⚠️ Failed to stream text chunk")
                // Handle the error by showing it to the user
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to stream text to speech. Please try again."
                }
            }
        }
    }
    
    func sendMessage(_ text: String) {
        // Make sure we explicitly mark this as from the user
        print("💬 Adding user message: \"\(text)\"")
        
        // If we're already processing a response, don't send another one
        guard !isProcessing else {
            print("⚠️ Already processing a response, ignoring this send request")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create a user message if there isn't a progressive one
            if self.progressiveUserMessageId == nil {
                let message = self.conversationModel.addMessage(text, isFromUser: true)
                print("💬 Created new user message with ID: \(message.id)")
                
                // Force UI update
                self.objectWillChange.send()
            }
            
            // Reset the progressive message ID
            self.progressiveUserMessageId = nil
            
            // Set the processing flag
            self.isProcessing = true
            
            // Clear the current transcription
            self.currentTranscription = ""
            
            // Force stop listening during AI processing
            self.forceStopListening()
            
            // Send to OpenAI
            self.openAIService.sendMessage(text) { [weak self] response in
                guard self != nil else { return }
                // Handle response if needed
                print("📝 Received complete response from OpenAI: \(response.prefix(30))...")
            }
            
            // Reset for the next AI response
            self.isFirstChunk = true
            self.accumulatedAIResponse = ""
            self.aiResponseMessageId = nil
        }
    }
    
    // Toggle between streaming and complete message TTS modes
    func toggleTTSMode() {
        useStreamingTTS = !useStreamingTTS
        print("🔊 TTS Mode: \(useStreamingTTS ? "Streaming chunks" : "Complete message")")
    }
    
    // Clear all messages from the conversation
    func clearConversation() {
        print("🧹 Clearing conversation")
        conversationModel.clearMessages()
        self.accumulatedAIResponse = ""
        self.isFirstChunk = true
    }
}
