#!/usr/bin/env zsh

# HACS Installation Script for DeLoHome
# This script helps install HACS and essential custom components

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print styled messages
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
  echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

# Function to install HACS
install_hacs() {
  print_header "Installing HACS"
  
  # Create custom_components directory if it doesn't exist
  print_status "Creating custom_components directory..."
  mkdir -p /home/delorenj/docker/stacks/delohome/homeassistant/config/custom_components
  
  # Clone HACS repository
  print_status "Cloning HACS repository..."
  git clone --depth=1 https://github.com/hacs/integration /tmp/hacs
  
  # Copy HACS integration to custom_components
  print_status "Installing HACS to custom_components..."
  cp -r /tmp/hacs/custom_components/hacs /home/delorenj/docker/stacks/delohome/homeassistant/config/custom_components/
  
  # Clean up
  rm -rf /tmp/hacs
  
  print_success "HACS installation prepared!"
  print_status "After Home Assistant restarts, go to Configuration > Integrations > Add Integration > HACS"
  print_status "Follow the on-screen instructions to complete the setup."
}

# Function to add recommended custom components to configuration
add_recommended_components() {
  print_header "Adding Recommended Custom Components to Configuration"
  
  # Create configuration files
  print_status "Creating input_boolean.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/input_boolean.yaml << 'EOL'
# Input booleans for DeLoHome
voice_assistant_enabled:
  name: Voice Assistant Enabled
  icon: mdi:microphone
  initial: true

debug_mode:
  name: Debug Mode
  icon: mdi:bug
  initial: false
EOL

  print_status "Creating input_select.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/input_select.yaml << 'EOL'
# Input selects for DeLoHome
tts_voice:
  name: TTS Voice
  options:
    - "en_US-lessac-medium"
    - "en_US-arctic-medium"
    - "en_GB-alan-medium"
    - "en_GB-southern_english_female-medium"
  initial: "en_US-lessac-medium"
  icon: mdi:account-voice

tts_engine:
  name: TTS Engine
  options:
    - "Piper"
    - "Google Translate"
    - "Amazon Polly"
  initial: "Piper"
  icon: mdi:text-to-speech

stt_engine:
  name: STT Engine
  options:
    - "Whisper"
    - "Google STT"
    - "DeepSpeech"
  initial: "Whisper"
  icon: mdi:account-voice

wake_word_engine:
  name: Wake Word Engine
  options:
    - "Porcupine"
    - "Snowboy"
    - "Rhasspy"
  initial: "Porcupine"
  icon: mdi:ear-hearing
EOL

  print_status "Creating input_text.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/input_text.yaml << 'EOL'
# Input text for DeLoHome
wake_word:
  name: Wake Word
  initial: "hey computer"
  icon: mdi:microphone-message

mqtt_broker:
  name: MQTT Broker
  initial: "mosquitto"
  icon: mdi:server-network

mqtt_username:
  name: MQTT Username
  initial: ""
  icon: mdi:account

mqtt_password:
  name: MQTT Password
  initial: ""
  icon: mdi:form-textbox-password
EOL

  print_status "Creating input_number.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/input_number.yaml << 'EOL'
# Input numbers for DeLoHome
tts_speed:
  name: TTS Speed
  initial: 1.0
  min: 0.5
  max: 2.0
  step: 0.1
  icon: mdi:speedometer

stt_sensitivity:
  name: STT Sensitivity
  initial: 0.7
  min: 0.1
  max: 1.0
  step: 0.1
  icon: mdi:tune

mqtt_port:
  name: MQTT Port
  initial: 1883
  min: 1
  max: 65535
  step: 1
  icon: mdi:ethernet
EOL

  print_status "Creating scripts.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/scripts.yaml << 'EOL'
# Scripts for DeLoHome
test_voice:
  alias: Test Voice
  sequence:
    - service: tts.speak
      data:
        entity_id: media_player.delohome_speaker
        message: "Hello, this is a test of your DeLoHome voice assistant. Everything appears to be working correctly."

restart_voice_service:
  alias: Restart Voice Service
  sequence:
    - service: shell_command.restart_voice_service
      data: {}
    - delay:
        seconds: 5
    - service: persistent_notification.create
      data:
        title: "Voice Service"
        message: "Voice service has been restarted."

restart_system:
  alias: Restart System
  sequence:
    - service: shell_command.restart_homeassistant
      data: {}
    - delay:
        seconds: 5
    - service: persistent_notification.create
      data:
        title: "System Restart"
        message: "The system has been restarted. If you're seeing this message, the restart was successful."

backup_system:
  alias: Backup System
  sequence:
    - service: shell_command.create_backup
      data: {}
    - delay:
        seconds: 10
    - service: persistent_notification.create
      data:
        title: "Backup Created"
        message: "A backup of your configuration has been created."

check_updates:
  alias: Check Updates
  sequence:
    - service: shell_command.check_updates
      data: {}
    - delay:
        seconds: 5
    - service: persistent_notification.create
      data:
        title: "Updates"
        message: "Update check complete. See update logs for details."

run_diagnostics:
  alias: Run Diagnostics
  sequence:
    - service: shell_command.run_diagnostics
      data: {}
    - delay:
        seconds: 15
    - service: persistent_notification.create
      data:
        title: "Diagnostics"
        message: "Diagnostic tests complete. See diagnostic report for details."

setup_new_satellite:
  alias: Setup New Satellite
  sequence:
    - service: input_text.set_value
      target:
        entity_id: input_text.setup_device_name
      data:
        value: "new-satellite"
    - service: persistent_notification.create
      data:
        title: "New Satellite Setup"
        message: "Follow the instructions in the documentation to set up a new satellite device."
EOL

  print_status "Creating sensors.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/sensors.yaml << 'EOL'
# Sensors for DeLoHome
- platform: template
  sensors:
    homeassistant_status:
      friendly_name: "Home Assistant Status"
      value_template: "{{ states('sensor.homeassistant_uptime') }}"
      icon_template: "mdi:home-assistant"
    
    piper_tts_status:
      friendly_name: "Piper TTS Status"
      value_template: "{{ 'Online' if is_state('binary_sensor.piper_tts_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:text-to-speech"
    
    whisper_stt_status:
      friendly_name: "Whisper STT Status"
      value_template: "{{ 'Online' if is_state('binary_sensor.whisper_stt_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:microphone"
    
    mqtt_status:
      friendly_name: "MQTT Status"
      value_template: "{{ 'Connected' if is_state('binary_sensor.mqtt_connected', 'on') else 'Disconnected' }}"
      icon_template: "mdi:transit-connection"
    
    voice_assistant_requests:
      friendly_name: "Voice Assistant Requests"
      value_template: "{{ states('counter.voice_requests') }}"
      icon_template: "mdi:account-voice"
    
    voice_requests_today:
      friendly_name: "Voice Requests Today"
      value_template: "{{ states('counter.voice_requests_today') }}"
      icon_template: "mdi:calendar-today"
    
    last_voice_command:
      friendly_name: "Last Voice Command"
      value_template: "{{ states('input_text.last_voice_command') }}"
      icon_template: "mdi:text-to-speech"
    
    # Satellite status sensors
    living_room_satellite_status:
      friendly_name: "Living Room Satellite"
      value_template: "{{ 'Online' if is_state('binary_sensor.living_room_satellite_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:sofa"
    
    kitchen_satellite_status:
      friendly_name: "Kitchen Satellite"
      value_template: "{{ 'Online' if is_state('binary_sensor.kitchen_satellite_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:silverware-fork-knife"
    
    bedroom_satellite_status:
      friendly_name: "Bedroom Satellite"
      value_template: "{{ 'Online' if is_state('binary_sensor.bedroom_satellite_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:bed"
    
    office_satellite_status:
      friendly_name: "Office Satellite"
      value_template: "{{ 'Online' if is_state('binary_sensor.office_satellite_connected', 'on') else 'Offline' }}"
      icon_template: "mdi:desk"
EOL

  print_status "Creating shell_command.yaml..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/shell_command.yaml << 'EOL'
# Shell commands for DeLoHome
restart_homeassistant: "/home/delorenj/docker/stacks/delohome/homeassistant/delohome.sh restart homeassistant"
restart_voice_service: "/home/delorenj/docker/stacks/delohome/homeassistant/delohome.sh restart"
create_backup: "/home/delorenj/docker/stacks/delohome/homeassistant/delohome.sh backup"
check_updates: "/home/delorenj/docker/stacks/delohome/homeassistant/delohome.sh update"
run_diagnostics: "/home/delorenj/docker/stacks/delohome/homeassistant/delohome.sh status > /tmp/delohome-diagnostics.log && echo 'Diagnostics completed' || echo 'Diagnostics failed'"
EOL

  # Update configuration.yaml to include these files
  print_status "Updating configuration.yaml to include custom components..."
  cat >> /home/delorenj/docker/stacks/delohome/homeassistant/config/configuration.yaml << 'EOL'

# Include custom components
input_boolean: !include input_boolean.yaml
input_select: !include input_select.yaml
input_text: !include input_text.yaml
input_number: !include input_number.yaml
sensor: !include sensors.yaml
shell_command: !include shell_command.yaml

# Enable MQTT
mqtt:
  broker: !secret mqtt_broker
  port: !secret mqtt_port
  username: !secret mqtt_username
  password: !secret mqtt_password
  discovery: true
  discovery_prefix: homeassistant
EOL

  # Create secrets.yaml
  print_status "Creating secrets.yaml for sensitive information..."
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/secrets.yaml << 'EOL'
# DeLoHome Secrets
mqtt_broker: mosquitto
mqtt_port: 1883
mqtt_username: ""
mqtt_password: ""
EOL

  print_success "Custom components configuration completed!"
}

