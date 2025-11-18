# 🤖 IoT Device Simulation Scripts

This directory contains everything needed to simulate a complete smart home IoT ecosystem for testing your Flutter app.

## 📁 Contents

```
scripts/
├── iot_simulation/
│   ├── device_simulator.js      # 🤖 AI-powered multi-device simulator
│   ├── virtual_bulb.js          # 💡 Standalone smart bulb
│   ├── virtual_fan.js           # 💨 Standalone smart fan
│   ├── package.json             # Node.js dependencies
│   └── node_modules/            # MQTT client library
│
├── start_iot_simulation.sh      # 🚀 Main startup script
├── stop_iot_simulation.sh       # 🛑 Cleanup and shutdown
└── test_mqtt_devices.sh         # 🧪 Interactive device tester
```

## 🎯 Quick Start

### 1. Start Everything

```bash
./start_iot_simulation.sh
```

Choose simulation mode:
- **Option 1**: All devices (bulbs, fans, thermostat, lock) - Recommended
- **Option 2**: Single smart bulb
- **Option 3**: Single smart fan
- **Option 4**: Bulb + Fan together

### 2. Test Devices

In a new terminal:

```bash
./test_mqtt_devices.sh
```

Follow the interactive prompts to control devices.

### 3. Stop Everything

```bash
./stop_iot_simulation.sh
```

## 🤖 Device Simulator Features

### Multi-Device AI Simulator (`device_simulator.js`)

**Simulates:**
- 2x Smart Bulbs (RGB, dimmable)
- 1x Smart Fan (5 speeds, oscillation)
- 1x Smart Thermostat (heating/cooling)
- 1x Smart Lock (with battery monitoring)

**Smart Features:**
- ✅ Responds to commands in real-time
- ✅ Publishes telemetry every 5 seconds
- ✅ Simulates realistic temperature changes
- ✅ Simulates battery drain
- ✅ Maintains persistent state
- ✅ Automatic reconnection

**Usage:**
```bash
cd iot_simulation
node device_simulator.js
```

### Individual Device Simulators

#### Smart Bulb (`virtual_bulb.js`)

**Capabilities:**
- On/Off control
- Brightness (0-100%)
- RGB color control
- State telemetry

**Topics:**
- Command: `home/bulb1/cmd`
- State: `home/bulb1/state`

**Example Commands:**
```bash
# Turn on
mqttx pub -t "home/bulb1/cmd" -m '{"action": "turnOn"}' -h localhost

# Set brightness
mqttx pub -t "home/bulb1/cmd" -m '{"brightness": 80}' -h localhost

# Change color to red
mqttx pub -t "home/bulb1/cmd" -m '{"color": {"r": 255, "g": 0, "b": 0}}' -h localhost
```

#### Smart Fan (`virtual_fan.js`)

**Capabilities:**
- On/Off control
- Speed levels (0-5)
- Oscillation toggle
- Timer support
- State telemetry

**Topics:**
- Command: `home/fan1/cmd`
- State: `home/fan1/state`

**Example Commands:**
```bash
# Set speed to 3
mqttx pub -t "home/fan1/cmd" -m '{"speed": 3}' -h localhost

# Enable oscillation
mqttx pub -t "home/fan1/cmd" -m '{"oscillating": true}' -h localhost
```

## 📡 MQTT Topics Reference

| Device | Command Topic | State Topic |
|--------|---------------|-------------|
| Bulb 1 | `home/bulb1/cmd` | `home/bulb1/state` |
| Bulb 2 | `home/bulb2/cmd` | `home/bulb2/state` |
| Fan 1 | `home/fan1/cmd` | `home/fan1/state` |
| Thermostat | `home/thermostat1/cmd` | `home/thermostat1/state` |
| Lock | `home/lock1/cmd` | `home/lock1/state` |

## 🔧 Management Scripts

### `start_iot_simulation.sh`

**What it does:**
1. ✅ Checks if Mosquitto broker is running
2. ✅ Starts broker if needed
3. ✅ Tests broker connectivity
4. ✅ Installs Node.js dependencies if missing
5. ✅ Presents simulation mode options
6. ✅ Starts selected simulators

**Features:**
- Colored output for easy reading
- Error handling and validation
- Automatic dependency installation
- Multiple simulation modes

### `stop_iot_simulation.sh`

