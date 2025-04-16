#!/usr/bin/env python3
"""
DeLoHome Satellite - Voice assistant client for Home Assistant
"""
import json
import os
import time
import argparse
import signal
import sys
import struct
import wave
import pvporcupine
import pyaudio
import sounddevice as sd
import numpy as np
import requests
import threading
import io
from datetime import datetime
import paho.mqtt.client as mqtt

# Load configuration
def load_config():
    """Load configuration from config.json"""
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config: {e}")
        sys.exit(1)

CONFIG = load_config()

# Setup logging
def log(message):
    """Log a message with timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

# MQTT setup
class MQTTClient:
    """MQTT client for DeLoHome satellite"""
    def __init__(self, config):
        self.client = mqtt.Client()
        if config.get("mqtt_username") and config.get("mqtt_password"):
            self.client.username_pw_set(config["mqtt_username"], config["mqtt_password"])
        
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.broker = config["mqtt_broker"]
        self.port = config.get("mqtt_port", 1883)
        self.connected = False
        self.satellite_name = config["name"]
        
    def on_connect(self, client, userdata, flags, rc):
        """Callback when connected to MQTT broker"""
        if rc == 0:
            log(f"Connected to MQTT broker at {self.broker}")
            self.connected = True
            # Subscribe to response topic
            topic = f"delohome/satellite/{self.satellite_name}/response"
            self.client.subscribe(topic)
            log(f"Subscribed to {topic}")
        else:
            log(f"Failed to connect to MQTT broker, return code: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback when message received"""
        log(f"Message received on {msg.topic}")
        try:
            payload = json.loads(msg.payload.decode())
            if payload.get("type") == "tts_response":
                # Handle TTS response
                self.play_audio_response(payload.get("response", ""))
        except Exception as e:
            log(f"Error processing message: {e}")
    
    def connect(self):
        """Connect to MQTT broker"""
        try:
            self.client.connect(self.broker, self.port, 60)
            self.client.loop_start()
        except Exception as e:
            log(f"Error connecting to MQTT: {e}")
    
    def publish_audio(self, audio_data):
        """Publish audio data for processing"""
        if not self.connected:
            log("Not connected to MQTT broker")
            return
        
        topic = f"delohome/satellite/{self.satellite_name}/audio"
        self.client.publish(topic, audio_data)
        log(f"Published audio data to {topic}")
    
    def play_audio_response(self, text):
        """Play audio response using Piper TTS"""
        if not text:
            return
            
        log(f"Playing response: {text}")
        try:
            # Get audio from Piper TTS
            url = f"{CONFIG['piper_url']}/api/tts"
            response = requests.post(url, json={"text": text}, timeout=10)
            
            if response.status_code == 200:
                # Play audio
                audio_data = response.content
                audio_buffer = io.BytesIO(audio_data)
                
                with wave.open(audio_buffer, 'rb') as wave_file:
                    sample_rate = wave_file.getframerate()
                    audio = np.frombuffer(wave_file.readframes(wave_file.getnframes()), dtype=np.int16)
                    sd.play(audio, sample_rate)
                    sd.wait()
            else:
                log(f"Error getting TTS: {response.status_code}")
        except Exception as e:
            log(f"Error playing audio response: {e}")
    
    def stop(self):
        """Stop MQTT client"""
        self.client.loop_stop()
        self.client.disconnect()

# Wake word detection
class WakeWordDetector:
    """Wake word detection using Porcupine"""
    def __init__(self, config):
        self.config = config
        self.porcupine = pvporcupine.create(keywords=[config["wake_word"]])
        self.pa = pyaudio.PyAudio()
        self.audio_stream = self.pa.open(
            rate=self.porcupine.sample_rate,
            channels=1,
            format=pyaudio.paInt16,
            input=True,
            frames_per_buffer=self.porcupine.frame_length,
            input_device_index=config.get("audio_device_index", None)
        )
        self.running = False
        
    def start(self, callback):
        """Start listening for wake word"""
        self.running = True
        log(f"Listening for wake word: {self.config['wake_word']}")
        
        try:
            while self.running:
                pcm = self.audio_stream.read(self.porcupine.frame_length)
                pcm = struct.unpack_from("h" * self.porcupine.frame_length, pcm)
                
                keyword_index = self.porcupine.process(pcm)
                if keyword_index >= 0:
                    log("Wake word detected!")
                    callback()
        except Exception as e:
            log(f"Error in wake word detection: {e}")
    
    def stop(self):
        """Stop wake word detection"""
        self.running = False
        self.audio_stream.close()
        self.pa.terminate()
        self.porcupine.delete()

