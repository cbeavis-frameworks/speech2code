import Foundation
import Combine

class OpenAIChatService {
    // MARK: - Properties
    
    // API configuration
    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    private let apiKey: String
    private let model = "gpt-4o"
    
    // Message history
    private var messages = [[String: String]]()
    private var cancellables = Set<AnyCancellable>()
    
    // Response data
    private var accumulatedResponse = ""
    private var completeResponse = ""
    private var isStreamingResponse = false
    
    // Debug 
    var debugMessages: [String] = []
    
    // Callbacks
    var onResponseReceived: ((String) -> Void)?
    var onResponseCompleted: ((String) -> Void)?
    var completionHandler: (() -> Void)?
    var chunkHandler: ((String) -> Void)?
    var fullMessageHandler: ((String) -> Void)? // Handler for complete messages
    
    init() {
        // Retrieve API key from secure configuration
        self.apiKey = APIConfig.shared.openAIKey
        
        // Set system message
        self.messages = [
            [
                "role": "system",
                "content": "You are a simple AI conversation agent, please engage in a conversation with the user. Your responses should be short and conversational, I will be converting your responses to speech."
            ]
        ]
    }
    
    // Send a user message and get streaming response
    func sendMessage(_ message: String, completion: @escaping (String) -> Void) {
        // Update messages
        let userMessage = ["role": "user", "content": message]
        messages.append(userMessage)
        
        // Reset response state
        accumulatedResponse = ""
        completeResponse = ""
        isStreamingResponse = true
        
        // Create request URL
        guard let url = URL(string: openAIEndpoint) else {
            debugMessages.append("Invalid URL")
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true
        ]
        
        // Serialize request body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            debugMessages.append("Error creating request body: \(error.localizedDescription)")
            return
        }
        
        // Send request
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    self.debugMessages.append("HTTP Error: \(httpResponse.statusCode), \(errorMessage)")
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .sink(
                receiveCompletion: { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .finished:
                        self.debugMessages.append("Request completed successfully")
                        
                        // Add assistant response to messages
                        let assistantMessage = ["role": "assistant", "content": self.completeResponse]
                        self.messages.append(assistantMessage)
                        
                        // Call completion handler
                        self.isStreamingResponse = false
                        completion(self.completeResponse)
                        self.onResponseCompleted?(self.completeResponse)
                        self.completionHandler?()
                        self.fullMessageHandler?(self.completeResponse)
                        
                    case .failure(let error):
                        self.debugMessages.append("Request failed: \(error.localizedDescription)")
                        self.isStreamingResponse = false
                    }
                },
                receiveValue: { [weak self] data in
                    guard let self = self else { return }
                    
                    // Process the streaming response
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    self.processStreamingResponse(responseString)
                }
            )
            .store(in: &cancellables)
    }
    
    // Process streaming response from OpenAI
    private func processStreamingResponse(_ response: String) {
        // Split the response into lines
        let lines = response.components(separatedBy: "\n")
        
        // Process each line
        for line in lines {
            // Skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Remove the "data: " prefix
            var content = line
            if line.hasPrefix("data: ") {
                content = String(line.dropFirst(6))
            }
            
            // Check if this is the end of the stream
            if content == "[DONE]" {
                // Stream is complete
                debugMessages.append("Stream complete")
                continue
            }
            
            // Try to parse the JSON
            do {
                if let data = content.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let delta = choice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    // Accumulate the response
                    accumulatedResponse += content
                    completeResponse += content
                    
                    // Call the handler with the chunk
                    chunkHandler?(content)
                    onResponseReceived?(accumulatedResponse)
                    
                    // Reset accumulated response if it gets too long
                    if accumulatedResponse.count > 100 {
                        accumulatedResponse = ""
                    }
                }
            } catch {
                debugMessages.append("Error parsing JSON: \(error.localizedDescription)")
            }
        }
    }
}