# Function to create HACS recommended components list
create_recommended_components_list() {
  print_header "Creating HACS Recommended Components List"
  
  cat > /home/delorenj/docker/stacks/delohome/homeassistant/config/HACS_RECOMMENDED.md << 'EOL'
# Recommended HACS Components for DeLoHome

After installing HACS, search for and install the following components to enhance your DeLoHome experience.

## Frontend

These components are required for the DeLoHome dashboard:

- **Mushroom Cards** - Beautiful and functional cards for your dashboard
- **Mini Graph Card** - Advanced graphs and charts
- **ApexCharts Card** - Additional chart types for analytics
- **Button Card** - Customizable buttons
- **Layout Card** - Enhanced layout options
- **Lovelace Swipe Navigation** - Improved mobile navigation
- **Card Mod** - Style cards with CSS

## Integrations

These integrations add functionality to your voice assistant:

- **Piper** - Local, privacy-focused TTS
- **Whisper** - Local, privacy-focused STT
- **Spotcast** - Enhanced Spotify integration
- **Browser Mod** - Browser-based media playback
- **Node-RED** - Advanced automation flows
- **Scheduler** - Advanced scheduling
- **MQTT Explorer** - Helps debug MQTT messages

## Additional

For even more functionality:

- **WLED** - Control LED strips
- **Adaptive Lighting** - Dynamic lighting based on time of day
- **Frigate** - Local NVR with AI object detection
- **ESPHome** - Custom IoT devices
- **Watchman** - System monitoring

## Installation

1. Go to Settings > Add-ons > HACS
2. Click on the desired component category (Frontend, Integrations, etc.)
3. Click the "+ Explore & Download Repositories" button
4. Search for the component name and install it
5. Restart Home Assistant when prompted
EOL

  print_success "Recommended components list created!"
}

# Main function to run all setup tasks
setup_all() {
  print_header "Setting Up HACS and Custom Components"
  
  install_hacs
  add_recommended_components
  create_recommended_components_list
  
  print_header "HACS and Custom Components Setup Complete!"
  print_success "All components have been prepared for HACS installation."
  print_status "Next steps:"
  print_status "1. Restart Home Assistant"
  print_status "2. Go to Configuration > Integrations > Add Integration > HACS"
  print_status "3. Follow the on-screen instructions to complete HACS setup"
  print_status "4. Refer to the HACS_RECOMMENDED.md file for recommended components"
  
  return 0
}

# Parse command line arguments
if [ $# -eq 0 ]; then
  # No arguments, run all setup tasks
  setup_all
else
  case $1 in
    hacs)
      install_hacs
      ;;
    components)
      add_recommended_components
      ;;
    recommended)
      create_recommended_components_list
      ;;
    all)
      setup_all
      ;;
    *)
      print_error "Unknown command: $1"
      echo "Available commands: hacs, components, recommended, all"
      exit 1
      ;;
  esac
fi

exit 0
