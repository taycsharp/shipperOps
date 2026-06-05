import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/delivery_models.dart';
import '../services/api_client.dart';
import '../services/location_tracking_service.dart';
import '../services/shipper_api.dart';
import '../utils/formatters.dart';
import '../widgets/order_card.dart';
import '../widgets/status_pill.dart';

class ShipperHomeScreen extends StatefulWidget {
  const ShipperHomeScreen({super.key});

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
      setState(() => _error = 'Please login again. $e');
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
            'This production mobile app is for SHIPPER accounts only. Use the web dashboard or a separate simulator for admin/dispatcher testing.';
      });
      return;
    }

    final selected = await _api.getAuthenticatedShipperProfile(user.id);
    setState(() {
      _selectedShipper = selected;
      _orders = [];
      _error = selected == null
          ? 'No shipper profile is linked to ${user.email}. Ask an admin/dispatcher to create and link your shipper profile before using the mobile app.'
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
      setState(() => _error = e.toString());
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busyAction) return;
    try {
      setState(() {
        _busyAction = true;
        _error = null;
      });
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  String _shipperStatusLabel(ShipperStatus status) {
    switch (status) {
      case ShipperStatus.available:
        return 'Available';
      case ShipperStatus.busy:
        return 'Busy';
      case ShipperStatus.suspended:
        return 'Suspended';
      case ShipperStatus.offline:
        return 'Offline';
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
    if (shipperId == null) return 'No shipper profile is linked to this login.';
    if (order.shipperId != shipperId) return 'This order is not assigned to your shipper profile.';
    if (!_canTransition(order, nextStatus)) {
      return 'Cannot change order ${order.orderCode} from ${compactStatus(order.status)} to ${compactStatus(nextStatus)}.';
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
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
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
          title: const Text('Complete delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: receiverController,
                  decoration: const InputDecoration(labelText: 'Receiver name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Delivery note *', border: OutlineInputBorder()),
                ),
                if (order.codAmount > 0) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: codController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'COD collected amount (${money(order.codAmount)})', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank transfer')),
                      DropdownMenuItem(value: 'WALLET', child: Text('Wallet')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (value) => setDialogState(() => paymentMethod = value ?? 'CASH'),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: codConfirmed,
                    title: const Text('I confirm COD was collected'),
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
                      ? 'Upload proof photo *'
                      : proofImage != null
                          ? 'Proof selected'
                          : 'Replace proof photo'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final codAmount = double.tryParse(codController.text.trim());
                final missingProof = order.proofImageUrl.isEmpty && proofImage == null;
                String? validation;
                if (receiverController.text.trim().isEmpty) {
                  validation = 'Receiver name is required.';
                } else if (noteController.text.trim().isEmpty) {
                  validation = 'Delivery note is required.';
                } else if (order.codAmount > 0 && !codConfirmed) {
                  validation = 'Confirm COD collection before completing this delivery.';
                } else if (order.codAmount > 0 && (codAmount == null || codAmount <= 0)) {
                  validation = 'Enter the COD amount collected.';
                } else if (missingProof) {
                  validation = 'Proof photo is required before marking delivered.';
                }
                if (validation != null) {
                  setDialogState(() => dialogError = validation);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Mark delivered'),
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
          title: Text(status == 'FAILED' ? 'Mark failed' : 'Mark returned'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: InputDecoration(labelText: status == 'FAILED' ? 'Failed reason *' : 'Return reason *', border: const OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CUSTOMER_NOT_AVAILABLE', child: Text('Customer not available')),
                    DropdownMenuItem(value: 'WRONG_ADDRESS', child: Text('Wrong address')),
                    DropdownMenuItem(value: 'REFUSED_DELIVERY', child: Text('Refused delivery')),
                    DropdownMenuItem(value: 'DAMAGED_GOODS', child: Text('Damaged goods')),
                    DropdownMenuItem(value: 'PAYMENT_ISSUE', child: Text('Payment issue')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) => setDialogState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: status == 'FAILED' ? 'Failed note' : 'Return note', border: const OutlineInputBorder()),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (status == 'RETURNED' && reason == 'OTHER' && noteController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = 'Add a return note for Other.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(status == 'FAILED' ? 'Mark failed' : 'Mark returned'),
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
    });
  }

  Future<void> _uploadProof(DeliveryOrder order) async {
    final receiverController = TextEditingController(text: order.receiverName);
    final noteController = TextEditingController(text: order.deliveryNote);
    final image = await _pickProofImage();
    if (image == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proof of delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiverController,
              decoration: const InputDecoration(labelText: 'Receiver name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Delivery note', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
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
    });
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
        title: const Text('Delivery Console'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(onPressed: _bootstrap, icon: const Icon(Icons.sync)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
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
                    });
                  },
                  onOrderStatus: (orderId, status) => _updateOrderStatusDialog(order, status),
                  onUploadProof: () => _uploadProof(order),
                  onCallCustomer: () => _callCustomer(order.customerPhone),
                  onNavigatePickup: () => _openDirections(order, pickup: true),
                  onNavigateDelivery: () => _openDirections(order, pickup: false),
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
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 18),
                        Text('Shipper Login', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Secure access for shipper GPS and delivery workflow', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                          validator: (value) => value == null || !value.contains('@') ? 'Enter valid email' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                          validator: (value) => value == null || value.length < 3 ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busyAction ? null : _login,
                          icon: _busyAction ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                          label: const Text('Login'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 14),
                        Text('API: ${AppConfig.apiBaseUrl}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
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
              'Connected API: ${AppConfig.apiBaseUrl}',
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
                          _InlineMeta(icon: Icons.two_wheeler_outlined, text: shipper.vehicleType),
                          _InlineMeta(icon: Icons.confirmation_number_outlined, text: shipper.plateLabel),
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
                Expanded(child: _SummaryBox(label: 'Active Orders', value: '$activeOrders', icon: Icons.assignment_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _SummaryBox(label: 'COD Remaining', value: money(codTotal), icon: Icons.payments_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.available)),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Available'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.busy)),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Busy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.offline)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Offline'),
                  ),
                ),
              ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('GPS tracking', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                StatusPill(
                  label: _state.isTracking ? 'LIVE' : 'STOPPED',
                  color: _state.isTracking ? Colors.green : Colors.grey,
                  icon: _state.isTracking ? Icons.gps_fixed : Icons.gps_off,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _state.isTracking || _busyAction || _shipperId == null ? null : () => _run(() => _tracking.start(_shipperId!)),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start live GPS'),
                ),
                OutlinedButton.icon(
                  onPressed: !_state.isTracking || _busyAction ? null : () => _run(() => _tracking.stop()),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                OutlinedButton.icon(
                  onPressed: _busyAction || _shipperId == null ? null : () => _run(() => _tracking.sendOnce()),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Send once'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (last != null)
              Text(
                'Last GPS: ${last.latitude.toStringAsFixed(5)}, ${last.longitude.toStringAsFixed(5)} • accuracy ${last.accuracy.toStringAsFixed(0)}m • ${shortTime(_state.lastSentAt)}',
              )
            else
              const Text('No GPS sent yet. Start tracking or send once.'),
            if (_state.lastMessage != null) ...[
              const SizedBox(height: 6),
              Text(_state.lastMessage!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersHeader(int activeOrders) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Assigned orders',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (_loadingOrders)
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Chip(label: Text('$activeOrders active')),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40),
            SizedBox(height: 8),
            Text('No assigned orders yet.'),
            Text('Ask dispatcher/admin to assign an order to this shipper.'),
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
            const Text(
              'No shipper profiles found. Login as a SHIPPER user or create a shipper in the admin dashboard.',
              style: TextStyle(fontWeight: FontWeight.w700),
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

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text.isEmpty ? 'Not set' : text,
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
