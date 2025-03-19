# Speech2Code: Voice-enabled AI Conversation App

This macOS application allows you to have conversations with AI using your voice. It captures your speech via the microphone, converts it to text using Apple's speech recognition, sends it to OpenAI's Realtime API, and speaks the response using ElevenLabs speech synthesis.

## Features

- **Voice Input**: Capture your voice through your Mac's microphone
- **Real-time Audio Level Visualization**: See when your voice is being detected
- **Speech-to-Text**: Convert speech to text using Apple's native speech recognition
- **AI Processing**: Process text with OpenAI's Realtime API
- **Text-to-Speech**: Convert AI responses to natural-sounding speech with ElevenLabs
- **Conversation History**: View the entire conversation in a text window

## Requirements

- macOS 14.0 (Sonoma) or later
- Microphone access
- Internet connection
- OpenAI API key (Realtime API enabled)
- ElevenLabs API key

## Setup

1. Make sure the `.env` file is properly set up with your API keys:
   ```
   OPENAI_API_KEY="your_openai_api_key_here"
   ELEVENLABS_API_KEY="your_elevenlabs_api_key_here"
   ```

2. Build and run the app in Xcode

3. Grant microphone and speech recognition permissions when prompted

## Using the App

1. Press the **Microphone button** (blue circle) to start recording your voice
2. Speak clearly into your microphone - you'll see the audio level meter respond
3. Press the button again (now red) to stop recording
4. The app will process your speech, send it to the AI, and speak the response
5. Your conversation history appears in the main window

## Troubleshooting

- If the app doesn't respond to your voice, check that you've granted microphone permissions in System Preferences > Privacy & Security > Microphone
- If API responses fail, verify your API keys in the `.env` file are correct and that you have billing set up with both services
- For ElevenLabs voice issues, ensure you have enough credits in your ElevenLabs account

## Technologies Used

- SwiftUI for the user interface
- Apple's Speech framework for speech recognition
- WebSocket connections to OpenAI's Realtime API
- ElevenLabs API for text-to-speech conversion
- AVFoundation for audio processing and playback

## Privacy

This application processes your voice locally for speech-to-text conversion, but sends the resulting text to OpenAI's servers. AI responses are also sent to ElevenLabs for voice synthesis. Please review the privacy policies of these services if you have concerns about data usage.
