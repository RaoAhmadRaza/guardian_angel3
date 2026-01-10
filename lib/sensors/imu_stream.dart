import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// IMU Stream - Collects accelerometer and gyroscope data
/// 
/// Combines both sensor streams into a single 6-channel output:
/// [ax, ay, az, gx, gy, gz] in SI units (m/s², rad/s)
class ImuStream {
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Buffers to hold the latest readings
  AccelerometerEvent? _lastAccel;
  GyroscopeEvent? _lastGyro;

  // Stream controller to broadcast combined sensor data
  // Emits a list: [ax, ay, az, gx, gy, gz]
  final _controller = StreamController<List<double>>.broadcast();

  Stream<List<double>> get dataStream => _controller.stream;
  
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    
    _accelSubscription = accelerometerEvents.listen((event) {
      _lastAccel = event;
      _emitIfReady();
    });

    _gyroSubscription = gyroscopeEvents.listen((event) {
      _lastGyro = event;
      _emitIfReady();
    });
  }

  void stop() {
    _isRunning = false;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _lastAccel = null;
    _lastGyro = null;
  }

  void _emitIfReady() {
    if (_lastAccel != null && _lastGyro != null) {
      _controller.add([
        _lastAccel!.x,
        _lastAccel!.y,
        _lastAccel!.z,
        _lastGyro!.x,
        _lastGyro!.y,
        _lastGyro!.z,
      ]);
      
      // Optional: Clear buffers if you only want paired readings 
      // (though sensors usually run at different rates, so holding last value is common)
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