# Audio recorder
class AudioRecorder:
    """Records audio after wake word detection"""
    def __init__(self, config):
        self.config = config
        self.pa = pyaudio.PyAudio()
        self.recording = False
        self.frames = []
        self.sample_rate = 16000
        self.chunk_size = 1024
        
    def start_recording(self):
        """Start recording audio"""
        self.frames = []
        self.recording = True
        log("Recording started")
        
        self.audio_stream = self.pa.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=self.sample_rate,
            input=True,
            frames_per_buffer=self.chunk_size,
            input_device_index=self.config.get("audio_device_index", None)
        )
        
        # Record for up to 10 seconds (or until stop_recording is called)
        start_time = time.time()
        while self.recording and (time.time() - start_time) < 10:
            data = self.audio_stream.read(self.chunk_size)
            self.frames.append(data)
            
            # Check for silence to auto-stop (simplified)
            if len(self.frames) > 10:  # After some initial audio
                audio_data = np.frombuffer(data, dtype=np.int16)
                if np.abs(audio_data).mean() < 100:  # Very simple silence detection
                    silent_chunks = getattr(self, 'silent_chunks', 0) + 1
                    self.silent_chunks = silent_chunks
                    if silent_chunks > 10:  # About 1 second of silence
                        log("Silence detected, stopping recording")
                        break
                else:
                    self.silent_chunks = 0
        
        self.stop_recording()
        return self.get_wav_data()
    
    def stop_recording(self):
        """Stop recording audio"""
        if hasattr(self, 'audio_stream') and self.audio_stream.is_active():
            self.recording = False
            self.audio_stream.stop_stream()
            self.audio_stream.close()
            log("Recording stopped")
    
    def get_wav_data(self):
        """Convert recorded frames to WAV format"""
        if not self.frames:
            return None
            
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(self.pa.get_sample_size(pyaudio.paInt16))
            wf.setframerate(self.sample_rate)
            wf.writeframes(b''.join(self.frames))
        
        return buffer.getvalue()
    
    def cleanup(self):
        """Clean up resources"""
        self.pa.terminate()

