#!/usr/bin/env node

/**
 * AI-Powered IoT Device Simulator
 * 
 * This intelligent agent simulates multiple IoT devices simultaneously:
 * - Smart Bulbs
 * - Smart Fans
 * - Smart Thermostats
 * - Smart Locks
 * 
 * It responds to commands and publishes realistic telemetry data.
 */

const mqtt = require('mqtt');

const BROKER_URL = 'mqtt://localhost:1883';
const TELEMETRY_INTERVAL = 5000;

// Device registry - add new devices here
const devices = {
  bulb1: {
    type: 'bulb',
    cmdTopic: 'home/bulb1/cmd',
    stateTopic: 'home/bulb1/state',
    state: {
      isOn: false,
      brightness: 60,
      color: { r: 255, g: 255, b: 255 },
      lastUpdate: new Date().toISOString()
    },
    icon: '💡'
  },
  bulb2: {
    type: 'bulb',
    cmdTopic: 'home/bulb2/cmd',
    stateTopic: 'home/bulb2/state',
    state: {
      isOn: false,
      brightness: 80,
      color: { r: 255, g: 200, b: 100 },
      lastUpdate: new Date().toISOString()
    },
    icon: '💡'
  },
  fan1: {
    type: 'fan',
    cmdTopic: 'home/fan1/cmd',
    stateTopic: 'home/fan1/state',
    state: {
      isOn: false,
      speed: 0,
      oscillating: false,
      timer: null,
      lastUpdate: new Date().toISOString()
    },
    icon: '💨'
  },
  thermostat1: {
    type: 'thermostat',
    cmdTopic: 'home/thermostat1/cmd',
    stateTopic: 'home/thermostat1/state',
    state: {
      isOn: true,
      currentTemp: 22,
      targetTemp: 24,
      mode: 'cool', // heat, cool, auto, off
      fanSpeed: 'auto',
      lastUpdate: new Date().toISOString()
    },
    icon: '🌡️'
  },
  lock1: {
    type: 'lock',
    cmdTopic: 'home/lock1/cmd',
    stateTopic: 'home/lock1/state',
    state: {
      isLocked: true,
      batteryLevel: 85,
      lastAccess: null,
      lastUpdate: new Date().toISOString()
    },
    icon: '🔒'
  }
};

console.log('🤖 AI-Powered IoT Device Simulator Starting...\n');
console.log(`📡 Connecting to broker: ${BROKER_URL}\n`);

const client = mqtt.connect(BROKER_URL, {
  clientId: 'iot_simulator_ai_agent',
  clean: true,
  reconnectPeriod: 1000
});

client.on('connect', () => {
  console.log('✅ Connected to MQTT broker\n');
  console.log('🎯 Simulating the following devices:');
  
  // Subscribe to all command topics
  Object.entries(devices).forEach(([id, device]) => {
    client.subscribe(device.cmdTopic, (err) => {
      if (!err) {
        console.log(`  ${device.icon} ${id} (${device.type})`);
        console.log(`     CMD: ${device.cmdTopic}`);
        console.log(`     STATE: ${device.stateTopic}`);
        
        // Publish initial state
        publishState(id);
      } else {
        console.error(`❌ Failed to subscribe to ${device.cmdTopic}`);
      }
    });
  });
  
  console.log('\n🚀 All devices are online and ready!\n');
});

client.on('message', (topic, message) => {
  try {
    const command = JSON.parse(message.toString());
    const device = findDeviceByTopic(topic);
    
    if (device) {
      const [deviceId, deviceData] = device;
      console.log(`📨 [${deviceId}] Received:`, command);
      handleCommand(deviceId, deviceData, command);
    }
  } catch (error) {
    console.error('❌ Error processing message:', error.message);
  }
});

client.on('error', (error) => {
  console.error('❌ MQTT Error:', error);
});

function findDeviceByTopic(topic) {
  return Object.entries(devices).find(([_, device]) => device.cmdTopic === topic);
}

