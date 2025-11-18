#!/bin/bash

# IoT Simulation - Stop All Components

echo "🛑 Stopping Home Automation IoT Simulation"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kill Node.js simulation processes
echo "⚙️  Stopping device simulators..."
pkill -f "virtual_bulb.js" 2>/dev/null
pkill -f "virtual_fan.js" 2>/dev/null
pkill -f "device_simulator.js" 2>/dev/null
echo -e "${GREEN}✅ Device simulators stopped${NC}"
echo ""

# Ask about stopping Mosquitto
read -p "Do you want to stop the MQTT broker (Mosquitto)? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "⚙️  Stopping Mosquitto broker..."
    brew services stop mosquitto
    echo -e "${GREEN}✅ Mosquitto stopped${NC}"
else
    echo -e "${YELLOW}ℹ️  Mosquitto broker left running${NC}"
fi

echo ""
echo "✅ Cleanup complete!"
