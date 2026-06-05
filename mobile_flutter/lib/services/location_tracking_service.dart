import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config.dart';
import '../models/delivery_models.dart';
import 'shipper_api.dart';

class TrackingState {
  final bool isTracking;
  final ShipperStatus status;
  final Position? lastPosition;
  final String? lastMessage;
  final DateTime? lastSentAt;

  TrackingState({
    required this.isTracking,
    required this.status,
    this.lastPosition,
    this.lastMessage,
    this.lastSentAt,
  });

  TrackingState copyWith({
    bool? isTracking,
    ShipperStatus? status,
    Position? lastPosition,
    String? lastMessage,
    DateTime? lastSentAt,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      status: status ?? this.status,
      lastPosition: lastPosition ?? this.lastPosition,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSentAt: lastSentAt ?? this.lastSentAt,
    );
  }
}

class LocationTrackingService {
  final ShipperApi api;
  final _controller = StreamController<TrackingState>.broadcast();

  Timer? _timer;
  int? _shipperId;
  TrackingState _state = TrackingState(
    isTracking: false,
    status: ShipperStatus.offline,
  );

  LocationTrackingService(this.api);

  Stream<TrackingState> get stream => _controller.stream;
  TrackingState get state => _state;

  void bindShipper(int shipperId, {ShipperStatus? status}) {
    _shipperId = shipperId;
    if (status != null) {
      _state = _state.copyWith(status: status, lastMessage: 'Selected shipper #$shipperId');
    } else {
      _state = _state.copyWith(lastMessage: 'Selected shipper #$shipperId');
    }
    _emit();
  }

  Future<void> start(int shipperId, {ShipperStatus status = ShipperStatus.available}) async {
    _shipperId = shipperId;
    await _ensurePermission();
    await setStatus(status);
    _state = _state.copyWith(isTracking: true, lastMessage: 'Live tracking started');
    _emit();
    await sendOnce();
    _schedule();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_shipperId != null) {
      await setStatus(ShipperStatus.offline);
    }
    _state = _state.copyWith(isTracking: false, lastMessage: 'Tracking stopped');
    _emit();
  }

  Future<void> setStatus(ShipperStatus status) async {
    final shipperId = _shipperId;
    if (shipperId == null) {
      throw Exception('Please select a shipper first.');
    }
    await api.updateStatus(shipperId, status);
    _state = _state.copyWith(status: status, lastMessage: 'Status changed to ${statusToApi(status)}');
    _emit();
    if (_state.isTracking) _schedule();
  }

  Future<void> sendOnce() async {
    final shipperId = _shipperId;
    if (shipperId == null) {
      throw Exception('Please select a shipper first.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 15),
    );

    await api.sendLocation(
      shipperId: shipperId,
      lat: position.latitude,
      lng: position.longitude,
      speed: position.speed >= 0 ? position.speed : null,
      heading: position.heading >= 0 ? position.heading : null,
    );

    _state = _state.copyWith(
      lastPosition: position,
      lastSentAt: DateTime.now(),
      lastMessage:
          'GPS sent: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
    );
    _emit();
  }

  void _schedule() {
    _timer?.cancel();
    final interval = _state.status == ShipperStatus.busy
        ? AppConfig.busyInterval
        : AppConfig.availableInterval;
    _timer = Timer.periodic(interval, (_) async {
      try {
        await sendOnce();
      } catch (e) {
        _state = _state.copyWith(lastMessage: 'GPS error: $e');
        _emit();
      }
    });
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS/location services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied. Enable it in system settings.');
    }
  }

  void _emit() => _controller.add(_state);

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
