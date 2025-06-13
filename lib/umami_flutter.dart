import 'dart:async'; // Keep for Future
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef UmamiEventData = Map<String, dynamic>;

class Umami {
  static final Umami _instance = Umami._internal();
  factory Umami() => _instance;
  Umami._internal();

  late final String? _endpoint;
  late final String? _websiteId;

  /// Optionally set params if needed.
  String? _hostname;
  String? tag;

  // Dynamically overrided value
  String? _url;
  String? _title;
  String? _referrer;
  String? _id;

  void setHostname(String hostname) => _hostname = hostname;
  void setReferrer(String referrer) => _referrer = referrer;

  /// Initialize Umami SDK.
  void init({
    required String endpoint,
    required String websiteId,
    String? hostname,
  }) {
    _endpoint = endpoint;
    _websiteId = websiteId;
    _hostname = hostname;
  }

  Future<String> get _userAgent async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webBrowserInfo = await deviceInfo.webBrowserInfo;
        return webBrowserInfo.userAgent ?? 'unknown';
      }

      final platformInfo = await deviceInfo.deviceInfo;
      final packageInfo = await PackageInfo.fromPlatform();

      if (platformInfo is AndroidDeviceInfo) {
        return '${packageInfo.appName}/${packageInfo.version} (Linux; Android ${platformInfo.version.release}; ${platformInfo.model})';
      } else if (platformInfo is IosDeviceInfo) {
        return '${packageInfo.appName}/${packageInfo.version} (iPhone; CPU iPhone OS ${platformInfo.systemVersion.replaceAll('_', '.')})';
      } else {
        return '${packageInfo.appName}/${packageInfo.version} (${platformInfo.runtimeType})';
      }
    } catch (e) {
      debugPrint('Error getting user agent: $e');
      return 'unknown';
    }
  }

  /// Get current screen size as "widthxheight"
  String get _screenSize {
    final size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return '${size.width.round()}x${size.height.round()}';
  }

  /// Get current locale/language
  String get _language {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.toLanguageTag();
  }

  void identify(String id) {
    _id = id;
    _sendIdendity({'data': _id});
  }

  UmamiEventData _getPayload() {
    if (_endpoint == null || _websiteId == null) {
      throw Exception("Umami().init(...) before tracking pageview");
    }
    final UmamiEventData payload = <String, dynamic>{
      'website': _websiteId,
      'screen': _screenSize,
      'language': _language,
      if (_title != null) 'title': _title,
      if (_hostname != null) 'hostname': _hostname,
      'url': _url,
      if (_referrer != null) 'referrer': _referrer,
      if (tag != null) 'tag': tag,
      if (_id != null) 'id': _id,
    };
    return payload;
  }

  /// Track a pageview.
  Future<void> trackPageView(String url, String? title) async {
    _url = url;
    _title = title;
    final payload = _getPayload();
    debugPrint('Umami has recorded pageview with payload: $payload');
    _referrer = url;
    _sendEvent(payload);
  }

  /// Track a custom event.
  Future<void> trackEvent(String name, {UmamiEventData? data}) async {
    if (_endpoint == null || _websiteId == null) return;
    final UmamiEventData payload = <String, dynamic>{
      ..._getPayload(),
      'name': name,
      if (data != null) 'data': data,
    };
    debugPrint('Umami trackEvent payload: $payload');
    _sendEvent(payload);
  }

  Future<void> _sendIdendity(UmamiEventData payload) =>
      _send(payload, 'identify');

  Future<void> _sendEvent(UmamiEventData payload) => _send(payload, 'event');

  Future<void> _send(UmamiEventData payload, String type) async {
    await http.post(
      Uri.parse('$_endpoint/api/send'),
      headers: {
        'Content-Type': 'application/json',
        'user-agent': await _userAgent,
      },
      body: jsonEncode({'type': type, 'payload': payload}),
    );
  }
}

class UmamiRouteListener {
  final Umami _umami;
  UmamiRouteListener(this._umami);

  //put this method in router.dart to register the listener
  void registerRouter(GoRouter? router) {
    if (router == null) {
      debugPrint(
        "UMAMI: No router provided, skipping route listener registration.",
      );
      return;
    }

    router.routerDelegate.addListener(() {
      final currentRoute = router.routerDelegate.currentConfiguration.last;
      final url = currentRoute.matchedLocation;
      final routeName = currentRoute.route.name ?? url;

      debugPrint("routeMatch: $routeName, url: $url");
      _trackRouteChange(url, routeName);
    });
    debugPrint("UMAMI: Registered route listener for router: $router");
  }

  void _trackRouteChange(String url, String title) {
    debugPrint("UMAMI: Tracking route change: $url with name $title");
    _umami.trackPageView(url, title);
  }
}
