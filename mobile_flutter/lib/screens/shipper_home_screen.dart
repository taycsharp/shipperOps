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
  static const _shipperIdKey = 'shipper_id';

  late final ApiClient _client;
  late final ShipperApi _api;
  late final LocationTrackingService _tracking;

  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'shipper1@example.com');
  final _passwordController = TextEditingController(text: 'shipper123');
  final _picker = ImagePicker();

  AppUser? _currentUser;
  List<ShipperProfile> _shippers = [];
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
      _shippers = [];
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
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_shipperIdKey);
    final shippers = await _api.getShippers();
    ShipperProfile? selected;
    if (shippers.isNotEmpty) {
      selected = shippers.firstWhere(
        (shipper) => shipper.id == savedId,
        orElse: () => shippers.first,
      );
    }
    setState(() {
      _shippers = shippers;
      _selectedShipper = selected;
    });
    if (selected != null) {
      _tracking.bindShipper(selected.id, status: selected.status);
      await _saveShipperId(selected.id);
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

  Future<void> _saveShipperId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shipperIdKey, id);
  }

  Future<void> _selectShipper(int? shipperId) async {
    if (shipperId == null) return;
    final selected = _shippers.firstWhere((shipper) => shipper.id == shipperId);
    setState(() {
      _selectedShipper = selected;
      _orders = [];
      _error = null;
    });
    _tracking.bindShipper(selected.id, status: selected.status);
    await _saveShipperId(selected.id);
    await _loadOrders();
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
      setState(() => _orders = orders);
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

  Future<void> _updateOrderStatusDialog(DeliveryOrder order, String status) async {
    final noteController = TextEditingController();
    final receiverController = TextEditingController(text: order.receiverName);
    final codController = TextEditingController(text: order.codAmount > 0 ? order.codAmount.toStringAsFixed(0) : '');
    String failedReason = 'CUSTOMER_NOT_AVAILABLE';
    String paymentMethod = 'CASH';
    final needsDeliveryInfo = status == 'DELIVERED' || status == 'PARTIALLY_DELIVERED';
    final needsFailedReason = status == 'FAILED' || status == 'RETURNED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${compactStatus(status)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (needsDeliveryInfo) ...[
                TextField(
                  controller: receiverController,
                  decoration: const InputDecoration(labelText: 'Receiver name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'COD collected amount', border: OutlineInputBorder()),
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
                  onChanged: (value) => paymentMethod = value ?? 'CASH',
                ),
              ],
              if (needsFailedReason) ...[
                DropdownButtonFormField<String>(
                  value: failedReason,
                  decoration: const InputDecoration(labelText: 'Failed reason', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CUSTOMER_NOT_AVAILABLE', child: Text('Customer not available')),
                    DropdownMenuItem(value: 'WRONG_ADDRESS', child: Text('Wrong address')),
                    DropdownMenuItem(value: 'DAMAGED_GOODS', child: Text('Damaged goods')),
                    DropdownMenuItem(value: 'REFUSED_DELIVERY', child: Text('Refused delivery')),
                    DropdownMenuItem(value: 'REATTEMPT_REQUIRED', child: Text('Reattempt required')),
                    DropdownMenuItem(value: 'RETURN_TO_WAREHOUSE', child: Text('Return to warehouse')),
                  ],
                  onChanged: (value) => failedReason = value ?? 'CUSTOMER_NOT_AVAILABLE',
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(() async {
      await _api.updateOrderStatus(
        order.id,
        status,
        note: noteController.text,
        failedReason: needsFailedReason ? failedReason : null,
        receiverName: needsDeliveryInfo ? receiverController.text : null,
        codCollected: needsDeliveryInfo && order.codAmount > 0,
        codCollectedAmount: needsDeliveryInfo ? double.tryParse(codController.text) : null,
        paymentMethod: needsDeliveryInfo && order.codAmount > 0 ? paymentMethod : null,
      );
      if (status == 'IN_TRANSIT' || status == 'PICKED_UP') {
        await _tracking.setStatus(ShipperStatus.busy);
      }
      if (status == 'DELIVERED' || status == 'FAILED' || status == 'RETURNED' || status == 'PARTIALLY_DELIVERED') {
        await _tracking.setStatus(ShipperStatus.available);
      }
      await _loadOrders();
    });
  }

  Future<void> _uploadProof(DeliveryOrder order) async {
    final receiverController = TextEditingController(text: order.receiverName);
    final noteController = TextEditingController(text: order.deliveryNote);
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
    if (source == null) return;

    final image = await _picker.pickImage(source: source, imageQuality: 78, maxWidth: 1600);
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
        title: const Text('Shipper Delivery Console'),
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
          padding: const EdgeInsets.all(16),
          children: [
            _buildConnectionBanner(),
            const SizedBox(height: 12),
            _buildUserBanner(),
            const SizedBox(height: 12),
            _buildShipperSelector(),
            if (shipper != null) ...[
              const SizedBox(height: 12),
              _buildStatusCard(shipper, activeOrders, codTotal),
              const SizedBox(height: 12),
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

  Widget _buildUserBanner() {
    final user = _currentUser;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(user?.name ?? 'User', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${user?.email ?? ''} • ${roleToApi(user?.role ?? UserRole.shipper)}'),
      ),
    );
  }

  Widget _buildShipperSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Working shipper', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedShipper?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.delivery_dining),
                labelText: 'Select shipper profile',
              ),
              items: _shippers
                  .map(
                    (shipper) => DropdownMenuItem<int>(
                      value: shipper.id,
                      child: Text('${shipper.displayName} • ${shipper.plateLabel}'),
                    ),
                  )
                  .toList(),
              onChanged: _busyAction ? null : _selectShipper,
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

  Widget _buildStatusCard(ShipperProfile shipper, int activeOrders, double codTotal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    shipper.displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shipper.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      Text('${shipper.phone.isEmpty ? 'No phone' : shipper.phone} • ${shipper.vehicleType} • ${shipper.plateLabel}'),
                    ],
                  ),
                ),
                StatusPill(
                  label: statusToApi(_state.status),
                  color: _shipperStatusColor(_state.status),
                  icon: Icons.circle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _SummaryBox(label: 'Active orders', value: '$activeOrders', icon: Icons.assignment_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _SummaryBox(label: 'COD remaining', value: money(codTotal), icon: Icons.payments_outlined)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.available)),
                  child: const Text('Available'),
                ),
                FilledButton.tonal(
                  onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.busy)),
                  child: const Text('Busy'),
                ),
                OutlinedButton(
                  onPressed: _busyAction ? null : () => _run(() => _updateStatus(ShipperStatus.offline)),
                  child: const Text('Offline'),
                ),
              ],
            ),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No shipper profiles found. Login as a SHIPPER user or create a shipper in the admin dashboard.'),
      ),
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
