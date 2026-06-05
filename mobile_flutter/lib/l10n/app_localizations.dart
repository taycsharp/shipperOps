import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  static const storageKey = 'app_language_code';
  static const defaultCode = 'en';
  static const supportedCodes = ['en', 'vi'];

  String _code = defaultCode;

  String get code => _code;
  Locale get locale => Locale(_code);
  AppLocalizations get strings => AppLocalizations(_code);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    if (saved != null && supportedCodes.contains(saved)) {
      _code = saved;
    }
  }

  Future<void> setCode(String code) async {
    if (!supportedCodes.contains(code) || code == _code) return;
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, code);
  }
}

class AppLocalizations {
  final String code;

  const AppLocalizations(this.code);

  bool get isVietnamese => code == 'vi';

  String t(String key) => (_localizedValues[code] ?? _localizedValues[LanguageController.defaultCode])?[key] ?? _localizedValues[LanguageController.defaultCode]![key] ?? key;

  String connectedApi(String apiUrl) => isVietnamese ? 'API đã kết nối: $apiUrl' : 'Connected API: $apiUrl';
  String api(String apiUrl) => isVietnamese ? 'API: $apiUrl' : 'API: $apiUrl';
  String noShipperProfileLinked(String email) => isVietnamese
      ? 'Chưa liên kết hồ sơ shipper với $email. Vui lòng nhờ quản trị/điều phối tạo và liên kết hồ sơ shipper trước khi dùng ứng dụng.'
      : 'No shipper profile is linked to $email. Ask an admin/dispatcher to create and link your shipper profile before using the mobile app.';
  String cannotChangeOrder(String code, String from, String to) => isVietnamese
      ? 'Không thể đổi đơn $code từ $from sang $to.'
      : 'Cannot change order $code from $from to $to.';
  String activeCount(int count) => isVietnamese ? '$count đang xử lý' : '$count active';
  String latLng(double lat, double lng) => isVietnamese ? 'Vĩ độ ${lat.toStringAsFixed(5)}, Kinh độ ${lng.toStringAsFixed(5)}' : 'Lat ${lat.toStringAsFixed(5)}, Lng ${lng.toStringAsFixed(5)}';
  String codAmountLabel(String amount) => isVietnamese ? 'COD đã thu ($amount)' : 'COD collected amount ($amount)';
  String deliveredQuantity(int delivered, int quantity) => isVietnamese ? 'đã giao $delivered/$quantity' : 'delivered $delivered/$quantity';
  String receiver(String value) => isVietnamese ? 'Người nhận: $value' : 'Receiver: $value';
  String reason(String value) => isVietnamese ? 'Lý do: $value' : 'Reason: $value';
  String note(String value) => isVietnamese ? 'Ghi chú: $value' : 'Note: $value';
  String codBadge(String amount, bool collected) => collected ? t('codCollected') : (isVietnamese ? 'COD $amount' : 'COD $amount');

  String serviceMessage(String message) {
    final exact = _serviceMessageKeys[message];
    if (exact != null) return t(exact);
    if (message.startsWith('Status changed to ')) {
      final raw = message.replaceFirst('Status changed to ', '').replaceFirst('.', '');
      return isVietnamese ? 'Đã đổi trạng thái thành ${displayStatus(raw)}.' : 'Status changed to ${displayStatus(raw)}.';
    }
    return message;
  }

  String connectionLabel(String status) {
    final exact = _connectionStatusKeys[status];
    if (exact != null) return t(exact);
    return status;
  }

  String shipperStatusLabel(Object status) {
    switch (status.toString().split('.').last.toLowerCase()) {
      case 'available':
        return t('available');
      case 'busy':
        return t('busy');
      case 'suspended':
        return t('suspended');
      case 'offline':
        return t('offline');
      default:
        return displayStatus(status.toString());
    }
  }

  String displayStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return t('pending');
      case 'ASSIGNED':
        return t('assigned');
      case 'PICKED_UP':
        return t('pickedUp');
      case 'IN_TRANSIT':
        return t('inTransit');
      case 'DELIVERED':
        return t('delivered');
      case 'PARTIALLY_DELIVERED':
        return t('partiallyDelivered');
      case 'FAILED':
        return t('failed');
      case 'RETURNED':
        return t('returned');
      case 'CANCELLED':
        return t('cancelled');
      case 'CUSTOMER_NOT_AVAILABLE':
        return t('customerNotAvailable');
      case 'WRONG_ADDRESS':
        return t('wrongAddress');
      case 'REFUSED_DELIVERY':
        return t('refusedDelivery');
      case 'DAMAGED_GOODS':
        return t('damagedGoods');
      case 'PAYMENT_ISSUE':
        return t('paymentIssue');
      case 'OTHER':
        return t('other');
      default:
        return status
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
            .join(' ');
    }
  }
}


