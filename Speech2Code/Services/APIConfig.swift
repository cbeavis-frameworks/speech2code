import Foundation

struct APIConfig {
    static let shared = APIConfig()
    
    // API Keys
    let openAIKey: String
    let elevenLabsKey: String
    
    private init() {
        // Load from environment or secure storage in a real app
        // This implementation loads from a .env file for development
        openAIKey = APIConfig.getEnvValue(for: "OPENAI_API_KEY") ?? ""
        elevenLabsKey = APIConfig.getEnvValue(for: "ELEVENLABS_API_KEY") ?? ""
        
        // Validate keys
        if openAIKey.isEmpty {
            print("⚠️ Warning: OpenAI API key is missing. Speech recognition will not work.")
        }
        
        if elevenLabsKey.isEmpty {
            print("⚠️ Warning: ElevenLabs API key is missing. Text-to-speech will not work.")
        }
    }
    
    // Helper to get environment variables
    private static func getEnvValue(for key: String) -> String? {
        // First check environment variables
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        
        // Then check .env file in the app bundle
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil),
           let contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            
            // Parse the file line by line
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                // Skip comments and empty lines
                if line.hasPrefix("#") || line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Parse key-value pairs
                let components = line.components(separatedBy: "=")
                if components.count >= 2,
                   let envKey = components.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                   envKey == key {
                    
                    // Join the rest in case there are = in the value
                    let value = components.dropFirst().joined(separator: "=")
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
}
