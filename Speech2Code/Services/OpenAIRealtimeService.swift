import Foundation
import Combine
import SwiftUI

class OpenAIRealtimeService: ObservableObject {
    // MARK: - Properties
    
    // API Configuration
    private let baseWSUrl = "wss://api.openai.com/v1/audio/speech"
    private let apiKey: String
    
    // WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    private var isRecording = false
    
    // State management
    @Published var isConnected = false
    @Published var debugMessages: [String] = []
    
    // Handlers
    var transcriptionHandler: ((String) -> Void)?
    
    init() {
        // Configure URL session
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config)
        
        self.apiKey = APIConfig.shared.openAIKey
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard !isConnected, webSocketTask == nil else {
            debugMessages.append("Already connected or connecting")
            return
        }
        
        debugMessages.append("Connecting to OpenAI Realtime API...")
        print("🌐 Connecting to OpenAI Realtime API")
        
        // Construct the URL with query parameters
        var components = URLComponents(string: baseWSUrl)
        components?.queryItems = [
            URLQueryItem(name: "model", value: "whisper-1")
        ]
        
        guard let url = components?.url else {
            debugMessages.append("Error creating WebSocket URL")
            return
        }
        
        // Create the WebSocket request with headers
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("json", forHTTPHeaderField: "OpenAI-Content-Type")
        request.addValue("json_response", forHTTPHeaderField: "OpenAI-Response-Format")
        
        // Create and resume WebSocket task
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Send initial configuration
        sendConfiguration()
        
        // Update state
        isConnected = true
    }
    
    func disconnect() {
        guard isConnected, let webSocketTask = webSocketTask else {
            debugMessages.append("Not connected")
            return
        }
        
        // Send end message if needed
        if isRecording {
            sendEndMessage()
        }
        
        // Close WebSocket connection
        webSocketTask.cancel(with: .goingAway, reason: nil)
        self.webSocketTask = nil
        
        // Update state
        isConnected = false
        isRecording = false
        
        debugMessages.append("Disconnected from OpenAI Realtime API")
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleBinaryMessage(data)
                case .string(let string):
                    self.handleTextMessage(string)
                @unknown default:
                    self.debugMessages.append("Unknown message type received")
                }
                
                // Continue receiving messages if still connected
                if self.isConnected {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                self.debugMessages.append("Error receiving message: \(error.localizedDescription)")
                self.isConnected = false
            }
        }
    }
    
    private func handleTextMessage(_ message: String) {
        debugMessages.append("Received text message: \(message)")
        
        // Try to parse JSON response
        guard let data = message.data(using: .utf8) else {
            debugMessages.append("Could not convert message to data")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Extract transcription if available
                if let transcription = json["text"] as? String {
                    transcriptionHandler?(transcription)
                }
                
                // Log any error
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    debugMessages.append("API error: \(message)")
                }
            }
        } catch {
            debugMessages.append("Error parsing JSON: \(error.localizedDescription)")
        }
    }
    
    private func handleBinaryMessage(_ data: Data) {
        debugMessages.append("Received binary data: \(data.count) bytes")
        
        // Attempt to parse binary data as JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let transcription = json["text"] as? String {
                    transcriptionHandler?(transcription)
                }
            }
        } catch {
            debugMessages.append("Error parsing binary data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sending Messages
    
    private func sendConfiguration() {
        // Configuration message
        let config = [
            "type": "config",
            "model": "whisper-1",
            "language": "en",  // Specify language if known
            "response_format": "json"
        ] as [String : Any]
        
        sendJSONMessage(config)
    }
    
    func startRecording() {
        guard isConnected, !isRecording else {
            debugMessages.append("Not connected or already recording")
            return
        }
        
        isRecording = true
        
        // Send start message
        let startMessage = [
            "type": "start"
        ]
        
        sendJSONMessage(startMessage)
        debugMessages.append("Started recording")
    }
    
    func sendAudioData(_ audioData: Data) {
        guard isConnected, isRecording else {
            debugMessages.append("Not connected or not recording")
            return
        }
        
        // Send audio data as binary message
        webSocketTask?.send(.data(audioData)) { [weak self] error in
            if let error = error {
                self?.debugMessages.append("Error sending audio data: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording() {
        guard isConnected, isRecording else {
            debugMessages.append("Not connected or not recording")
            return
        }
        
        sendEndMessage()
        isRecording = false
        debugMessages.append("Stopped recording")
    }
    
    private func sendEndMessage() {
        let endMessage = [
            "type": "end"
        ]
        
        sendJSONMessage(endMessage)
    }
    
    private func sendJSONMessage(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let string = String(data: data, encoding: .utf8)!
            
            webSocketTask?.send(.string(string)) { [weak self] error in
                if let error = error {
                    self?.debugMessages.append("Error sending message: \(error.localizedDescription)")
                }
            }
        } catch {
            debugMessages.append("Error serializing JSON: \(error.localizedDescription)")
        }
    }
}