const _serviceMessageKeys = <String, String>{
  'Shipper profile ready': 'shipperProfileReady',
  'Live GPS is on. Dispatch can see your latest location.': 'liveGpsOn',
  'Tracking stopped.': 'trackingStopped',
  'You are offline. GPS tracking is paused.': 'offlinePaused',
  'You are offline. Go Available to restart GPS tracking.': 'offlineMessage',
  'Sending location update…': 'sendingLocationUpdate',
  'Location updated successfully.': 'locationUpdated',
  'GPS is off. Turn on Location Services to continue tracking.': 'gpsOffMessage',
  'No connection. Your latest location is saved and will retry automatically.': 'waitingNetworkMessage',
  'Retrying saved location update…': 'retryingSavedLocation',
  'Saved location updates synced.': 'savedLocationsSynced',
  'Some saved locations still need retry.': 'someRetriesPending',
  'GPS is off. Turn on Location Services to share delivery progress.': 'gpsOffShare',
  'Location permission is needed so dispatch can track your delivery route.': 'permissionDispatch',
  'Allow location permission to start live GPS tracking.': 'allowPermission',
  'Location permission is off. Open app settings and allow location access.': 'settingsMessage',
  'No authenticated shipper profile is linked to this login.': 'noShipperAction',
};

const _connectionStatusKeys = <String, String>{
  'Ready': 'ready',
  'Offline': 'offlineConn',
  'Waiting to retry': 'waitingRetry',
  'Online': 'online',
  'Sending': 'sending',
  'Retry pending': 'retryPending',
  'GPS off': 'gpsOffConn',
  'Waiting for network': 'waitingNetworkShort',
  'Update failed': 'updateFailed',
  'Retrying': 'retrying',
  'Permission needed': 'permissionNeeded',
  'Settings needed': 'settingsNeeded',
};

