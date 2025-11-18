#!/usr/bin/env node

/**
 * Virtual Smart Fan - Simulates a real IoT fan device
 * 
 * This script simulates a smart fan that:
 * - Listens for commands on home/fan1/cmd
 * - Publishes state updates to home/fan1/state
 * - Maintains internal state (speed, oscillation)
 * - Responds realistically to commands
 */

const mqtt = require('mqtt');

// Configuration
const BROKER_URL = 'mqtt://localhost:1883';
const CMD_TOPIC = 'home/fan1/cmd';
const STATE_TOPIC = 'home/fan1/state';
const TELEMETRY_INTERVAL = 5000; // 5 seconds

// Device state
let deviceState = {
  isOn: false,
  speed: 0, // 0-5 (0 = off, 1-5 = speed levels)
  oscillating: false,
  timer: null,
  lastUpdate: new Date().toISOString()
};

console.log('💨 Virtual Smart Fan Starting...');
console.log(`📡 Connecting to broker: ${BROKER_URL}`);

// Connect to MQTT broker
const client = mqtt.connect(BROKER_URL, {
  clientId: 'virtual_fan_1',
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
      console.log('🎯 Fan is ready to receive commands!\n');
      
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
  
  // Handle speed changes
  if (command.speed !== undefined) {
    deviceState.speed = Math.max(0, Math.min(5, command.speed));
    deviceState.isOn = deviceState.speed > 0;
    stateChanged = true;
    
    if (deviceState.speed === 0) {
      console.log('💨 Fan turned OFF (speed 0)');
    } else {
      console.log(`💨 Fan speed set to: ${deviceState.speed}`);
    }
  }
  
  // Handle on/off
  if (command.action === 'turnOn') {
    deviceState.isOn = true;
    if (deviceState.speed === 0) {
      deviceState.speed = 1; // Default to speed 1
    }
    stateChanged = true;
    console.log('💨 Fan turned ON');
  } 
  else if (command.action === 'turnOff') {
    deviceState.isOn = false;
    deviceState.speed = 0;
    stateChanged = true;
    console.log('💨 Fan turned OFF');
  }
  
  // Handle oscillation
  if (command.oscillating !== undefined) {
    deviceState.oscillating = command.oscillating;
    stateChanged = true;
    console.log(`🔄 Oscillation ${deviceState.oscillating ? 'enabled' : 'disabled'}`);
  }
  
  // Handle timer
  if (command.timer !== undefined) {
    deviceState.timer = command.timer;
    stateChanged = true;
    console.log(`⏰ Timer set to: ${command.timer} minutes`);
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
    deviceId: 'fan1',
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
  console.log('\n🛑 Shutting down virtual fan...');
  client.end();
  process.exit(0);
});

console.log('🚀 Virtual Fan is running. Press Ctrl+C to stop.\n');
