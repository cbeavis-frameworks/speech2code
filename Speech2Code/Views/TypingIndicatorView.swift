import SwiftUI

struct TypingIndicatorView: View {
    @State private var animationState = 0
    
    var body: some View {
        // Always show the indicator on the AI (left) side of the conversation
        HStack(alignment: .top) {
            // AI indicator on the left side
            VStack(alignment: .leading) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(.purple)
                        .frame(width: 30, height: 30)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Circle())
                    
                    // Animated dots
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .opacity(self.animationState == i ? 1 : 0.3)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.purple.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .onAppear {
            // Start animation loop
            withAnimation(Animation.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                self.animationState = (self.animationState + 1) % 3
            }
        }
    }
}

#Preview {
    TypingIndicatorView()
}