# Speech processing
class SpeechProcessor:
    """Processes recorded speech using Whisper STT and Home Assistant"""
    def __init__(self, config):
        self.config = config
        
    def process_audio(self, audio_data):
        """Process audio with Whisper STT and send to Home Assistant"""
        if not audio_data:
            return None
            
        try:
            # Send to Whisper STT
            url = f"{self.config['whisper_url']}/asr?task=transcribe&language=en"
            files = {"audio_file": ("audio.wav", audio_data, "audio/wav")}
            response = requests.post(url, files=files, timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                text = result.get("text", "").strip()
                log(f"Recognized: {text}")
                
                if text:
                    # Send to Home Assistant
                    return self.send_to_home_assistant(text)
            else:
                log(f"Error from STT service: {response.status_code}")
        except Exception as e:
            log(f"Error processing speech: {e}")
        
        return None
    
    def send_to_home_assistant(self, text):
        """Send recognized text to Home Assistant conversation API"""
        try:
            url = f"{self.config['home_assistant_url']}/api/conversation/process"
            headers = {
                "Authorization": f"Bearer {self.config['home_assistant_token']}",
                "Content-Type": "application/json"
            }
            payload = {
                "text": text,
                "language": "en"
            }
            response = requests.post(url, headers=headers, json=payload, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                speech = result.get("response", {}).get("speech", {}).get("plain", {}).get("speech", "")
                log(f"Home Assistant response: {speech}")
                return speech
            else:
                log(f"Error from Home Assistant: {response.status_code}")
        except Exception as e:
            log(f"Error sending to Home Assistant: {e}")
        
        return None

# Main satellite class
class Satellite:
    """Main class for DeLoHome satellite"""
    def __init__(self, config):
        self.config = config
        self.mqtt_client = MQTTClient(config)
        self.wake_word_detector = WakeWordDetector(config)
        self.audio_recorder = AudioRecorder(config)
        self.speech_processor = SpeechProcessor(config)
        self.detection_thread = None
        self.running = False
        
    def on_wake_word_detected(self):
        """Called when wake word is detected"""
        # Play a sound to indicate wake word detection
        sd.play(np.sin(2 * np.pi * 1000 * np.arange(8000) / 8000) * 0.3, 8000)
        sd.wait()
        
        # Record audio
        audio_data = self.audio_recorder.start_recording()
        
        # Process speech
        response = self.speech_processor.process_audio(audio_data)
        
        # Play response
        if response:
            self.mqtt_client.play_audio_response(response)
    
    def start(self):
        """Start the satellite"""
        self.running = True
        self.mqtt_client.connect()
        
        # Start wake word detection in a thread
        self.detection_thread = threading.Thread(target=self.wake_word_detector.start, 
                                                args=(self.on_wake_word_detected,))
        self.detection_thread.daemon = True
        self.detection_thread.start()
        
        log(f"DeLoHome satellite '{self.config['name']}' started")
        log(f"Listening for wake word: {self.config['wake_word']}")
        
        # Keep the main thread alive
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
    
    def stop(self):
        """Stop the satellite"""
        self.running = False
        self.wake_word_detector.stop()
        self.audio_recorder.cleanup()
        self.mqtt_client.stop()
        log("DeLoHome satellite stopped")

# Command line interface
def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="DeLoHome Satellite")
    parser.add_argument("--list-devices", action="store_true", help="List available audio devices")
    args = parser.parse_args()
    
    if args.list_devices:
        pa = pyaudio.PyAudio()
        for i in range(pa.get_device_count()):
            dev = pa.get_device_info_by_index(i)
            print(f"Device {i}: {dev['name']}")
            print(f"  Input channels: {dev['maxInputChannels']}")
            print(f"  Output channels: {dev['maxOutputChannels']}")
            print(f"  Default sample rate: {dev['defaultSampleRate']}")
            print()
        pa.terminate()
        return
    
    # Set up signal handling
    def signal_handler(sig, frame):
        print("Exiting...")
        if 'satellite' in locals():
            satellite.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Load config and start satellite
    config = load_config()
    satellite = Satellite(config)
    satellite.start()

if __name__ == "__main__":
    main()
EOF
chown $SUDO_USER:$SUDO_USER /opt/delohome/satellite.py
chmod +x /opt/delohome/satellite.py
print_success "Created satellite script at /opt/delohome/satellite.py"

# Create systemd service
print_header "Creating SystemD Service"
cat > /etc/systemd/system/delohome-satellite.service << EOF
[Unit]
Description=DeLoHome Voice Assistant Satellite
After=network.target

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=/opt/delohome
ExecStart=/opt/delohome/.venv/bin/python /opt/delohome/satellite.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
print_header "Enabling and Starting Service"
systemctl daemon-reload
systemctl enable delohome-satellite.service
systemctl start delohome-satellite.service

print_success "DeLoHome satellite setup complete!"
print_status "Satellite service is now running and will start automatically on boot"
print_status "To check status: systemctl status delohome-satellite"
print_status "To view logs: journalctl -u delohome-satellite -f"
print_warning "Don't forget to edit /opt/delohome/config.json with your specific settings"

# Test audio devices
print_header "Available Audio Devices"
su - $SUDO_USER -c "cd /opt/delohome && source .venv/bin/activate && python satellite.py --list-devices"
print_status "Use the device index in config.json for your microphone"
print_status "Example: \"audio_device_index\": 1"

exit 0
EOL
chmod +x "$script_dir/setup_satellite.sh"
print_success "Created satellite setup script at: $script_dir/setup_satellite.sh"
print_status "You can copy this script to any Raspberry Pi and run it with sudo"
}

# Function to set up example automation
setup_example_automation() {
  print_header "Setting Up Example Voice Automation"
  
  print_step "Creating example automation file"
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/voice_automations.yaml << 'EOL'
# DeLoHome Voice Assistant Automations

# Response customization
- id: custom_greeting_response
  alias: "Custom Greeting Response"
  trigger:
    platform: conversation
    pattern: "(hi|hello|hey|good morning|good afternoon|good evening).*"
  action:
    - service: conversation.process
      data:
        agent_id: homeassistant
        text: >
          {% set responses = [
            "Hello! How can I help you today?",
            "Hi there! What can I do for you?",
            "Hey! I'm listening. What do you need?",
            "Greetings! How may I assist you?",
            "Hello! DeLoHome at your service!"
          ] %}
          {{ responses | random }}

# Weather information
- id: custom_weather_response
  alias: "Custom Weather Response"
  trigger:
    platform: conversation
    pattern: "what('s| is) (the|today's) weather( like| going to be)?( today| tomorrow)?"
  condition:
    - condition: state
      entity_id: weather.home
      attribute: temperature
  action:
    - service: conversation.process
      data:
        agent_id: homeassistant
        text: >
          {% set temp = states('sensor.temperature') | float %}
          {% set condition = states('weather.home').attributes.condition %}
          {% set forecast = states('weather.home').attributes.forecast[0] if 'tomorrow' in trigger.slots.text else None %}
          
          {% if 'tomorrow' in trigger.slots.text and forecast %}
            Tomorrow will be {{ forecast.condition }} with a high of {{ forecast.temperature }} degrees.
          {% else %}
            Currently it's {{ temp }} degrees and {{ condition }}. 
            {% if temp < 50 %}
              It's quite cold, you might want to wear a jacket.
            {% elif temp < 70 %}
              The temperature is moderate today.
            {% else %}
              It's pretty warm today.
            {% endif %}
          {% endif %}

# Multi-room announcement
- id: home_announcement
  alias: "Home-wide Announcement"
  trigger:
    platform: conversation
    pattern: "announce (that )?{message}"
  action:
    - service: mqtt.publish
      data:
        topic: "delohome/broadcast/tts"
        payload_template: "{{ trigger.slots.message }}"
        retain: false
EOL

  print_step "Adding to Home Assistant configuration"
  echo "automation: !include_dir_merge_list automations" >> /home/delorenj/docker/stacks/delohome/homeassistant/config/configuration.yaml
  echo "automation voice: !include voice_automations.yaml" >> /home/delorenj/docker/stacks/delohome/homeassistant/config/configuration.yaml
  
  print_success "Example voice automations added!"
}