**What it does:**
1. ✅ Stops all device simulators
2. ✅ Optionally stops Mosquitto broker
3. ✅ Cleans up processes

**Usage:**
```bash
./stop_iot_simulation.sh
# Answer 'y' to also stop the broker
```

### `test_mqtt_devices.sh`

**What it does:**
1. ✅ Interactive device selection
2. ✅ Command menu for each device type
3. ✅ Direct MQTT command sending
4. ✅ State monitoring option

**Features:**
- Easy-to-use menu interface
- Support for all device types
- Real-time state subscription
- JSON command building

## 🎓 Usage Examples

### Example 1: Test Complete Flow

```bash
# Terminal 1: Start simulator
./start_iot_simulation.sh
# Choose option 1 (All devices)

# Terminal 2: Monitor states
mqttx sub -t "home/+/state" -h localhost

# Terminal 3: Send commands
./test_mqtt_devices.sh
# Select device and send commands
```

### Example 2: Test Single Device

```bash
# Terminal 1: Start single bulb
./start_iot_simulation.sh
# Choose option 2

# Terminal 2: Control it
mqttx pub -t "home/bulb1/cmd" -m '{"action": "toggle"}' -h localhost
mqttx pub -t "home/bulb1/cmd" -m '{"brightness": 50}' -h localhost
```

### Example 3: Integration Test with Flutter

```bash
# 1. Start all devices
./start_iot_simulation.sh  # Choose option 1

# 2. In another terminal, run Flutter app
flutter run

# 3. Configure app to connect to localhost:1883

# 4. Control devices from app UI

# 5. Watch simulator console for responses

# 6. Verify state updates in app
```

## 🐛 Debugging

### Enable Debug Logging

Edit any `.js` simulator and add:

```javascript
// At the top
const DEBUG = true;

// Then use throughout:
if (DEBUG) console.log('Debug info:', data);
```

### Check Process Status

```bash
# Check if simulators are running
ps aux | grep "device_simulator\|virtual_"

# Check Mosquitto
pgrep mosquitto
brew services list | grep mosquitto
```

### View Logs

```bash
# Mosquitto logs
tail -f /opt/homebrew/var/log/mosquitto/mosquitto.log

# Simulator output is in the terminal where it was started
```

### Test Broker

```bash
# Publish test
mosquitto_pub -t test -m "hello" -h localhost -d

# Subscribe test
mosquitto_sub -t test -h localhost -d
```

## 🔌 Requirements

- **Mosquitto**: `brew install mosquitto`
- **Node.js**: Version 14 or higher
- **MQTTX CLI**: `npm install -g mqttx-cli`
- **MQTT npm package**: Auto-installed by start script

## 📚 Additional Resources

- **Full Guide**: See `../MQTT_SIMULATION_GUIDE.md`
- **Quick Reference**: See `../MQTT_QUICK_REFERENCE.md`
- **MQTT Protocol**: https://mqtt.org/
- **Mosquitto Docs**: https://mosquitto.org/

## 🎨 Customization

### Add New Device

Edit `iot_simulation/device_simulator.js`:

```javascript
myNewDevice: {
  type: 'switch',
  cmdTopic: 'home/switch1/cmd',
  stateTopic: 'home/switch1/state',
  state: {
    isOn: false,
    lastUpdate: new Date().toISOString()
  },
  icon: '🔌'
}
```

### Change Update Interval

In any simulator:

```javascript
const TELEMETRY_INTERVAL = 10000; // Change to 10 seconds
```

### Simulate Errors

Add error conditions:

```javascript
if (Math.random() < 0.05) {  // 5% error rate
  device.state.error = 'Device offline';
  publishState(deviceId);
}
```

## ✅ Verification

After setup, verify everything works:

```bash
# 1. Start simulation
./start_iot_simulation.sh

# 2. In new terminal, send test
mqttx pub -t "home/bulb1/cmd" -m '{"action": "turnOn"}' -h localhost

# 3. Subscribe to see state update
mqttx sub -t "home/bulb1/state" -h localhost

# Expected: {"isOn": true, "brightness": 60, ...}
```

## 🚀 You're Ready!

Everything is set up for realistic IoT device simulation. Start developing your Flutter app with confidence!

**Next Steps:**
1. Start the simulation
2. Configure Flutter app MQTT settings
3. Test device control from app
4. Build automation features
5. Test edge cases (offline, errors, etc.)

Happy coding! 🎉
