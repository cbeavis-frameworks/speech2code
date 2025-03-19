import Foundation

struct Message: Identifiable, Hashable {
    var id = UUID()
    var content: String
    var isFromUser: Bool
    var timestamp: Date = Date()
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(isFromUser)
        hasher.combine(timestamp)
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.isFromUser == rhs.isFromUser &&
               lhs.timestamp == rhs.timestamp
    }
}

class ConversationModel: ObservableObject {
    @Published var messages: [Message] = []
    
    // Add a new message and return it for reference
    @discardableResult
    func addMessage(_ content: String, isFromUser: Bool) -> Message {
        let message = Message(content: content, isFromUser: isFromUser)
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(message)
        }
        
        return message
    }
    
    func updateLastMessage(with content: String) {
        // Update on main thread to ensure UI updates correctly
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.messages.isEmpty else { return }
            
            // Get the last message
            let lastIndex = self.messages.count - 1
            let lastMessage = self.messages[lastIndex]
            
            // Create an updated version of the last message while preserving the ID
            let updatedMessage = Message(
                id: lastMessage.id, // Preserve the original ID to maintain the same bubble
                content: content, 
                isFromUser: lastMessage.isFromUser, 
                timestamp: lastMessage.timestamp
            )
            
            // Create a whole new array to trigger publisher
            var updatedMessages = self.messages
            updatedMessages[lastIndex] = updatedMessage
            
            // Force UI update
            self.objectWillChange.send()
            self.messages = updatedMessages
            
            // Debug log to verify update is happening
            print("🔄 Message updated with \(content.count) characters: \"\(content.suffix(min(20, content.count)))...\"")
        }
    }
    
    // Update a specific message by ID (used for progressive updates)
    func updateMessageWithId(_ messageId: UUID, content: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the message with the specified ID
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                // Create an updated version of the message while preserving the ID and other properties
                let originalMessage = self.messages[index]
                let updatedMessage = Message(
                    id: originalMessage.id,
                    content: content,
                    isFromUser: originalMessage.isFromUser,
                    timestamp: originalMessage.timestamp
                )
                
                // Update the message in the array
                var updatedMessages = self.messages
                updatedMessages[index] = updatedMessage
                
                // Force UI update
                self.messages = updatedMessages
                print("📝 Updated message with ID: \(messageId)")
            } else {
                print("⚠️ Could not find message with ID: \(messageId)")
            }
        }
    }
    
    // Delete a message by ID
    func deleteMessageWithId(_ messageId: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the message with the specified ID
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                // Remove the message from the array
                var updatedMessages = self.messages
                updatedMessages.remove(at: index)
                
                // Force UI update
                self.messages = updatedMessages
                print("🗑️ Deleted message with ID: \(messageId)")
            } else {
                print("⚠️ Could not find message with ID: \(messageId) to delete")
            }
        }
    }
    
    // Clear all messages from the conversation
    func clearMessages() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.messages = []
        }
    }
    
    func clearConversation() {
        DispatchQueue.main.async { [weak self] in
            self?.messages = []
        }
    }
}