# Function to create a README file
create_readme() {
  print_header "Creating README"
  
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/README.md << 'EOL'
# DeLoHome - Personal Voice Assistant

## Overview

DeLoHome is a privacy-focused, locally-controlled smart home system based on Home Assistant. This setup replaces cloud-based assistants like Google Home and Alexa with a solution that gives you complete ownership of your data and full customization options.

## Getting Started

1. Start the stack:
   ```bash
   ./delohome.sh start
   ```

2. Access Home Assistant at: http://localhost:8123

3. Follow the onboarding steps in Home Assistant

## Voice Assistant Setup

The DeLoHome stack includes all necessary components for a voice assistant:

1. Home Assistant - Central hub
2. Piper TTS - Text-to-speech
3. Whisper STT - Speech-to-text
4. MQTT - Communication between components
5. Satellite devices - Distributed listening points

### Setting Up Satellite Devices

For each Raspberry Pi you want to use as a satellite:

1. Copy the `scripts/setup_satellite.sh` script to the Raspberry Pi
2. Run with sudo: `sudo ./setup_satellite.sh`
3. Edit the config file at `/opt/delohome/config.json` with your specific settings
4. Restart the service: `sudo systemctl restart delohome-satellite`

## Management

Use the included management script for common tasks:

```bash
# Start the stack
./delohome.sh start

# Stop the stack
./delohome.sh stop

# View logs
./delohome.sh logs

# Update containers
./delohome.sh update

# Back up configuration
./delohome.sh backup
```

## Customization

* Home Assistant configuration: `./config/`
* Voice automations: `./config/voice_automations.yaml`
* MQTT settings: `./mosquitto/config/`
* Piper TTS voices can be changed in the Piper container

## Troubleshooting

* Check logs with: `./delohome.sh logs [service]`
* Verify container status: `./delohome.sh status`
* View satellite logs: `journalctl -u delohome-satellite -f`
* Test audio devices: `/opt/delohome/satellite.py --list-devices`

## Resources

* Home Assistant Docs: https://www.home-assistant.io/docs/
* Mosquitto MQTT: https://mosquitto.org/documentation/
* Piper TTS: https://github.com/rhasspy/piper
* Whisper STT: https://github.com/openai/whisper
EOL

  print_success "README created!"
}

# Main function to run all setup tasks
setup_all() {
  print_header "Setting Up DeLoHome Voice Assistant Components"
  
  setup_piper_tts
  setup_whisper_stt
  setup_ha_voice
  create_satellite_script
  setup_example_automation
  create_readme
  
  print_header "Setup Complete!"
  print_success "All DeLoHome voice assistant components have been set up!"
  print_status "Next steps:"
  print_status "1. Start the Home Assistant stack with: cd /home/delorenj/docker/stacks/delohome/homeassistant && ./delohome.sh start"
  print_status "2. Complete the Home Assistant onboarding at http://localhost:8123"
  print_status "3. Set up additional containers with: cd /home/delorenj/docker/stacks/delohome/piper-tts && docker compose up -d"
  print_status "4. Configure satellite devices using the setup script in /home/delorenj/code/DeLoContainers/scripts/"
  
  return 0
}

# Parse command line arguments
if [ $# -eq 0 ]; then
  # No arguments, run all setup tasks
  setup_all
else
  case $1 in
    piper)
      setup_piper_tts
      ;;
    whisper)
      setup_whisper_stt
      ;;
    ha-voice)
      setup_ha_voice
      ;;
    satellite)
      create_satellite_script
      ;;
    automation)
      setup_example_automation
      ;;
    readme)
      create_readme
      ;;
    all)
      setup_all
      ;;
    *)
      print_error "Unknown command: $1"
      echo "Available commands: piper, whisper, ha-voice, satellite, automation, readme, all"
      exit 1
      ;;
  esac
fi

exit 0
