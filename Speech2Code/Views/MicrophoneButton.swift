import SwiftUI

struct MicrophoneButton: View {
    var isRecording: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 70, height: 70)
                    .shadow(radius: 5)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

#Preview {
    MicrophoneButton(isRecording: false, action: {})
}