const _localizedValues = <String, Map<String, String>>{
  'en': {
    'appTitle': 'Shipper Mobile',
    'language': 'Language',
    'english': 'English',
    'vietnamese': 'Tiếng Việt',
    'deliveryConsole': 'Delivery Console',
    'refresh': 'Refresh',
    'logout': 'Logout',
    'loginTitle': 'Shipper Login',
    'loginSubtitle': 'Secure access for shipper GPS and delivery workflow',
    'email': 'Email',
    'password': 'Password',
    'login': 'Login',
    'enterValidEmail': 'Enter valid email',
    'enterPassword': 'Enter password',
    'pleaseLoginAgain': 'Please login again.',
    'serverUnavailable': 'Server temporarily unavailable. Please try again.',
    'unableSendGps': 'Unable to send GPS. Check your internet connection.',
    'unableStartGps': 'Unable to start GPS. Check location permission and internet connection.',
    'unableStopGps': 'Unable to stop GPS. Please try again.',
    'orderUpdateFailed': 'Order update failed. Please try again.',
    'shipperOnly': 'This production mobile app is for SHIPPER accounts only. Use the web dashboard or a separate simulator for admin/dispatcher testing.',
    'noShipperAction': 'No shipper profile is linked to this login.',
    'orderNotAssigned': 'This order is not assigned to your shipper profile.',
    'noShipperFound': 'No shipper profiles found. Login as a SHIPPER user or create a shipper in the admin dashboard.',
    'activeOrders': 'Active Orders',
    'codRemaining': 'COD Remaining',
    'available': 'Available',
    'busy': 'Busy',
    'offline': 'Offline',
    'suspended': 'Suspended',
    'gpsTracking': 'GPS tracking',
    'startLiveGps': 'Start live GPS',
    'stop': 'Stop',
    'sendOnce': 'Send once',
    'openAppSettings': 'Open app settings',
    'turnOnGps': 'Turn on GPS',
    'lastUpdate': 'Last update',
    'accuracy': 'Accuracy',
    'trackingState': 'Tracking state',
    'pendingRetries': 'Pending retries',
    'connection': 'Connection',
    'debugLocationDetails': 'Debug location details',
    'startTrackingHint': 'Start tracking when you begin your route. Coordinates are hidden by default.',
    'noSuccessfulUpdate': 'No successful update yet',
    'waitingForGps': 'Waiting for GPS',
    'startLiveGpsQuestion': 'Start live GPS?',
    'startLiveGpsExplanation': 'ShipperOps uses your location to update dispatch, support accurate ETAs, and help customers receive deliveries. Your coordinates stay hidden in the app unless you open debug details.',
    'notNow': 'Not now',
    'startGps': 'Start GPS',
    'gpsOffLabel': 'GPS OFF',
    'gpsOffShort': 'GPS off',
    'gpsOffMessage': 'GPS is off. Turn on Location Services to continue tracking.',
    'permissionLabel': 'PERMISSION',
    'permissionShort': 'Permission needed',
    'permissionMessage': 'Location permission is needed to share your delivery progress.',
    'settingsLabel': 'SETTINGS',
    'settingsShort': 'Open settings',
    'settingsMessage': 'Location permission is off. Open app settings and allow location access.',
    'sendingLabel': 'SENDING',
    'sendingShort': 'Sending location',
    'sendingMessage': 'Sending your latest location now…',
    'failedLabel': 'FAILED',
    'lastFailedShort': 'Last update failed',
    'lastFailedMessage': 'Last GPS update failed. We will try again automatically.',
    'offlineLabel': 'OFFLINE',
    'waitingNetworkShort': 'Waiting for network',
    'waitingNetworkMessage': 'No connection. Your latest location is saved and will retry automatically.',
    'liveLabel': 'LIVE',
    'liveShort': 'Tracking live',
    'liveMessage': 'Tracking is live. Dispatch can see your latest successful location.',
    'offlineMessage': 'You are offline. Go Available to restart GPS tracking.',
    'stoppedLabel': 'STOPPED',
    'stoppedShort': 'Tracking stopped',
    'stoppedMessage': 'GPS tracking is stopped. Start live GPS when you begin your route.',
    'assignedOrders': 'Assigned Orders',
    'noAssignedOrders': 'No assigned orders yet.',
    'askAssignOrder': 'Ask dispatcher/admin to assign an order to this shipper.',
    'completeDelivery': 'Complete delivery',
    'receiverName': 'Receiver name',
    'receiverNameRequiredLabel': 'Receiver name *',
    'deliveryNote': 'Delivery note',
    'deliveryNoteRequiredLabel': 'Delivery note *',
    'paymentMethod': 'Payment method',
    'cash': 'Cash',
    'bankTransfer': 'Bank transfer',
    'wallet': 'Wallet',
    'other': 'Other',
    'confirmCodCollected': 'I confirm COD was collected',
    'uploadProofPhotoRequired': 'Upload proof photo *',
    'proofSelected': 'Proof selected',
    'replaceProofPhoto': 'Replace proof photo',
    'receiverNameRequired': 'Receiver name is required.',
    'deliveryNoteRequired': 'Delivery note is required.',
    'confirmCodBeforeComplete': 'Confirm COD collection before completing this delivery.',
    'enterCodCollected': 'Enter the COD amount collected.',
    'proofPhotoRequired': 'Proof photo is required before marking delivered.',
    'markDelivered': 'Mark delivered',
    'markFailed': 'Mark failed',
    'markReturned': 'Mark returned',
    'failedReasonRequired': 'Failed reason *',
    'returnReasonRequired': 'Return reason *',
    'failedNote': 'Failed note',
    'returnNote': 'Return note',
    'addReturnNoteOther': 'Add a return note for Other.',
    'cancel': 'Cancel',
    'proofOfDelivery': 'Proof of delivery',
    'upload': 'Upload',
    'takePhoto': 'Take photo',
    'chooseFromGallery': 'Choose from gallery',
    'phoneNotSet': 'Phone not set',
    'pickupAddressNotSet': 'Pickup address not set',
    'callCustomer': 'Call customer',
    'pickupMap': 'Pickup map',
    'openMap': 'Open map',
    'navigate': 'Navigate',
    'codTotal': 'COD total',
    'collected': 'Collected',
    'no': 'No',
    'items': 'Items',
    'weight': 'Weight',
    'proofUploaded': 'Proof uploaded',
    'packageItems': 'Package items',
    'noSku': 'No SKU',
    'updateItem': 'Update item',
    'markPickedUp': 'Mark picked up',
    'startDelivery': 'Start delivery',
    'uploadProof': 'Upload proof',
    'replaceProof': 'Replace proof',
    'notSet': 'Not set',
    'pending': 'Pending',
    'assigned': 'Assigned',
    'pickedUp': 'Picked up',
    'inTransit': 'In transit',
    'delivered': 'Delivered',
    'partiallyDelivered': 'Partially delivered',
    'failed': 'Failed',
    'returned': 'Returned',
    'cancelled': 'Cancelled',
    'customerNotAvailable': 'Customer not available',
    'wrongAddress': 'Wrong address',
    'refusedDelivery': 'Refused delivery',
    'damagedGoods': 'Damaged goods',
    'paymentIssue': 'Payment issue',
    'ready': 'Ready',
    'offlineConn': 'Offline',
    'waitingRetry': 'Waiting to retry',
    'shipperProfileReady': 'Shipper profile ready',
    'liveGpsOn': 'Live GPS is on. Dispatch can see your latest location.',
    'online': 'Online',
    'trackingStopped': 'Tracking stopped.',
    'offlinePaused': 'You are offline. GPS tracking is paused.',
    'sending': 'Sending',
    'sendingLocationUpdate': 'Sending location update…',
    'locationUpdated': 'Location updated successfully.',
    'retryPending': 'Retry pending',
    'updateFailed': 'Update failed',
    'retrying': 'Retrying',
    'retryingSavedLocation': 'Retrying saved location update…',
    'savedLocationsSynced': 'Saved location updates synced.',
    'someRetriesPending': 'Some saved locations still need retry.',
    'gpsOffConn': 'GPS off',
    'gpsOffShare': 'GPS is off. Turn on Location Services to share delivery progress.',
    'permissionNeeded': 'Permission needed',
    'permissionDispatch': 'Location permission is needed so dispatch can track your delivery route.',
    'allowPermission': 'Allow location permission to start live GPS tracking.',
    'settingsNeeded': 'Settings needed',
    'codCollected': 'COD collected',
  },
  'vi': {
    'appTitle': 'Ứng dụng Shipper',
    'language': 'Ngôn ngữ',
    'english': 'English',
    'vietnamese': 'Tiếng Việt',
    'deliveryConsole': 'Bảng giao hàng',
    'refresh': 'Làm mới',
    'logout': 'Đăng xuất',
    'loginTitle': 'Đăng nhập shipper',
    'loginSubtitle': 'Truy cập an toàn cho GPS và quy trình giao hàng',
    'email': 'Email',
    'password': 'Mật khẩu',
    'login': 'Đăng nhập',
    'enterValidEmail': 'Nhập email hợp lệ',
    'enterPassword': 'Nhập mật khẩu',
    'pleaseLoginAgain': 'Vui lòng đăng nhập lại.',
    'serverUnavailable': 'Máy chủ tạm thời không khả dụng. Vui lòng thử lại.',
    'unableSendGps': 'Không gửi được GPS. Kiểm tra kết nối internet.',
    'unableStartGps': 'Không bắt đầu được GPS. Kiểm tra quyền vị trí và internet.',
    'unableStopGps': 'Không dừng được GPS. Vui lòng thử lại.',
    'orderUpdateFailed': 'Cập nhật đơn thất bại. Vui lòng thử lại.',
    'shipperOnly': 'Ứng dụng mobile production này chỉ dành cho tài khoản SHIPPER. Vui lòng dùng dashboard web hoặc công cụ giả lập riêng để kiểm thử admin/điều phối.',
    'noShipperAction': 'Chưa liên kết hồ sơ shipper với tài khoản này.',
    'orderNotAssigned': 'Đơn này không thuộc hồ sơ shipper của bạn.',
    'noShipperFound': 'Không tìm thấy hồ sơ shipper. Đăng nhập bằng tài khoản SHIPPER hoặc tạo shipper trong dashboard admin.',
    'activeOrders': 'Đơn đang xử lý',
    'codRemaining': 'COD còn lại',
    'available': 'Sẵn sàng',
    'busy': 'Đang bận',
    'offline': 'Ngoại tuyến',
    'suspended': 'Tạm khóa',
    'gpsTracking': 'Theo dõi GPS',
    'startLiveGps': 'Bắt đầu GPS',
    'stop': 'Dừng',
    'sendOnce': 'Gửi vị trí',
    'openAppSettings': 'Mở cài đặt app',
    'turnOnGps': 'Bật GPS',
    'lastUpdate': 'Cập nhật cuối',
    'accuracy': 'Độ chính xác',
    'trackingState': 'Trạng thái GPS',
    'pendingRetries': 'Lần gửi lại chờ',
    'connection': 'Kết nối',
    'debugLocationDetails': 'Chi tiết vị trí debug',
    'startTrackingHint': 'Bắt đầu theo dõi khi bạn chạy tuyến. Tọa độ mặc định được ẩn.',
    'noSuccessfulUpdate': 'Chưa gửi vị trí thành công',
    'waitingForGps': 'Đang chờ GPS',
    'startLiveGpsQuestion': 'Bắt đầu GPS?',
    'startLiveGpsExplanation': 'ShipperOps dùng vị trí của bạn để cập nhật điều phối, hỗ trợ ETA chính xác và giúp khách nhận hàng. Tọa độ được ẩn trong app trừ khi mở chi tiết debug.',
    'notNow': 'Để sau',
    'startGps': 'Bắt đầu GPS',
    'gpsOffLabel': 'GPS TẮT',
    'gpsOffShort': 'GPS tắt',
    'gpsOffMessage': 'GPS đang tắt. Bật Dịch vụ vị trí để tiếp tục theo dõi.',
    'permissionLabel': 'CẦN QUYỀN',
    'permissionShort': 'Cần quyền vị trí',
    'permissionMessage': 'Cần quyền vị trí để chia sẻ tiến độ giao hàng.',
    'settingsLabel': 'CÀI ĐẶT',
    'settingsShort': 'Mở cài đặt',
    'settingsMessage': 'Quyền vị trí đang tắt. Mở cài đặt app và cho phép truy cập vị trí.',
    'sendingLabel': 'ĐANG GỬI',
    'sendingShort': 'Đang gửi vị trí',
    'sendingMessage': 'Đang gửi vị trí mới nhất…',
    'failedLabel': 'LỖI',
    'lastFailedShort': 'Gửi vị trí lỗi',
    'lastFailedMessage': 'Lần gửi GPS cuối thất bại. Hệ thống sẽ tự thử lại.',
    'offlineLabel': 'NGOẠI TUYẾN',
    'waitingNetworkShort': 'Chờ mạng',
    'waitingNetworkMessage': 'Mất kết nối. Vị trí mới nhất đã lưu và sẽ tự gửi lại.',
    'liveLabel': 'LIVE',
    'liveShort': 'Đang theo dõi',
    'liveMessage': 'GPS đang chạy. Điều phối có thể thấy vị trí thành công mới nhất.',
    'offlineMessage': 'Bạn đang ngoại tuyến. Chọn Sẵn sàng để chạy lại GPS.',
    'stoppedLabel': 'ĐÃ DỪNG',
    'stoppedShort': 'GPS đã dừng',
    'stoppedMessage': 'GPS đã dừng. Bắt đầu GPS khi bạn chạy tuyến.',
    'assignedOrders': 'Đơn được giao',
    'noAssignedOrders': 'Chưa có đơn được giao.',
    'askAssignOrder': 'Nhờ điều phối/admin gán đơn cho shipper này.',
    'completeDelivery': 'Hoàn tất giao hàng',
    'receiverName': 'Tên người nhận',
    'receiverNameRequiredLabel': 'Tên người nhận *',
    'deliveryNote': 'Ghi chú giao hàng',
    'deliveryNoteRequiredLabel': 'Ghi chú giao hàng *',
    'paymentMethod': 'Phương thức thanh toán',
    'cash': 'Tiền mặt',
    'bankTransfer': 'Chuyển khoản',
    'wallet': 'Ví điện tử',
    'other': 'Khác',
    'confirmCodCollected': 'Tôi xác nhận đã thu COD',
    'uploadProofPhotoRequired': 'Tải ảnh bằng chứng *',
    'proofSelected': 'Đã chọn bằng chứng',
    'replaceProofPhoto': 'Thay ảnh bằng chứng',
    'receiverNameRequired': 'Bắt buộc nhập tên người nhận.',
    'deliveryNoteRequired': 'Bắt buộc nhập ghi chú giao hàng.',
    'confirmCodBeforeComplete': 'Xác nhận thu COD trước khi hoàn tất giao hàng.',
    'enterCodCollected': 'Nhập số tiền COD đã thu.',
    'proofPhotoRequired': 'Cần ảnh bằng chứng trước khi đánh dấu đã giao.',
    'markDelivered': 'Đánh dấu đã giao',
    'markFailed': 'Đánh dấu thất bại',
    'markReturned': 'Đánh dấu đã hoàn',
    'failedReasonRequired': 'Lý do thất bại *',
    'returnReasonRequired': 'Lý do hoàn hàng *',
    'failedNote': 'Ghi chú thất bại',
    'returnNote': 'Ghi chú hoàn hàng',
    'addReturnNoteOther': 'Nhập ghi chú hoàn hàng khi chọn Khác.',
    'cancel': 'Hủy',
    'proofOfDelivery': 'Bằng chứng giao hàng',
    'upload': 'Tải lên',
    'takePhoto': 'Chụp ảnh',
    'chooseFromGallery': 'Chọn từ thư viện',
    'phoneNotSet': 'Chưa có số điện thoại',
    'pickupAddressNotSet': 'Chưa có địa chỉ lấy hàng',
    'callCustomer': 'Gọi khách',
    'pickupMap': 'Bản đồ lấy hàng',
    'openMap': 'Mở bản đồ',
    'navigate': 'Dẫn đường',
    'codTotal': 'Tổng COD',
    'collected': 'Đã thu',
    'no': 'Không',
    'items': 'Món hàng',
    'weight': 'Khối lượng',
    'proofUploaded': 'Đã tải bằng chứng',
    'packageItems': 'Hàng trong kiện',
    'noSku': 'Không có SKU',
    'updateItem': 'Cập nhật món',
    'markPickedUp': 'Đã lấy hàng',
    'startDelivery': 'Bắt đầu giao',
    'uploadProof': 'Tải bằng chứng',
    'replaceProof': 'Thay bằng chứng',
    'notSet': 'Chưa đặt',
    'pending': 'Đang chờ',
    'assigned': 'Đã gán',
    'pickedUp': 'Đã lấy hàng',
    'inTransit': 'Đang giao',
    'delivered': 'Đã giao',
    'partiallyDelivered': 'Giao một phần',
    'failed': 'Giao thất bại',
    'returned': 'Đã hoàn',
    'cancelled': 'Đã hủy',
    'customerNotAvailable': 'Khách không có mặt',
    'wrongAddress': 'Sai địa chỉ',
    'refusedDelivery': 'Khách từ chối nhận',
    'damagedGoods': 'Hàng bị hỏng',
    'paymentIssue': 'Vấn đề thanh toán',
    'ready': 'Sẵn sàng',
    'offlineConn': 'Ngoại tuyến',
    'waitingRetry': 'Chờ gửi lại',
    'shipperProfileReady': 'Hồ sơ shipper đã sẵn sàng',
    'liveGpsOn': 'GPS trực tiếp đã bật. Điều phối có thể thấy vị trí mới nhất của bạn.',
    'online': 'Trực tuyến',
    'trackingStopped': 'Đã dừng theo dõi.',
    'offlinePaused': 'Bạn đang ngoại tuyến. GPS đang tạm dừng.',
    'sending': 'Đang gửi',
    'sendingLocationUpdate': 'Đang gửi cập nhật vị trí…',
    'locationUpdated': 'Đã cập nhật vị trí thành công.',
    'retryPending': 'Chờ gửi lại',
    'updateFailed': 'Cập nhật thất bại',
    'retrying': 'Đang gửi lại',
    'retryingSavedLocation': 'Đang gửi lại vị trí đã lưu…',
    'savedLocationsSynced': 'Đã đồng bộ các vị trí đã lưu.',
    'someRetriesPending': 'Một số vị trí đã lưu vẫn chờ gửi lại.',
    'gpsOffConn': 'GPS tắt',
    'gpsOffShare': 'GPS đang tắt. Bật Dịch vụ vị trí để chia sẻ tiến độ giao hàng.',
    'permissionNeeded': 'Cần quyền vị trí',
    'permissionDispatch': 'Cần quyền vị trí để điều phối theo dõi tuyến giao hàng.',
    'allowPermission': 'Cho phép quyền vị trí để bắt đầu GPS trực tiếp.',
    'settingsNeeded': 'Cần cài đặt',
    'codCollected': 'Đã thu COD',
  },
};
