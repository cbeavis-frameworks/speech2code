//
//  ContentView.swift
//  Speech2Code
//
//  Created by Chris Beavis on 13/03/2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ConversationViewModel()
    @State private var showDebugPanel = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("AI Voice Assistant")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                // Debug toggle (small, unobtrusive)
                Button(action: {
                    showDebugPanel.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .opacity(0.5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
                
                // Audio level meter in header
                HStack(spacing: 10) {
                    AudioLevelMeterRow(level: viewModel.audioLevel)
                        .frame(width: 120)
                }
            }
            .padding()
            
            // Chat area
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Display conversation history from the model
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id) // Ensure each message has its unique ID for scrolling
                        }
                        
                        // Only show the typing indicator if we're waiting for a response
                        if viewModel.isProcessing {
                            // Show typing indicator in chat bubble when AI is working
                            TypingIndicatorView()
                                .padding(.vertical, 4)
                        }
                        
                        // Add bottom padding spacer to prevent messages from being too close to bottom
                        Spacer()
                            .frame(height: 40)
                            .id("bottomSpacer") // ID for scrolling to bottom
                    }
                    .padding(.vertical)
                    // Force refresh when messages change or are updated
                    .id("message-list-\(viewModel.messages.count)-\(Date())")
                }
                .background(Color.primary.opacity(0.05))
                .layoutPriority(1)
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Always scroll to the very bottom of the scroll view
                    withAnimation {
                        scrollView.scrollTo("bottomSpacer", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isProcessing) { _, _ in
                    // Always scroll to the very bottom when processing state changes
                    withAnimation {
                        scrollView.scrollTo("bottomSpacer", anchor: .bottom)
                    }
                }
            }
            
            // Debug Panel - fixed at bottom with set height
            if showDebugPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Information")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Group {
                        HStack {
                            Text("Processing:")
                                .bold()
                            Circle()
                                .fill(viewModel.isProcessing ? Color.yellow : Color.green)
                                .frame(width: 10, height: 10)
                            Text(viewModel.isProcessing ? "Yes" : "No")
                        }
                        
                        HStack {
                            Text("Listening:")
                                .bold()
                            Circle()
                                .fill(viewModel.isListening ? Color.blue : Color.gray)
                                .frame(width: 10, height: 10)
                            Text(viewModel.isListening ? "Yes" : "No")
                        }
                        
                        HStack {
                            Text("Speaking:")
                                .bold()
                            Circle()
                                .fill(viewModel.isSpeaking ? Color.orange : Color.gray)
                                .frame(width: 10, height: 10)
                            Text(viewModel.isSpeaking ? "Yes" : "No")
                        }
                        
                        Divider()
                        
                        if let error = viewModel.errorMessage, !error.isEmpty {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                        }
                        
                        Text("Automatic listening mode: always on")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("The microphone will automatically listen for your speech and pause after 2 seconds of silence.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }
                .padding()
                .frame(height: 200)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
