import SwiftUI

struct AudioLevelMeter: View {
    var level: Float // 0.0 to 1.0
    
    var body: some View {
        VStack {
            ZStack(alignment: .bottom) {
                // Background container
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 10, height: 50)
                
                // Active level bar
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .green, .yellow, .red]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 10, height: max(4, CGFloat(level) * 50))
                    .animation(.easeOut(duration: 0.1), value: level)
            }
            
            // Display numerical value for debugging
            Text("\(Int(level * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct AudioLevelMeterRow: View {
    var level: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level >= Float(i) / 10 ? meterColor(for: Float(i) / 10) : Color.gray.opacity(0.2))
                    .frame(height: 20)
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }
    
    private func meterColor(for level: Float) -> Color {
        switch level {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
}

#Preview {
    VStack {
        AudioLevelMeter(level: 0.7)
        AudioLevelMeterRow(level: 0.7)
    }
}
