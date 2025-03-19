# Speech2Code Project Overview

## Introduction

Speech2Code is a voice-activated AI coding assistant application that enables seamless interaction with an AI through natural language. The application combines speech recognition, AI text generation, and text-to-speech capabilities to create a hands-free coding assistance experience.

### Key Features

- Real-time speech recognition for continuous user input
- AI-powered responses using OpenAI's models 
- Text-to-speech audio output via ElevenLabs streaming service
- Progressive streaming of AI responses in the chat UI
- Voice-controlled programming assistance
- Elegant macOS native interface with SwiftUI

## Project Structure

The codebase is organized into several main components:

- **Main App**: Core application setup and entry points
- **Models**: Data structures and business logic
- **ViewModels**: State management and business logic for views
- **Views**: UI components and layouts
- **Services**: Integration with external APIs and core functionality

## File Descriptions

### Root Files

- `Speech2CodeApp.swift`: The main entry point of the application that sets up the SwiftUI lifecycle and initializes the primary window.
- `ContentView.swift`: The main view of the application containing the conversation interface, microphone controls, and overall layout.
- `Item.swift`: A utility data model file (possibly for SwiftData or CoreData integration).

### Models

- `Models/Message.swift`: Defines the Message data structure for chat messages and the ConversationModel that manages the collection of messages. Includes Hashable conformance for proper list updates and methods for adding, updating, and deleting messages.

### ViewModels

- `ViewModels/ConversationViewModel.swift`: The central coordinator that manages conversation state, handles AI responses, manages speech recognition, and coordinates between the UI and various services. Implements sophisticated message handling to prevent duplication.

### Views

- `Views/MessageView.swift`: Responsible for rendering individual chat messages with appropriate styling based on sender (user or AI).
- `Views/MicrophoneButton.swift`: A custom button control for activating and deactivating speech recognition.
- `Views/AudioLevelMeter.swift`: Visual component that displays audio input levels during speech recognition.
- `Views/TypingIndicatorView.swift`: Animated indicator shown while waiting for AI responses.

### Services

- `Services/SpeechRecognitionService.swift`: Handles continuous speech recognition using Apple's Speech framework, converting spoken words to text.
- `Services/OpenAIChatService.swift`: Manages communication with OpenAI's API for generating AI responses to user queries, with proper handling of streaming responses.
- `Services/OpenAIRealtimeService.swift`: Handles real-time streaming of responses from the OpenAI API.
- `Services/ElevenLabsStreamingService.swift`: Enhanced service for real-time streaming of audio from ElevenLabs, with WebSocket-based communication for better performance.

### Tests

- `Speech2CodeTests/Speech2CodeTests.swift`: Unit tests for application functionality.
- `Speech2CodeUITests/Speech2CodeUITests.swift`: UI tests for application interface.
- `Speech2CodeUITests/Speech2CodeUITestsLaunchTests.swift`: Tests for application launch behavior.

## Architecture

The application follows a MVVM (Model-View-ViewModel) architecture:

1. **Models** (Message, ConversationModel) define the data structures and core logic
2. **Views** (ContentView, MessageView, etc.) handle the UI presentation
3. **ViewModels** (ConversationViewModel) coordinate between models and views, managing state

Services are used to encapsulate external API interactions and complex functionality, keeping the rest of the codebase clean and focused.

## Communication Flow

1. User speaks into the microphone
2. SpeechRecognitionService converts speech to text
3. ConversationViewModel sends the text to OpenAIChatService
4. AI response is generated and streamed back
5. ConversationViewModel updates the UI with each response chunk
6. ElevenLabsStreamingService converts the response text to speech for audio playback
7. UI updates in real-time with both text and audio

## Recent Improvements

- Enhanced real-time streaming of AI responses in the UI
- Improved WebSocket connection handling for more reliable audio streaming
- Added better error recovery for audio playback
- Fixed Hashable conformance for Message model to ensure proper list updates
- Optimized UI refresh logic for smoother experience
- Fixed message duplication issues in the conversation flow
- Added intelligent duplicate detection for user messages
- Improved handling of progressive messages during speech recognition
- Enhanced message management with deletion capability
- Optimized state management for AI response processing
- Simplified the text-to-speech implementation by using only the streaming service
