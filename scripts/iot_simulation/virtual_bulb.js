#!/usr/bin/env node

/**
 * Virtual Smart Bulb - Simulates a real IoT bulb device
 * 
 * This script simulates a smart bulb that:
 * - Listens for commands on home/bulb1/cmd
 * - Publishes state updates to home/bulb1/state
 * - Maintains internal state (on/off, brightness)
 * - Responds realistically to commands
 */

const mqtt = require('mqtt');

// Configuration
const BROKER_URL = 'mqtt://localhost:1883';
const CMD_TOPIC = 'home/bulb1/cmd';
const STATE_TOPIC = 'home/bulb1/state';
const TELEMETRY_INTERVAL = 5000; // 5 seconds

// Device state
let deviceState = {
  isOn: false,
  brightness: 60,
  color: { r: 255, g: 255, b: 255 },
  lastUpdate: new Date().toISOString()
};

console.log('🔌 Virtual Smart Bulb Starting...');
console.log(`📡 Connecting to broker: ${BROKER_URL}`);

// Connect to MQTT broker
const client = mqtt.connect(BROKER_URL, {
  clientId: 'virtual_bulb_1',
  clean: true,
  reconnectPeriod: 1000
});

client.on('connect', () => {
  console.log('✅ Connected to MQTT broker');
  
  // Subscribe to command topic
  client.subscribe(CMD_TOPIC, (err) => {
    if (!err) {
      console.log(`📥 Subscribed to: ${CMD_TOPIC}`);
      console.log(`📤 Publishing state to: ${STATE_TOPIC}`);
      console.log('🎯 Bulb is ready to receive commands!\n');
      
      // Publish initial state
      publishState();
    } else {
      console.error('❌ Subscription error:', err);
    }
  });
});

client.on('message', (topic, message) => {
  try {
    const command = JSON.parse(message.toString());
    console.log(`📨 Received command:`, command);
    
    handleCommand(command);
  } catch (error) {
    console.error('❌ Error parsing command:', error);
  }
});

client.on('error', (error) => {
  console.error('❌ MQTT Error:', error);
});

client.on('close', () => {
  console.log('📡 Disconnected from broker');
});

function handleCommand(command) {
  let stateChanged = false;
  
  // Handle different command types
  if (command.action === 'turnOn') {
    deviceState.isOn = true;
    stateChanged = true;
    console.log('💡 Bulb turned ON');
  } 
  else if (command.action === 'turnOff') {
    deviceState.isOn = false;
    stateChanged = true;
    console.log('💡 Bulb turned OFF');
  }
  else if (command.action === 'toggle') {
    deviceState.isOn = !deviceState.isOn;
    stateChanged = true;
    console.log(`💡 Bulb toggled ${deviceState.isOn ? 'ON' : 'OFF'}`);
  }
  
  // Handle brightness changes
  if (command.brightness !== undefined) {
    deviceState.brightness = Math.max(0, Math.min(100, command.brightness));
    stateChanged = true;
    console.log(`🔆 Brightness set to: ${deviceState.brightness}%`);
  }
  
  // Handle color changes
  if (command.color) {
    deviceState.color = command.color;
    stateChanged = true;
    console.log(`🎨 Color changed to: RGB(${command.color.r}, ${command.color.g}, ${command.color.b})`);
  }
  
  // Publish updated state if something changed
  if (stateChanged) {
    deviceState.lastUpdate = new Date().toISOString();
    publishState();
  }
}

function publishState() {
  // Include deviceId for Flutter app compatibility
  const stateWithId = {
    deviceId: 'bulb1',
    ...deviceState
  };
  
  const stateMessage = JSON.stringify(stateWithId);
  client.publish(STATE_TOPIC, stateMessage, { qos: 1, retain: true });
  console.log(`✅ State published:`, stateWithId);
  console.log('---');
}

// Periodic telemetry updates (heartbeat)
setInterval(() => {
  deviceState.lastUpdate = new Date().toISOString();
  publishState();
  console.log('💓 Heartbeat telemetry sent');
}, TELEMETRY_INTERVAL);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down virtual bulb...');
  client.end();
  process.exit(0);
});

console.log('🚀 Virtual Bulb is running. Press Ctrl+C to stop.\n');
