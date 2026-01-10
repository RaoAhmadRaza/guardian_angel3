import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

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

  void start() {
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
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
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
