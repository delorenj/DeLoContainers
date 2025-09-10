#!/bin/bash
# Arturia KeyLab MIDI Diagnostic Script
# Purpose: Comprehensive MIDI device troubleshooting for Linux systems

echo "═══════════════════════════════════════════════════════════"
echo "          ARTURIA KEYLAB MIDI DIAGNOSTIC TOOL"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo "▶ $1"
    echo "───────────────────────────────────────────────────────────"
}

# Check if running as root (sometimes needed for USB access)
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  Running as root - good for hardware access"
else
   echo "ℹ️  Running as user: $USER"
   echo "   (Run with sudo if devices aren't visible)"
fi

# 1. USB Device Detection
print_section "USB DEVICE DETECTION"
echo "Searching for Arturia devices..."
lsusb 2>/dev/null | grep -i arturia || echo "❌ No Arturia USB devices detected"
echo ""
echo "All USB MIDI-related devices:"
lsusb 2>/dev/null | grep -iE "midi|audio|arturia|keylab" || echo "No MIDI/Audio USB devices found"

# 2. Kernel Module Check
print_section "KERNEL MODULES"
echo "USB Audio modules:"
lsmod | grep -E "snd_usb_audio|snd_seq_midi|snd_rawmidi" || echo "❌ USB audio modules not loaded"

# 3. ALSA MIDI Detection
print_section "ALSA MIDI DEVICES"
if command -v aconnect &> /dev/null; then
    echo "MIDI connections:"
    aconnect -l 2>/dev/null || echo "No MIDI connections available"
else
    echo "❌ aconnect not installed (install alsa-utils)"
fi

if command -v amidi &> /dev/null; then
    echo ""
    echo "Hardware MIDI devices:"
    amidi -l 2>/dev/null || echo "No hardware MIDI devices"
else
    echo "❌ amidi not installed"
fi

# 4. JACK Audio Check (if installed)
print_section "JACK AUDIO STATUS"
if command -v jack_lsp &> /dev/null; then
    if pgrep -x jackd > /dev/null; then
        echo "✅ JACK is running"
        echo "JACK MIDI ports:"
        jack_lsp -t | grep midi 2>/dev/null || echo "No JACK MIDI ports"
    else
        echo "⚠️  JACK is installed but not running"
    fi
else
    echo "ℹ️  JACK not installed (optional)"
fi

# 5. Device Files Check
print_section "DEVICE FILES"
echo "MIDI device files in /dev:"
ls -la /dev/midi* /dev/snd/midi* 2>/dev/null || echo "No MIDI device files found"
echo ""
echo "Sequencer devices:"
ls -la /dev/snd/seq 2>/dev/null || echo "No sequencer device"

# 6. USB Power Management
print_section "USB POWER MANAGEMENT"
echo "Checking USB autosuspend status..."
for i in /sys/bus/usb/devices/*/power/autosuspend; do
    if [ -f "$i" ]; then
        device=$(dirname $(dirname $i))
        value=$(cat $i 2>/dev/null)
        if [ "$value" != "-1" ]; then
            echo "⚠️  USB autosuspend enabled for $(basename $device): $value"
        fi
    fi
done

# 7. System Messages
print_section "RECENT USB/MIDI SYSTEM MESSAGES"
echo "Last 20 USB-related kernel messages:"
dmesg | grep -iE "usb|midi|arturia" | tail -20 || echo "No recent USB/MIDI messages"

# 8. Process Check
print_section "AUDIO PROCESSES"
echo "Audio-related processes:"
ps aux | grep -iE "pulse|jack|pipewire|midi" | grep -v grep || echo "No audio processes found"

# 9. Recommendations
print_section "TROUBLESHOOTING RECOMMENDATIONS"
echo "
Based on the diagnostic results, try these steps:

1. 🔌 USB Connection:
   - Try different USB ports (preferably USB 2.0)
   - Avoid USB hubs initially
   - Use a different USB cable if available

2. 🔄 Driver/Module Reload:
   sudo modprobe snd-usb-audio
   sudo modprobe snd-seq-midi

3. ⚡ Disable USB Autosuspend:
   echo -1 | sudo tee /sys/bus/usb/devices/*/power/autosuspend

4. 🔧 Reset USB Device:
   # Find your device ID with lsusb
   sudo usbreset [device_id]

5. 🎹 ALSA Configuration:
   alsa force-reload
   sudo alsactl restore

6. 📦 Required Packages:
   sudo apt install alsa-utils libasound2 alsa-firmware-loaders

7. 🔍 Monitor Connection:
   watch -n 1 'lsusb | grep -i arturia'
"

echo "═══════════════════════════════════════════════════════════"
echo "         Diagnostic Complete - $(date)"
echo "═══════════════════════════════════════════════════════════"