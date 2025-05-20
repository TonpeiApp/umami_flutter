import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

typedef UmamiEventData = Map<String, dynamic>;

class Umami {
  static final Umami _instance = Umami._internal();
  factory Umami() => _instance;
  Umami._internal();

  String? _endpoint;
  String? _websiteId;

  /// Optionally set hostname/referrer if needed.
  String? _hostname;
  String? _referrer;

  void setHostname(String hostname) => _hostname = hostname;
  void setReferrer(String referrer) => _referrer = referrer;

  /// Initialize Umami SDK.
  void init({
    required String endpoint,
    required String websiteId,
    String? hostname,
    String? referrer,
  }) {
    _endpoint = endpoint;
    _websiteId = websiteId;
    _hostname = hostname;
    _referrer = referrer;
  }

  /// Get current screen size as "widthxheight"
  String get _screenSize {
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return '${size.width.round()}x${size.height.round()}';
  }

  /// Get current locale/language
  String get _language {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.toLanguageTag();
  }

  /// Track a pageview (called automatically if using [UmamiRouteObserver]).
  Future<void> trackPageView(String url) async {
    if (_endpoint == null || _websiteId == null) return;
    final payload = <String, dynamic>{
      'website': _websiteId,
      'url': url,
      'screen': _screenSize,
      'language': _language,
      if (_referrer != null) 'referrer': _referrer,
      if (_hostname != null) 'hostname': _hostname,
    };
    await http.post(
      Uri.parse('$_endpoint/api/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'pageview',
        'payload': payload,
      }),
    );
  }

  /// Track a custom event.
  Future<void> trackEvent(String name, {String? title, UmamiEventData? data, String? url}) async {
    if (_endpoint == null || _websiteId == null) return;
    final payload = <String, dynamic>{
      'website': _websiteId,
      'name': name,
      if (title != null) 'title': title,
      if (url != null) 'url': url,
      'screen': _screenSize,
      'language': _language,
      if (_referrer != null) 'referrer': _referrer,
      if (_hostname != null) 'hostname': _hostname,
      if (data != null) 'data': data,
    };
    await http.post(
      Uri.parse('$_endpoint/api/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'event',
        'payload': payload,
      }),
    );
  }

  /// Navigator observer for automatic pageview tracking.
  NavigatorObserver get goRouterObserver => UmamiRouteObserver(this);
}

/// GoRouter observer to track page views automatically.
class UmamiRouteObserver extends NavigatorObserver {
  final Umami _umami;
  UmamiRouteObserver(this._umami);

  @override
  void didPush(Route route, Route? previousRoute) {
    final uri = route.settings.name ?? route.settings.arguments?.toString() ?? '';
    if (uri.isNotEmpty) {
      _umami.trackPageView(uri);
    }
    super.didPush(route, previousRoute);
  }
}
