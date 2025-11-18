#!/bin/bash

# IoT Simulation Manager - Start All Components

echo "🚀 Starting Home Automation IoT Simulation"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Mosquitto is running
echo "📡 Checking MQTT Broker (Mosquitto)..."
if pgrep -x "mosquitto" > /dev/null; then
    echo -e "${GREEN}✅ Mosquitto is already running${NC}"
else
    echo -e "${YELLOW}⚙️  Starting Mosquitto broker...${NC}"
    brew services start mosquitto
    sleep 2
    echo -e "${GREEN}✅ Mosquitto started${NC}"
fi
echo ""

# Test broker connectivity
echo "🧪 Testing broker connectivity..."
if mosquitto_pub -t test/ping -m "ping" -h localhost 2>/dev/null; then
    echo -e "${GREEN}✅ MQTT Broker is accessible${NC}"
else
    echo -e "${RED}❌ Failed to connect to MQTT broker${NC}"
    echo "   Please check if Mosquitto is installed and running"
    exit 1
fi
echo ""

# Install dependencies if needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOT_DIR="$SCRIPT_DIR/iot_simulation"

if [ ! -d "$IOT_DIR/node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    cd "$IOT_DIR"
    npm init -y > /dev/null 2>&1
    npm install mqtt > /dev/null 2>&1
    echo -e "${GREEN}✅ Dependencies installed${NC}"
    echo ""
fi

# Present simulation options
echo "🎯 Select simulation mode:"
echo ""
echo "  1) Run ALL devices (Smart Agent - Recommended)"
echo "  2) Run single bulb only"
echo "  3) Run single fan only"
echo "  4) Run bulb + fan"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "🤖 Starting AI-Powered Device Simulator..."
        echo "   This will simulate: Bulbs, Fans, Thermostat, Lock"
        echo ""
        cd "$IOT_DIR"
        node device_simulator.js
        ;;
    2)
        echo ""
        echo "💡 Starting Virtual Bulb..."
        echo "   Command Topic: home/bulb1/cmd"
        echo "   State Topic:   home/bulb1/state"
        echo ""
        cd "$IOT_DIR"
        node virtual_bulb.js
        ;;
    3)
        echo ""
        echo "💨 Starting Virtual Fan..."
        echo "   Command Topic: home/fan1/cmd"
        echo "   State Topic:   home/fan1/state"
        echo ""
        cd "$IOT_DIR"
        node virtual_fan.js
        ;;
    4)
        echo ""
        echo "💡💨 Starting Virtual Bulb + Fan..."
        echo ""
        # Run both in background with process management
        cd "$IOT_DIR"
        node virtual_bulb.js &
        BULB_PID=$!
        node virtual_fan.js &
        FAN_PID=$!
        
        # Trap Ctrl+C to stop both
        trap "echo ''; echo '🛑 Stopping all devices...'; kill $BULB_PID $FAN_PID 2>/dev/null; exit 0" SIGINT
        
        echo "💡 Bulb running (PID: $BULB_PID)"
        echo "💨 Fan running (PID: $FAN_PID)"
        echo ""
        echo "Press Ctrl+C to stop all devices"
        
        # Wait for processes
        wait
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac
