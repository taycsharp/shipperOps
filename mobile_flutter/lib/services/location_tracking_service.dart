import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/delivery_models.dart';
import 'shipper_api.dart';

enum GpsStatus {
  stopped,
  gpsOff,
  permissionRequired,
  permissionPermanentlyDenied,
  trackingLive,
  sendingLocation,
  lastUpdateFailed,
  offlineWaitingNetwork,
}

class TrackingState {
  final bool isTracking;
  final ShipperStatus status;
  final Position? lastPosition;
  final String? lastMessage;
  final DateTime? lastSentAt;
  final GpsStatus gpsStatus;
  final int pendingRetryCount;
  final bool isSending;
  final DateTime? lastFailedAt;
  final String connectionStatus;

  TrackingState({
    required this.isTracking,
    required this.status,
    this.lastPosition,
    this.lastMessage,
    this.lastSentAt,
    this.gpsStatus = GpsStatus.stopped,
    this.pendingRetryCount = 0,
    this.isSending = false,
    this.lastFailedAt,
    this.connectionStatus = 'Ready',
  });

  TrackingState copyWith({
    bool? isTracking,
    ShipperStatus? status,
    Position? lastPosition,
    String? lastMessage,
    DateTime? lastSentAt,
    GpsStatus? gpsStatus,
    int? pendingRetryCount,
    bool? isSending,
    DateTime? lastFailedAt,
    String? connectionStatus,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      status: status ?? this.status,
      lastPosition: lastPosition ?? this.lastPosition,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSentAt: lastSentAt ?? this.lastSentAt,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      pendingRetryCount: pendingRetryCount ?? this.pendingRetryCount,
      isSending: isSending ?? this.isSending,
      lastFailedAt: lastFailedAt ?? this.lastFailedAt,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

class PendingLocation {
  final int shipperId;
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final double accuracy;
  final DateTime capturedAt;

  const PendingLocation({
    required this.shipperId,
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.capturedAt,
    this.speed,
    this.heading,
  });

  factory PendingLocation.fromPosition(int shipperId, Position position) {
    return PendingLocation(
      shipperId: shipperId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
      speed: position.speed >= 0 ? position.speed : null,
      heading: position.heading >= 0 ? position.heading : null,
    );
  }

  factory PendingLocation.fromJson(Map<String, dynamic> json) {
    return PendingLocation(
      shipperId: (json['shipper_id'] as num).toInt(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracy: (json['accuracy'] as num? ?? 0).toDouble(),
      capturedAt: DateTime.tryParse(json['captured_at']?.toString() ?? '') ?? DateTime.now(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'shipper_id': shipperId,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'captured_at': capturedAt.toIso8601String(),
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
      };
}

class LocationTrackingService {
  static const _pendingLocationKey = 'gps_pending_locations';
  static const _retryCooldown = Duration(seconds: 30);

  final ShipperApi api;
  final _controller = StreamController<TrackingState>.broadcast();

  Timer? _timer;
  int? _shipperId;
  bool _sendInFlight = false;
  DateTime? _nextRetryAfter;
  List<PendingLocation> _pendingLocations = [];
  TrackingState _state = TrackingState(
    isTracking: false,
    status: ShipperStatus.offline,
    connectionStatus: 'Offline',
  );

  LocationTrackingService(this.api) {
    unawaited(_loadPendingLocations());
  }

  Stream<TrackingState> get stream => _controller.stream;
  TrackingState get state => _state;

  void bindShipper(int shipperId, {ShipperStatus? status}) {
    _shipperId = shipperId;
    _state = _state.copyWith(
      status: status ?? _state.status,
      pendingRetryCount: _pendingCountFor(shipperId),
      lastMessage: 'Shipper profile ready',
      connectionStatus: _pendingCountFor(shipperId) > 0 ? 'Waiting to retry' : 'Ready',
    );
    _emit();
    if ((status ?? _state.status) != ShipperStatus.offline && _pendingCountFor(shipperId) > 0) {
      _schedule();
    }
  }

  Future<void> start(int shipperId, {ShipperStatus status = ShipperStatus.available}) async {
    if (_state.isTracking && _shipperId == shipperId) return;
    _shipperId = shipperId;
    await _loadPendingLocations();
    await _ensurePermission();
    await setStatus(status);
    _state = _state.copyWith(
      isTracking: true,
      gpsStatus: GpsStatus.trackingLive,
      lastMessage: 'Live GPS is on. Dispatch can see your latest location.',
      connectionStatus: 'Online',
      pendingRetryCount: _pendingCountFor(shipperId),
    );
    _emit();
    _schedule();
    await sendOnce();
  }

  Future<void> stop({bool markOffline = true}) async {
    _cancelTimer();
    if (markOffline && _shipperId != null) {
      await setStatus(ShipperStatus.offline);
    }
    _state = _state.copyWith(
      isTracking: false,
      gpsStatus: GpsStatus.stopped,
      lastMessage: 'Tracking stopped.',
      connectionStatus: 'Offline',
      isSending: false,
    );
    _emit();
  }

  Future<void> setStatus(ShipperStatus status) async {
    final shipperId = _shipperId;
    if (shipperId == null) {
      throw Exception('No authenticated shipper profile is linked to this login.');
    }
    await api.updateStatus(shipperId, status);
    if (status == ShipperStatus.offline) {
      _cancelTimer();
      _state = _state.copyWith(
        status: status,
        isTracking: false,
        gpsStatus: GpsStatus.stopped,
        lastMessage: 'You are offline. GPS tracking is paused.',
        connectionStatus: 'Offline',
      );
    } else {
      _state = _state.copyWith(
        status: status,
        gpsStatus: _state.isTracking ? GpsStatus.trackingLive : _state.gpsStatus,
        lastMessage: 'Status changed to ${statusToApi(status)}.',
        connectionStatus: _state.pendingRetryCount > 0 ? 'Waiting to retry' : 'Online',
      );
    }
    _emit();
    if (_state.isTracking) _schedule();
  }

  Future<void> sendOnce() async {
    final shipperId = _shipperId;
    if (shipperId == null) {
      throw Exception('No authenticated shipper profile is linked to this login.');
    }
    if (_sendInFlight) return;
    if (_state.status == ShipperStatus.offline) {
      _state = _state.copyWith(
        isTracking: false,
        gpsStatus: GpsStatus.stopped,
        lastMessage: 'You are offline. Go Available to restart GPS tracking.',
        connectionStatus: 'Offline',
      );
      _emit();
      return;
    }

    _sendInFlight = true;
    _state = _state.copyWith(
      isSending: true,
      gpsStatus: GpsStatus.sendingLocation,
      lastMessage: 'Sending location update…',
      connectionStatus: 'Sending',
    );
    _emit();

    try {
      await _flushPendingLocations(force: false);
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
      final pending = PendingLocation.fromPosition(shipperId, position);
      await _sendPendingLocation(pending);
      _state = _state.copyWith(
        lastPosition: position,
        lastSentAt: DateTime.now(),
        lastMessage: 'Location updated successfully.',
        gpsStatus: _state.isTracking ? GpsStatus.trackingLive : GpsStatus.stopped,
        pendingRetryCount: _pendingCountFor(shipperId),
        isSending: false,
        connectionStatus: _pendingCountFor(shipperId) > 0 ? 'Retry pending' : 'Online',
      );
      _nextRetryAfter = null;
      _emit();
    } catch (e) {
      debugPrint('GPS send failed: $e');
      if (e is LocationServiceDisabledException) {
        _state = _state.copyWith(
          gpsStatus: GpsStatus.gpsOff,
          lastMessage: 'GPS is off. Turn on Location Services to continue tracking.',
          isSending: false,
          connectionStatus: 'GPS off',
        );
      } else {
        final now = DateTime.now();
        _nextRetryAfter = now.add(_retryCooldown);
        _state = _state.copyWith(
          gpsStatus: _pendingCountFor(shipperId) > 0 ? GpsStatus.offlineWaitingNetwork : GpsStatus.lastUpdateFailed,
          lastFailedAt: now,
          lastMessage: _pendingCountFor(shipperId) > 0
              ? 'No connection. Your latest location is saved and will retry automatically.'
              : 'Last GPS update failed. We will try again automatically.',
          pendingRetryCount: _pendingCountFor(shipperId),
          isSending: false,
          connectionStatus: _pendingCountFor(shipperId) > 0 ? 'Waiting for network' : 'Update failed',
        );
      }
      _emit();
    } finally {
      _sendInFlight = false;
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> retryPendingLocations() async {
    final shipperId = _shipperId;
    if (shipperId == null || _pendingCountFor(shipperId) == 0 || _sendInFlight) return;
    _sendInFlight = true;
    _state = _state.copyWith(
      isSending: true,
      gpsStatus: GpsStatus.sendingLocation,
      lastMessage: 'Retrying saved location update…',
      connectionStatus: 'Retrying',
    );
    _emit();
    try {
      await _flushPendingLocations(force: false);
      _nextRetryAfter = null;
      final pendingCount = _pendingCountFor(shipperId);
      _state = _state.copyWith(
        isSending: false,
        gpsStatus: _state.isTracking ? GpsStatus.trackingLive : GpsStatus.stopped,
        pendingRetryCount: pendingCount,
        lastMessage: pendingCount == 0
            ? 'Saved location update sent successfully.'
            : 'Some saved locations are still waiting to retry.',
        connectionStatus: pendingCount == 0 ? 'Online' : 'Retry pending',
      );
      if (!_state.isTracking && pendingCount == 0) _cancelTimer();
      _emit();
    } catch (e) {
      debugPrint('Pending GPS retry failed: $e');
      final now = DateTime.now();
      _nextRetryAfter = now.add(_retryCooldown);
      _state = _state.copyWith(
        isSending: false,
        gpsStatus: GpsStatus.offlineWaitingNetwork,
        lastFailedAt: now,
        pendingRetryCount: _pendingCountFor(shipperId),
        lastMessage: 'No connection. Your latest location is saved and will retry automatically.',
        connectionStatus: 'Waiting for network',
      );
      _emit();
    } finally {
      _sendInFlight = false;
    }
  }

  void _schedule() {
    _timer?.cancel();
    final shipperId = _shipperId;
    if (shipperId == null || _state.status == ShipperStatus.offline) return;
    if (!_state.isTracking && _pendingCountFor(shipperId) == 0) return;
    final interval = _state.status == ShipperStatus.busy
        ? AppConfig.busyInterval
        : AppConfig.availableInterval;
    _timer = Timer.periodic(interval, (_) async {
      if (_sendInFlight) return;
      final retryAfter = _nextRetryAfter;
      if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
      if (_state.isTracking) {
        await sendOnce();
      } else {
        await retryPendingLocations();
      }
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _state = _state.copyWith(
        gpsStatus: GpsStatus.gpsOff,
        lastMessage: 'GPS is off. Turn on Location Services to share delivery progress.',
        connectionStatus: 'GPS off',
      );
      _emit();
      throw Exception('GPS is off. Turn on Location Services to share delivery progress.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      _state = _state.copyWith(
        gpsStatus: GpsStatus.permissionRequired,
        lastMessage: 'Location permission is needed so dispatch can track your delivery route.',
        connectionStatus: 'Permission needed',
      );
      _emit();
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _state = _state.copyWith(
        gpsStatus: GpsStatus.permissionRequired,
        lastMessage: 'Allow location permission to start live GPS tracking.',
        connectionStatus: 'Permission needed',
      );
      _emit();
      throw Exception('Allow location permission to start live GPS tracking.');
    }
    if (permission == LocationPermission.deniedForever) {
      _state = _state.copyWith(
        gpsStatus: GpsStatus.permissionPermanentlyDenied,
        lastMessage: 'Location permission is off. Open app settings and allow location access.',
        connectionStatus: 'Settings needed',
      );
      _emit();
      throw Exception('Location permission is off. Open app settings and allow location access.');
    }
  }

  Future<void> _flushPendingLocations({required bool force}) async {
    final shipperId = _shipperId;
    if (shipperId == null) return;
    final retryAfter = _nextRetryAfter;
    if (!force && retryAfter != null && DateTime.now().isBefore(retryAfter)) return;

    final queue = _pendingLocations.where((location) => location.shipperId == shipperId).toList();
    for (final location in queue) {
      await _sendPendingLocation(location);
      _pendingLocations.remove(location);
      await _savePendingLocations();
      _state = _state.copyWith(pendingRetryCount: _pendingCountFor(shipperId));
      _emit();
    }
  }

  Future<void> _sendPendingLocation(PendingLocation location) async {
    try {
      await api.sendLocation(
        shipperId: location.shipperId,
        lat: location.lat,
        lng: location.lng,
        speed: location.speed,
        heading: location.heading,
      );
    } catch (_) {
      await _enqueuePendingLocation(location);
      rethrow;
    }
  }

  Future<void> _enqueuePendingLocation(PendingLocation location) async {
    _pendingLocations.removeWhere(
      (item) => item.shipperId == location.shipperId && item.capturedAt == location.capturedAt,
    );
    _pendingLocations.add(location);
    if (_pendingLocations.length > AppConfig.gpsPendingQueueLimit) {
      _pendingLocations = _pendingLocations.sublist(_pendingLocations.length - AppConfig.gpsPendingQueueLimit);
    }
    await _savePendingLocations();
    _state = _state.copyWith(pendingRetryCount: _pendingCountFor(location.shipperId));
  }

  Future<void> _loadPendingLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingLocationKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _pendingLocations = decoded
          .whereType<Map>()
          .map((item) => PendingLocation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final shipperId = _shipperId;
      if (shipperId != null) {
        _state = _state.copyWith(pendingRetryCount: _pendingCountFor(shipperId));
        _emit();
      }
    } catch (e) {
      debugPrint('Unable to restore pending GPS queue: $e');
      await prefs.remove(_pendingLocationKey);
      _pendingLocations = [];
    }
  }

  Future<void> _savePendingLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingLocationKey,
      jsonEncode(_pendingLocations.map((location) => location.toJson()).toList()),
    );
  }

  int _pendingCountFor(int shipperId) => _pendingLocations.where((location) => location.shipperId == shipperId).length;

  void _emit() {
    if (!_controller.isClosed) _controller.add(_state);
  }

  void dispose() {
    _cancelTimer();
    _controller.close();
  }
}
