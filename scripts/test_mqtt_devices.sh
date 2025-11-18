#!/bin/bash

# MQTT Command Line Tester
# Use this to manually send commands to virtual devices

BROKER="localhost"

echo "🧪 MQTT Device Command Tester"
echo "=============================="
echo ""

# Check if mqttx is available
if ! command -v mqttx &> /dev/null; then
    echo "❌ mqttx CLI not found. Install with: npm install -g mqttx-cli"
    exit 1
fi

echo "Select device to control:"
echo ""
echo "  1) Bulb 1"
echo "  2) Bulb 2"
echo "  3) Fan 1"
echo "  4) Thermostat 1"
echo "  5) Lock 1"
echo "  6) Subscribe to device states"
echo ""
read -p "Enter choice [1-6]: " device_choice

case $device_choice in
    1|2)
        BULB_NUM=$device_choice
        TOPIC="home/bulb${BULB_NUM}/cmd"
        echo ""
        echo "💡 Bulb ${BULB_NUM} Commands:"
        echo "  1) Turn ON"
        echo "  2) Turn OFF"
        echo "  3) Toggle"
        echo "  4) Set brightness (0-100)"
        echo "  5) Set color (RGB)"
        echo ""
        read -p "Enter choice [1-5]: " cmd_choice
        
        case $cmd_choice in
            1) mqttx pub -t "$TOPIC" -m '{"action": "turnOn"}' -h "$BROKER" ;;
            2) mqttx pub -t "$TOPIC" -m '{"action": "turnOff"}' -h "$BROKER" ;;
            3) mqttx pub -t "$TOPIC" -m '{"action": "toggle"}' -h "$BROKER" ;;
            4)
                read -p "Enter brightness (0-100): " brightness
                mqttx pub -t "$TOPIC" -m "{\"brightness\": $brightness}" -h "$BROKER"
                ;;
            5)
                read -p "Enter R (0-255): " r
                read -p "Enter G (0-255): " g
                read -p "Enter B (0-255): " b
                mqttx pub -t "$TOPIC" -m "{\"color\": {\"r\": $r, \"g\": $g, \"b\": $b}}" -h "$BROKER"
                ;;
        esac
        ;;
        
    3)
        TOPIC="home/fan1/cmd"
        echo ""
        echo "💨 Fan Commands:"
        echo "  1) Turn ON"
        echo "  2) Turn OFF"
        echo "  3) Set speed (0-5)"
        echo "  4) Toggle oscillation"
        echo ""
        read -p "Enter choice [1-4]: " cmd_choice
        
        case $cmd_choice in
            1) mqttx pub -t "$TOPIC" -m '{"action": "turnOn"}' -h "$BROKER" ;;
            2) mqttx pub -t "$TOPIC" -m '{"action": "turnOff"}' -h "$BROKER" ;;
            3)
                read -p "Enter speed (0-5): " speed
                mqttx pub -t "$TOPIC" -m "{\"speed\": $speed}" -h "$BROKER"
                ;;
            4) mqttx pub -t "$TOPIC" -m '{"oscillating": true}' -h "$BROKER" ;;
        esac
        ;;
        
    4)
        TOPIC="home/thermostat1/cmd"
        echo ""
        echo "🌡️  Thermostat Commands:"
        echo "  1) Set target temperature"
        echo "  2) Set mode (heat/cool/auto/off)"
        echo ""
        read -p "Enter choice [1-2]: " cmd_choice
        
        case $cmd_choice in
            1)
                read -p "Enter target temperature (°C): " temp
                mqttx pub -t "$TOPIC" -m "{\"targetTemp\": $temp}" -h "$BROKER"
                ;;
            2)
                read -p "Enter mode (heat/cool/auto/off): " mode
                mqttx pub -t "$TOPIC" -m "{\"mode\": \"$mode\"}" -h "$BROKER"
                ;;
        esac
        ;;
        
    5)
        TOPIC="home/lock1/cmd"
        echo ""
        echo "🔒 Lock Commands:"
        echo "  1) Lock"
        echo "  2) Unlock"
        echo ""
        read -p "Enter choice [1-2]: " cmd_choice
        
        case $cmd_choice in
            1) mqttx pub -t "$TOPIC" -m '{"action": "lock"}' -h "$BROKER" ;;
            2) mqttx pub -t "$TOPIC" -m '{"action": "unlock"}' -h "$BROKER" ;;
        esac
        ;;
        
    6)
        echo ""
        echo "📡 Subscribing to all device states..."
        echo "Press Ctrl+C to stop"
        echo ""
        mqttx sub -t "home/+/state" -h "$BROKER"
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Command sent!"
echo ""
echo "💡 Tip: Subscribe to states with: mqttx sub -t 'home/+/state' -h localhost"
