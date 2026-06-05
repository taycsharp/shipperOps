import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../models/delivery_models.dart';
import '../services/api_client.dart';
import '../services/location_tracking_service.dart';
import '../services/shipper_api.dart';
import '../utils/formatters.dart';
import '../widgets/order_card.dart';
import '../widgets/status_pill.dart';

class ShipperHomeScreen extends StatefulWidget {
  final LanguageController languageController;

  const ShipperHomeScreen({super.key, required this.languageController});

  @override
  State<ShipperHomeScreen> createState() => _ShipperHomeScreenState();
}

class _ShipperHomeScreenState extends State<ShipperHomeScreen> {
  static const _tokenKey = 'auth_token';

  late final ApiClient _client;
  late final ShipperApi _api;
  late final LocationTrackingService _tracking;

  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'shipper1@example.com');
  final _passwordController = TextEditingController(text: 'shipper123');
  final _picker = ImagePicker();

  AppUser? _currentUser;
  List<DeliveryOrder> _orders = [];
  ShipperProfile? _selectedShipper;
  TrackingState _state = TrackingState(isTracking: false, status: ShipperStatus.offline);
  bool _authChecked = false;
  bool _loading = true;
  bool _loadingOrders = false;
  bool _busyAction = false;
  String? _error;

  AppLocalizations get l10n => widget.languageController.strings;

  int? get _shipperId => _selectedShipper?.id;
  bool get _isLoggedIn => _client.token != null && _currentUser != null;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = ShipperApi(_client);
    _tracking = LocationTrackingService(_api);
    _tracking.stream.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null || token.isEmpty) {
        setState(() {
          _authChecked = true;
          _loading = false;
        });
        return;
      }
      _client.token = token;
      final user = await _api.me();
      setState(() => _currentUser = user);
      await _bootstrapAfterAuth();
    } catch (e) {
      await _clearSavedSession();
      _setErrorFromException(e, fallback: l10n.t('pleaseLoginAgain'));
    } finally {
      if (mounted) {
        setState(() {
          _authChecked = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    await _run(() async {
      final session = await _api.login(_emailController.text, _passwordController.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, session.accessToken);
      final user = await _api.me();
      setState(() => _currentUser = user);
      await _bootstrapAfterAuth();
    });
  }

  Future<void> _logout() async {
    await _tracking.stop().catchError((_) {});
    await _clearSavedSession();
    setState(() {
      _currentUser = null;
      _selectedShipper = null;
      _orders = [];
      _state = TrackingState(isTracking: false, status: ShipperStatus.offline);
      _error = null;
    });
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _client.token = null;
  }

  Future<void> _bootstrapAfterAuth() async {
    final user = _currentUser;
    if (user == null) return;
    if (user.role != UserRole.shipper) {
      await _tracking.stop().catchError((_) {});
      setState(() {
        _selectedShipper = null;
        _orders = [];
        _error =
            l10n.t('shipperOnly');
      });
      return;
    }

    final selected = await _api.getAuthenticatedShipperProfile(user.id);
    setState(() {
      _selectedShipper = selected;
      _orders = [];
      _error = selected == null
          ? l10n.noShipperProfileLinked(user.email)
          : null;
    });
    if (selected != null) {
      _tracking.bindShipper(selected.id, status: selected.status);
      await _loadOrders();
    }
  }

  Future<void> _bootstrap() async {
    if (!_isLoggedIn) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.me();
      setState(() => _currentUser = user);
      await _bootstrapAfterAuth();
    } catch (e) {
      _setErrorFromException(e, fallback: l10n.t('serverUnavailable'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrders() async {
    final shipperId = _shipperId;
    if (shipperId == null) return;
    setState(() {
      _loadingOrders = true;
      _error = null;
    });
    try {
      final orders = await _api.getAssignedOrders(shipperId);
      setState(() => _orders = orders.where((order) => order.shipperId == shipperId).toList());
    } catch (e) {
      _setErrorFromException(e, fallback: l10n.t('serverUnavailable'));
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? fallbackError}) async {
    if (_busyAction) return;
    try {
      setState(() {
        _busyAction = true;
        _error = null;
      });
      await action();
    } catch (e) {
      _setErrorFromException(e, fallback: fallbackError ?? l10n.t('serverUnavailable'));
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  void _setErrorFromException(Object error, {required String fallback}) {
    debugPrint('Shipper mobile action failed: $error');
    if (!mounted) return;
    setState(() => _error = _friendlyErrorMessage(error, fallback: fallback));
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException && error.statusCode != null) {
      if (error.statusCode! >= 500 || error.statusCode == 403) {
        return l10n.t('serverUnavailable');
      }
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('location services') || raw.contains('location permission')) {
      return l10n.serviceMessage(error.toString().replaceFirst('Exception: ', ''));
    }
    if (raw.contains('socket') || raw.contains('network') || raw.contains('internet') || raw.contains('timed out')) {
      return fallback.contains('GPS') ? l10n.t('unableSendGps') : l10n.t('serverUnavailable');
    }
    if (raw.contains('cloudflare') || raw.contains('<html') || raw.contains('server error') || raw.contains('internal server') || raw.contains('bad gateway') || raw.contains('service unavailable')) {
      return l10n.t('serverUnavailable');
    }
    if (fallback.contains('Order')) return fallback;
    if (fallback.contains('GPS')) return fallback;
    return fallback;
  }

  String _shipperStatusLabel(ShipperStatus status) {
    switch (status) {
      case ShipperStatus.available:
        return l10n.t('available');
      case ShipperStatus.busy:
        return l10n.t('busy');
      case ShipperStatus.suspended:
        return l10n.t('suspended');
      case ShipperStatus.offline:
        return l10n.t('offline');
    }
  }

  Color _shipperStatusColor(ShipperStatus status) {
    switch (status) {
      case ShipperStatus.available:
        return Colors.green;
      case ShipperStatus.busy:
        return Colors.orange;
      case ShipperStatus.suspended:
        return Colors.red;
      case ShipperStatus.offline:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(ShipperStatus status) async {
    await _tracking.setStatus(status);
    final shipperId = _shipperId;
    if (shipperId != null) {
      final updated = await _api.getShipper(shipperId);
      setState(() => _selectedShipper = updated);
    }
  }

  Future<void> _startLiveGps() async {
    final shipperId = _shipperId;
    if (shipperId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('startLiveGpsQuestion')),
        content: Text(l10n.t('startLiveGpsExplanation')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.t('notNow'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.t('startGps'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _tracking.start(shipperId),
      fallbackError: l10n.t('unableStartGps'),
    );
  }

  Future<void> _openAppLocationSettings() async {
    await _tracking.openAppSettings();
  }

  Future<void> _openDeviceLocationSettings() async {
    await _tracking.openLocationSettings();
  }

  static const Map<String, List<String>> _validOrderTransitions = {
    'ASSIGNED': ['PICKED_UP'],
    'PICKED_UP': ['IN_TRANSIT'],
    'IN_TRANSIT': ['DELIVERED', 'FAILED', 'RETURNED'],
  };

  bool _canTransition(DeliveryOrder order, String nextStatus) {
    return _validOrderTransitions[order.status.toUpperCase()]?.contains(nextStatus) ?? false;
  }

  String? _orderActionError(DeliveryOrder order, String nextStatus) {
    final shipperId = _shipperId;
    if (shipperId == null) return l10n.t('noShipperAction');
    if (order.shipperId != shipperId) return l10n.t('orderNotAssigned');
    if (!_canTransition(order, nextStatus)) {
      return l10n.cannotChangeOrder(order.orderCode, l10n.displayStatus(order.status), l10n.displayStatus(nextStatus));
    }
    return null;
  }

  void _showActionError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<XFile?> _pickProofImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.t('takePhoto')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.t('chooseFromGallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return _picker.pickImage(source: source, imageQuality: 78, maxWidth: 1600);
  }

  Future<void> _updateOrderStatusDialog(DeliveryOrder order, String status) async {
    final actionError = _orderActionError(order, status);
    if (actionError != null) {
      _showActionError(actionError);
      return;
    }

    if (status == 'PICKED_UP' || status == 'IN_TRANSIT') {
      await _submitOrderStatus(order, status);
      return;
    }
    if (status == 'DELIVERED') {
      await _showDeliveredDialog(order);
      return;
    }
    if (status == 'FAILED' || status == 'RETURNED') {
      await _showExceptionDialog(order, status);
    }
  }

  Future<void> _showDeliveredDialog(DeliveryOrder order) async {
    final receiverController = TextEditingController(text: order.receiverName);
    final noteController = TextEditingController(text: order.deliveryNote);
    final codController = TextEditingController(text: order.codAmount > 0 ? order.codAmount.toStringAsFixed(0) : '');
    String paymentMethod = order.paymentMethod.isNotEmpty ? order.paymentMethod : 'CASH';
    bool codConfirmed = order.codAmount <= 0 || order.codCollected;
    XFile? proofImage;
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.t('completeDelivery')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: receiverController,
                  decoration: InputDecoration(labelText: l10n.t('receiverNameRequiredLabel'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.t('deliveryNoteRequiredLabel'), border: const OutlineInputBorder()),
                ),
                if (order.codAmount > 0) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: codController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.codAmountLabel(money(order.codAmount)), border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: InputDecoration(labelText: l10n.t('paymentMethod'), border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'CASH', child: Text(l10n.t('cash'))),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text(l10n.t('bankTransfer'))),
                      DropdownMenuItem(value: 'WALLET', child: Text(l10n.t('wallet'))),
                      DropdownMenuItem(value: 'OTHER', child: Text(l10n.t('other'))),
                    ],
                    onChanged: (value) => setDialogState(() => paymentMethod = value ?? 'CASH'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: codConfirmed,
                    title: Text(l10n.t('confirmCodCollected')),
                    onChanged: (value) => setDialogState(() => codConfirmed = value == true),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickProofImage();
                    if (picked != null) setDialogState(() => proofImage = picked);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(order.proofImageUrl.isEmpty && proofImage == null
                      ? l10n.t('uploadProofPhotoRequired')
                      : proofImage != null
                          ? l10n.t('proofSelected')
                          : l10n.t('replaceProofPhoto')),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.t('cancel'))),
            FilledButton(
              onPressed: () {
                final codAmount = double.tryParse(codController.text.trim());
                final missingProof = order.proofImageUrl.isEmpty && proofImage == null;
                String? validation;
                if (receiverController.text.trim().isEmpty) {
                  validation = l10n.t('receiverNameRequired');
                } else if (noteController.text.trim().isEmpty) {
                  validation = l10n.t('deliveryNoteRequired');
                } else if (order.codAmount > 0 && !codConfirmed) {
                  validation = l10n.t('confirmCodBeforeComplete');
                } else if (order.codAmount > 0 && (codAmount == null || codAmount <= 0)) {
                  validation = l10n.t('enterCodCollected');
                } else if (missingProof) {
                  validation = l10n.t('proofPhotoRequired');
                }
                if (validation != null) {
                  setDialogState(() => dialogError = validation);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(l10n.t('markDelivered')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await _submitOrderStatus(
      order,
      'DELIVERED',
      note: noteController.text,
      receiverName: receiverController.text,
      codCollected: order.codAmount > 0 ? true : null,
      codCollectedAmount: order.codAmount > 0 ? double.tryParse(codController.text) : null,
      paymentMethod: order.codAmount > 0 ? paymentMethod : null,
      proofFile: proofImage == null ? null : File(proofImage!.path),
    );
  }

  Future<void> _showExceptionDialog(DeliveryOrder order, String status) async {
    final noteController = TextEditingController();
    String reason = status == 'FAILED' ? 'CUSTOMER_NOT_AVAILABLE' : 'REFUSED_DELIVERY';
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(status == 'FAILED' ? l10n.t('markFailed') : l10n.t('markReturned')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: InputDecoration(labelText: status == 'FAILED' ? l10n.t('failedReasonRequired') : l10n.t('returnReasonRequired'), border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'CUSTOMER_NOT_AVAILABLE', child: Text(l10n.t('customerNotAvailable'))),
                    DropdownMenuItem(value: 'WRONG_ADDRESS', child: Text(l10n.t('wrongAddress'))),
                    DropdownMenuItem(value: 'REFUSED_DELIVERY', child: Text(l10n.t('refusedDelivery'))),
                    DropdownMenuItem(value: 'DAMAGED_GOODS', child: Text(l10n.t('damagedGoods'))),
                    DropdownMenuItem(value: 'PAYMENT_ISSUE', child: Text(l10n.t('paymentIssue'))),
                    DropdownMenuItem(value: 'OTHER', child: Text(l10n.t('other'))),
                  ],
                  onChanged: (value) => setDialogState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: status == 'FAILED' ? l10n.t('failedNote') : l10n.t('returnNote'), border: const OutlineInputBorder()),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.t('cancel'))),
            FilledButton(
              onPressed: () {
                if (status == 'RETURNED' && reason == 'OTHER' && noteController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = l10n.t('addReturnNoteOther'));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(status == 'FAILED' ? l10n.t('markFailed') : l10n.t('markReturned')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _submitOrderStatus(
      order,
      status,
      note: noteController.text,
      failedReason: reason,
    );
  }

  Future<void> _submitOrderStatus(
    DeliveryOrder order,
    String status, {
    String? note,
    String? failedReason,
    String? receiverName,
    bool? codCollected,
    double? codCollectedAmount,
    String? paymentMethod,
    File? proofFile,
  }) async {
    final actionError = _orderActionError(order, status);
    if (actionError != null) {
      _showActionError(actionError);
      return;
    }

    await _run(() async {
      if (proofFile != null) {
        await _api.uploadProof(order.id, proofFile, receiverName: receiverName, deliveryNote: note);
      }
      await _api.updateOrderStatus(
        order.id,
        status,
        note: note,
        failedReason: failedReason,
        receiverName: receiverName,
        codCollected: codCollected,
        codCollectedAmount: codCollectedAmount,
        paymentMethod: paymentMethod,
      );
      if (status == 'IN_TRANSIT' || status == 'PICKED_UP') {
        await _tracking.setStatus(ShipperStatus.busy);
      }
      if (status == 'DELIVERED' || status == 'FAILED' || status == 'RETURNED') {
        await _tracking.setStatus(ShipperStatus.available);
      }
      await _loadOrders();
    }, fallbackError: l10n.t('orderUpdateFailed'));
  }

  Future<void> _uploadProof(DeliveryOrder order) async {
    final receiverController = TextEditingController(text: order.receiverName);
    final noteController = TextEditingController(text: order.deliveryNote);
    final image = await _pickProofImage();
    if (image == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('proofOfDelivery')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiverController,
              decoration: InputDecoration(labelText: l10n.t('receiverName'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.t('deliveryNote'), border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.t('upload'))),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      await _api.uploadProof(
        order.id,
        File(image.path),
        receiverName: receiverController.text,
        deliveryNote: noteController.text,
      );
      await _loadOrders();
    }, fallbackError: l10n.t('orderUpdateFailed'));
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
  }

  Future<void> _openDirections(DeliveryOrder order, {required bool pickup}) async {
    final lat = pickup ? order.pickupLat : order.deliveryLat;
    final lng = pickup ? order.pickupLng : order.deliveryLng;
    final address = pickup ? order.pickupAddress : order.deliveryAddress;
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  Widget _buildLanguageMenu() {
    return PopupMenuButton<String>(
      tooltip: l10n.t('language'),
      icon: const Icon(Icons.language),
      initialValue: widget.languageController.code,
      onSelected: widget.languageController.setCode,
      itemBuilder: (context) => [
        PopupMenuItem(value: 'en', child: Text(l10n.t('english'))),
        PopupMenuItem(value: 'vi', child: Text(l10n.t('vietnamese'))),
      ],
    );
  }

  @override
  void dispose() {
    _tracking.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authChecked || _loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isLoggedIn) {
      return _buildLoginScreen();
    }

    final shipper = _selectedShipper;
    final activeOrders = _orders.where((order) => !order.isFinal).length;
    final codTotal = _orders.where((order) => !order.isFinal && !order.codCollected).fold<double>(0, (sum, order) => sum + order.codRemaining);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(l10n.t('deliveryConsole')),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          _buildLanguageMenu(),
          IconButton(tooltip: l10n.t('refresh'), onPressed: _bootstrap, icon: const Icon(Icons.sync)),
          IconButton(tooltip: l10n.t('logout'), onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _buildConnectionBanner(),
            const SizedBox(height: 10),
            if (shipper != null) ...[
              _buildCompactHeader(shipper, activeOrders, codTotal),
              const SizedBox(height: 10),
              _buildGpsCard(),
              const SizedBox(height: 18),
              _buildOrdersHeader(activeOrders),
              const SizedBox(height: 12),
              if (_orders.isEmpty && !_loadingOrders) _buildEmptyOrders(),
              ..._orders.map(
                (order) => OrderCard(
                  order: order,
                  onItemStatus: (itemId, status) async {
                    await _run(() async {
                      await _api.updateItemStatus(order.id, itemId, status);
                      await _loadOrders();
                    }, fallbackError: l10n.t('orderUpdateFailed'));
                  },
                  onOrderStatus: (orderId, status) => _updateOrderStatusDialog(order, status),
                  onUploadProof: () => _uploadProof(order),
                  onCallCustomer: () => _callCustomer(order.customerPhone),
                  onNavigatePickup: () => _openDirections(order, pickup: true),
                  onNavigateDelivery: () => _openDirections(order, pickup: false),
                  l10n: l10n,
                ),
              ),
            ] else
              _buildNoShipper(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerRight, child: _buildLanguageMenu()),
                        const SizedBox(height: 8),
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 18),
                        Text(l10n.t('loginTitle'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(l10n.t('loginSubtitle'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: l10n.t('email'), prefixIcon: const Icon(Icons.email_outlined), border: const OutlineInputBorder()),
                          validator: (value) => value == null || !value.contains('@') ? l10n.t('enterValidEmail') : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: l10n.t('password'), prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder()),
                          validator: (value) => value == null || value.length < 3 ? l10n.t('enterPassword') : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busyAction ? null : _login,
                          icon: _busyAction ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                          label: Text(l10n.t('login')),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 14),
                        Text(l10n.api(AppConfig.apiBaseUrl), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_outlined, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.connectedApi(AppConfig.apiBaseUrl),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(ShipperProfile shipper, int activeOrders, double codTotal) {
    final color = _shipperStatusColor(_state.status);
    final statusLabel = _shipperStatusLabel(_state.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shipper.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipper.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          _InlineMeta(icon: Icons.two_wheeler_outlined, text: shipper.vehicleType, l10n: l10n),
                          _InlineMeta(icon: Icons.confirmation_number_outlined, text: shipper.plateLabel, l10n: l10n),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 9, color: color),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SummaryBox(label: l10n.t('activeOrders'), value: '$activeOrders', icon: Icons.assignment_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _SummaryBox(label: l10n.t('codRemaining'), value: money(codTotal), icon: Icons.payments_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            _StatusSegmentedControl(
              current: _state.status,
              busy: _busyAction,
              onChanged: (status) => _run(() => _updateStatus(status)),
              l10n: l10n,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    final last = _state.lastPosition;
    final lastUpdate = _state.lastSentAt == null ? l10n.t('noSuccessfulUpdate') : shortTime(_state.lastSentAt);
    final accuracy = last == null ? l10n.t('waitingForGps') : '${last.accuracy.toStringAsFixed(0)}m';
    final statusUi = _gpsStatusUi(_state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.t('gpsTracking'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                StatusPill(
                  label: statusUi.label,
                  color: statusUi.color,
                  icon: statusUi.icon,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusUi.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusUi.color.withOpacity(0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusUi.icon, color: statusUi.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusUi.message,
                      style: TextStyle(color: statusUi.color, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _state.isTracking || _busyAction || _shipperId == null ? null : _startLiveGps,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.t('startLiveGps')),
                ),
                OutlinedButton.icon(
                  onPressed: !_state.isTracking || _busyAction ? null : () => _run(() => _tracking.stop(), fallbackError: l10n.t('unableStopGps')),
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.t('stop')),
                ),
                OutlinedButton.icon(
                  onPressed: _busyAction || _shipperId == null || _state.status == ShipperStatus.offline
                      ? null
                      : () => _run(() => _tracking.sendOnce(), fallbackError: l10n.t('unableSendGps')),
                  icon: _state.isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                  label: Text(l10n.t('sendOnce')),
                ),
                if (_state.gpsStatus == GpsStatus.permissionPermanentlyDenied)
                  OutlinedButton.icon(
                    onPressed: _openAppLocationSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(l10n.t('openAppSettings')),
                  ),
                if (_state.gpsStatus == GpsStatus.gpsOff)
                  OutlinedButton.icon(
                    onPressed: _openDeviceLocationSettings,
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(l10n.t('turnOnGps')),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _GpsInfoGrid(
              lastUpdate: lastUpdate,
              accuracy: accuracy,
              trackingState: statusUi.shortState,
              pendingRetryCount: _state.pendingRetryCount,
              connectionStatus: l10n.connectionLabel(_state.connectionStatus),
              l10n: l10n,
            ),
            if (_state.lastMessage != null) ...[
              const SizedBox(height: 8),
              Text(l10n.serviceMessage(_state.lastMessage!), style: TextStyle(color: statusUi.color, fontWeight: FontWeight.w700)),
            ],
            if (last != null) ...[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(l10n.t('debugLocationDetails'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                childrenPadding: EdgeInsets.zero,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.latLng(last.latitude, last.longitude),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.t('startTrackingHint')),
              ),
          ],
        ),
      ),
    );
  }

  _GpsStatusUi _gpsStatusUi(TrackingState state) {
    switch (state.gpsStatus) {
      case GpsStatus.gpsOff:
        return _GpsStatusUi(
          label: l10n.t('gpsOffLabel'),
          shortState: l10n.t('gpsOffShort'),
          message: l10n.t('gpsOffMessage'),
          color: Colors.deepOrange,
          icon: Icons.gps_off,
        );
      case GpsStatus.permissionRequired:
        return _GpsStatusUi(
          label: l10n.t('permissionLabel'),
          shortState: l10n.t('permissionShort'),
          message: l10n.t('permissionMessage'),
          color: Colors.orange,
          icon: Icons.location_disabled_outlined,
        );
      case GpsStatus.permissionPermanentlyDenied:
        return _GpsStatusUi(
          label: l10n.t('settingsLabel'),
          shortState: l10n.t('settingsShort'),
          message: l10n.t('settingsMessage'),
          color: Colors.red,
          icon: Icons.settings_outlined,
        );
      case GpsStatus.sendingLocation:
        return _GpsStatusUi(
          label: l10n.t('sendingLabel'),
          shortState: l10n.t('sendingShort'),
          message: l10n.t('sendingMessage'),
          color: Colors.blue,
          icon: Icons.cloud_upload_outlined,
        );
      case GpsStatus.lastUpdateFailed:
        return _GpsStatusUi(
          label: l10n.t('failedLabel'),
          shortState: l10n.t('lastFailedShort'),
          message: l10n.t('lastFailedMessage'),
          color: Colors.red,
          icon: Icons.error_outline,
        );
      case GpsStatus.offlineWaitingNetwork:
        return _GpsStatusUi(
          label: l10n.t('offlineLabel'),
          shortState: l10n.t('waitingNetworkShort'),
          message: l10n.t('waitingNetworkMessage'),
          color: Colors.orange,
          icon: Icons.cloud_off_outlined,
        );
      case GpsStatus.trackingLive:
        return _GpsStatusUi(
          label: l10n.t('liveLabel'),
          shortState: l10n.t('liveShort'),
          message: l10n.t('liveMessage'),
          color: Colors.green,
          icon: Icons.gps_fixed,
        );
      case GpsStatus.stopped:
        return state.status == ShipperStatus.offline
            ? _GpsStatusUi(
                label: l10n.t('offlineLabel'),
                shortState: l10n.t('offline'),
                message: l10n.t('offlineMessage'),
                color: Colors.grey,
                icon: Icons.power_settings_new,
              )
            : _GpsStatusUi(
                label: l10n.t('stoppedLabel'),
                shortState: l10n.t('stoppedShort'),
                message: l10n.t('stoppedMessage'),
                color: Colors.grey,
                icon: Icons.gps_not_fixed,
              );
    }
  }

  Widget _buildOrdersHeader(int activeOrders) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.t('assignedOrders'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (_loadingOrders)
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Chip(label: Text(l10n.activeCount(activeOrders))),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 40),
            const SizedBox(height: 8),
            Text(l10n.t('noAssignedOrders')),
            Text(l10n.t('askAssignOrder')),
          ],
        ),
      ),
    );
  }

  Widget _buildNoShipper() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('noShipperFound'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}


class _StatusSegmentedControl extends StatelessWidget {
  final ShipperStatus current;
  final bool busy;
  final ValueChanged<ShipperStatus> onChanged;
  final AppLocalizations l10n;

  const _StatusSegmentedControl({required this.current, required this.busy, required this.onChanged, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      (status: ShipperStatus.available, label: l10n.t('available'), icon: Icons.check_circle_outline),
      (status: ShipperStatus.busy, label: l10n.t('busy'), icon: Icons.local_shipping_outlined),
      (status: ShipperStatus.offline, label: l10n.t('offline'), icon: Icons.power_settings_new),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: statuses.map((entry) {
          final selected = current == entry.status;
          final color = selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: busy || selected ? null : () => onChanged(entry.status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(minHeight: 42),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            entry.label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(color: color, fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GpsStatusUi {
  final String label;
  final String shortState;
  final String message;
  final Color color;
  final IconData icon;

  const _GpsStatusUi({
    required this.label,
    required this.shortState,
    required this.message,
    required this.color,
    required this.icon,
  });
}

class _GpsInfoGrid extends StatelessWidget {
  final String lastUpdate;
  final String accuracy;
  final String trackingState;
  final int pendingRetryCount;
  final String connectionStatus;
  final AppLocalizations l10n;

  const _GpsInfoGrid({
    required this.lastUpdate,
    required this.accuracy,
    required this.trackingState,
    required this.pendingRetryCount,
    required this.connectionStatus,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _GpsInfoRow(icon: Icons.schedule, label: l10n.t('lastUpdate'), value: lastUpdate),
          const SizedBox(height: 8),
          _GpsInfoRow(icon: Icons.gps_fixed, label: l10n.t('accuracy'), value: accuracy),
          const SizedBox(height: 8),
          _GpsInfoRow(icon: Icons.route_outlined, label: l10n.t('trackingState'), value: trackingState),
          const SizedBox(height: 8),
          _GpsInfoRow(icon: Icons.cloud_queue_outlined, label: l10n.t('pendingRetries'), value: '$pendingRetryCount'),
          const SizedBox(height: 8),
          _GpsInfoRow(icon: Icons.wifi_tethering_outlined, label: l10n.t('connection'), value: connectionStatus),
        ],
      ),
    );
  }
}

class _GpsInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _GpsInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppLocalizations l10n;

  const _InlineMeta({required this.icon, required this.text, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text.isEmpty ? l10n.t('notSet') : text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryBox({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
