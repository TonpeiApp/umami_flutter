import 'dart:async'; // Keep for Future
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

typedef UmamiEventData = Map<String, dynamic>;

class Umami {
  static final Umami _instance = Umami._internal();
  factory Umami() => _instance;
  Umami._internal();

  late final String? _endpoint;
  late final String? _websiteId;

  /// Optionally set params if needed.
  String? _hostname;
  String? _tag;

  // Dynamically overrided value
  String? _url;
  String? _title;
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

  Map<String, dynamic> _getPayload() {
    if (_endpoint == null || _websiteId == null) {
      throw Exception("Umami().init(...) before tracking pageview")
    }
    final payload = <String, dynamic>{
      'website': _websiteId,
      'screen': _screenSize,
      'language': _language,
      if (_title != null) 'title': _title,
      if (_hostname != null) 'hostname': _hostname,
      'url': _url,
      if (_referrer != null) 'referrer': _referrer,
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
    await http.post(
      Uri.parse('$_endpoint/api/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'event',
        'payload': payload,
      }),
    );
  }

  /// Track a custom event.
  Future<void> trackEvent(String name, {UmamiEventData? data}) async {
    if (_endpoint == null || _websiteId == null) return;
    final payload = <String, dynamic>{
      ..._getPayload(),
      'name': name,
      if (data != null) 'data': data,
    };
    debugPrint('Umami trackEvent payload: $payload'); // Changed debugPrint for clarity
    await http.post(
      Uri.parse('$_endpoint/api/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'event',
        'payload': payload,
      }),
    );
  }
}
