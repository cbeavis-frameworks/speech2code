import SwiftUI

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top) {
            // User messages on the right with blue background
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(message.content)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .animation(.easeInOut(duration: 0.2), value: message.content)
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30, height: 30)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Circle())
                    }
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } 
            // AI messages on the left with purple background
            else {
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "bubble.left.fill")
                            .foregroundColor(.purple)
                            .frame(width: 30, height: 30)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Circle())
                        Text(message.content)
                            .padding()
                            .background(Color.purple.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message.content)
                    }
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessageView(message: Message(content: "Hello, how can I help you?", isFromUser: false))
            MessageView(message: Message(content: "I need help with coding.", isFromUser: true))
        }
    }
}