function handleCommand(deviceId, device, command) {
  let stateChanged = false;
  
  // Universal commands
  if (command.action === 'turnOn') {
    device.state.isOn = true;
    stateChanged = true;
    console.log(`${device.icon} [${deviceId}] Turned ON`);
  } else if (command.action === 'turnOff') {
    device.state.isOn = false;
    stateChanged = true;
    console.log(`${device.icon} [${deviceId}] Turned OFF`);
  } else if (command.action === 'toggle') {
    device.state.isOn = !device.state.isOn;
    stateChanged = true;
    console.log(`${device.icon} [${deviceId}] Toggled ${device.state.isOn ? 'ON' : 'OFF'}`);
  }
  
  // Device-specific commands
  switch (device.type) {
    case 'bulb':
      if (command.brightness !== undefined) {
        device.state.brightness = Math.max(0, Math.min(100, command.brightness));
        stateChanged = true;
        console.log(`  🔆 Brightness: ${device.state.brightness}%`);
      }
      if (command.color) {
        device.state.color = command.color;
        stateChanged = true;
        console.log(`  🎨 Color: RGB(${command.color.r}, ${command.color.g}, ${command.color.b})`);
      }
      break;
      
    case 'fan':
      if (command.speed !== undefined) {
        device.state.speed = Math.max(0, Math.min(5, command.speed));
        device.state.isOn = device.state.speed > 0;
        stateChanged = true;
        console.log(`  💨 Speed: ${device.state.speed}`);
      }
      if (command.oscillating !== undefined) {
        device.state.oscillating = command.oscillating;
        stateChanged = true;
        console.log(`  🔄 Oscillation: ${device.state.oscillating ? 'ON' : 'OFF'}`);
      }
      if (command.timer !== undefined) {
        device.state.timer = command.timer;
        stateChanged = true;
        console.log(`  ⏰ Timer: ${command.timer} min`);
      }
      break;
      
    case 'thermostat':
      if (command.targetTemp !== undefined) {
        device.state.targetTemp = command.targetTemp;
        stateChanged = true;
        console.log(`  🌡️  Target: ${command.targetTemp}°C`);
      }
      if (command.mode) {
        device.state.mode = command.mode;
        stateChanged = true;
        console.log(`  ⚙️  Mode: ${command.mode}`);
      }
      if (command.fanSpeed) {
        device.state.fanSpeed = command.fanSpeed;
        stateChanged = true;
        console.log(`  💨 Fan: ${command.fanSpeed}`);
      }
      break;
      
    case 'lock':
      if (command.action === 'lock') {
        device.state.isLocked = true;
        device.state.lastAccess = new Date().toISOString();
        stateChanged = true;
        console.log(`  🔒 Locked`);
      } else if (command.action === 'unlock') {
        device.state.isLocked = false;
        device.state.lastAccess = new Date().toISOString();
        stateChanged = true;
        console.log(`  🔓 Unlocked`);
      }
      break;
  }
  
  if (stateChanged) {
    device.state.lastUpdate = new Date().toISOString();
    publishState(deviceId);
  }
}

function publishState(deviceId) {
  const device = devices[deviceId];
  
  // Include deviceId in state for Flutter app compatibility
  const stateWithId = {
    deviceId: deviceId,
    ...device.state
  };
  
  const stateMessage = JSON.stringify(stateWithId);
  client.publish(device.stateTopic, stateMessage, { qos: 1, retain: true });
  console.log(`✅ [${deviceId}] State published with deviceId\n`);
}

// Periodic telemetry (simulates real device heartbeats)
setInterval(() => {
  Object.entries(devices).forEach(([deviceId, device]) => {
    // Update timestamps
    device.state.lastUpdate = new Date().toISOString();
    
    // Simulate thermostat temperature changes
    if (device.type === 'thermostat' && device.state.isOn) {
      const diff = device.state.targetTemp - device.state.currentTemp;
      if (Math.abs(diff) > 0.5) {
        device.state.currentTemp += diff > 0 ? 0.5 : -0.5;
        device.state.currentTemp = Math.round(device.state.currentTemp * 10) / 10;
      }
    }
    
    // Simulate battery drain for lock
    if (device.type === 'lock') {
      device.state.batteryLevel = Math.max(0, device.state.batteryLevel - 0.01);
      device.state.batteryLevel = Math.round(device.state.batteryLevel * 100) / 100;
    }
    
    publishState(deviceId);
  });
  
  console.log('💓 Heartbeat telemetry sent for all devices\n');
}, TELEMETRY_INTERVAL);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down IoT simulator...');
  client.end();
  process.exit(0);
});
