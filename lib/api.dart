import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Same host as the web dashboard: it proxies /api/* to the AgriSense server, so no extra URL is needed.
const kBase = 'https://agrisense-1-0.onrender.com';
const kSiteKey = '0x4AAAAAAFPyh2X1GS8e-smM'; // public Cloudflare Turnstile key, same as the web app

class ApiError implements Exception {
  ApiError(this.status, this.message, [this.data = const {}]);
  final int status;
  final String message;
  final Map<String, dynamic> data;
  @override
  String toString() => message;
}

class Reading {
  Reading({this.temp, this.hum, this.soil, required this.online, required this.soilFault, this.updatedAt, this.dry = 40, required this.fetchedAt});
  final double? temp, hum, soil;
  final bool online, soilFault;
  final DateTime? updatedAt;
  final int dry;
  final DateTime fetchedAt;

  String get soilState {
    if (soilFault) return 'Sensor fault';
    if (soil == null) return 'No reading';
    if (soil! < dry) return 'Dry';
    if (soil! > 75) return 'Wet';
    return 'Comfortable';
  }
}

/// Session tokens live in native storage so the widget and the live service can use (and refresh) the same session.
class Api {
  static const _ch = MethodChannel('agrisense/widget');

  static Future<Map<String, String>?> _session() async {
    final m = await _ch.invokeMethod<Map<dynamic, dynamic>>('getSession');
    if (m == null) return null;
    return {for (final e in m.entries) e.key as String: (e.value ?? '') as String};
  }

  static Future<bool> hasSession() async => (await _session()) != null;

  static Future<Map<String, dynamic>> _raw(String path, {String method = 'GET', Map<String, dynamic>? body, String? token}) async {
    final uri = Uri.parse('$kBase$path');
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json', if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'};
    try {
      final res = method == 'POST'
          ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 50))
          : await http.get(uri, headers: headers).timeout(const Duration(seconds: 50));
      Map<String, dynamic> data = {};
      try {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {}
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiError(res.statusCode, (data['error'] as String?) ?? 'request failed', data);
      }
      return data;
    } on ApiError {
      rethrow;
    } on TimeoutException {
      throw ApiError(0, 'The server took too long to answer. It may be waking up, try again.');
    } catch (_) {
      throw ApiError(0, 'Cannot reach the server.');
    }
  }

  static Future<void> login(String email, String password, String captcha) async {
    final s = await _raw('/api/auth/login', method: 'POST', body: {'email': email.trim(), 'password': password, 'captcha': captcha});
    await _ch.invokeMethod('saveSession', {
      'access': s['access_token'],
      'refresh': s['refresh_token'],
      'email': (s['user'] as Map?)?['email'] ?? email.trim(),
    });
  }

  static Future<void> logout() async {
    final s = await _session();
    if (s != null) {
      try {
        await _raw('/api/auth/logout', method: 'POST', token: s['access']);
      } catch (_) {}
    }
    await _ch.invokeMethod('clearSession');
  }

  static Future<bool> _refresh(String usedAccess) async {
    final s = await _session(); // the widget may have refreshed already
    if (s == null) return false;
    if (s['access']!.isNotEmpty && s['access'] != usedAccess) return true;
    if (s['refresh']!.isEmpty) return false;
    try {
      final r = await _raw('/api/auth/refresh', method: 'POST', body: {'refresh_token': s['refresh']});
      await _ch.invokeMethod('saveSession', {
        'access': r['access_token'],
        'refresh': r['refresh_token'],
        'email': (r['user'] as Map?)?['email'] ?? s['email'],
      });
      return true;
    } on ApiError catch (e) {
      if (e.status == 401 || e.status == 403) await _ch.invokeMethod('clearSession');
      return false;
    }
  }

  static double? _d(dynamic v) => v is num ? v.toDouble() : null;

  /// Latest readings (same endpoint the web dashboard polls). Also hands them to the widget.
  static Future<Reading> status() async {
    var s = await _session();
    if (s == null) throw ApiError(401, 'signed out');
    Map<String, dynamic> j;
    try {
      j = await _raw('/api/status', token: s['access']);
    } on ApiError catch (e) {
      if (e.status != 401) {
        if (e.status == 0) _ch.invokeMethod('markOffline').catchError((_) {});
        rethrow;
      }
      if (!await _refresh(s['access'] ?? '')) throw ApiError(401, 'signed out');
      s = await _session();
      if (s == null) throw ApiError(401, 'signed out');
      j = await _raw('/api/status', token: s['access']);
    }

    final t = j['telemetry'] as Map<String, dynamic>?;
    final dry = ((j['settings'] as Map?)?['soil_dry_pct'] as num?)?.toInt() ?? 40;
    final r = Reading(
      temp: _d(t?['temp_c']),
      hum: _d(t?['humidity']),
      soil: _d(t?['soil_pct']),
      online: j['online'] == true,
      soilFault: t?['soil_fault'] == true,
      updatedAt: t?['updated_at'] is String ? DateTime.tryParse(t!['updated_at'] as String)?.toLocal() : null,
      dry: dry,
      fetchedAt: DateTime.now(),
    );
    // same shape the native side stores
    _ch.invokeMethod('pushReading', {
      'json': jsonEncode({
        'temp': r.temp,
        'hum': r.hum,
        'soil': r.soil,
        'online': r.online,
        'soil_fault': r.soilFault,
        'dry': r.dry,
        'updated_at': t?['updated_at'],
      }),
    }).catchError((_) {});
    return r;
  }

  // ---- widget helpers ----
  static Future<bool> isLive() async => (await _ch.invokeMethod<bool>('isLive')) ?? true;
  static Future<void> setLive(bool on) => _ch.invokeMethod('setLive', {'on': on});
  static Future<String> diagnose() async => (await _ch.invokeMethod<String>('diagnose')) ?? 'no result';
  static Future<int> widgetCount() async => (await _ch.invokeMethod<int>('widgetCount')) ?? 0;
  static Future<bool> pinWidget() async => (await _ch.invokeMethod<bool>('pinWidget')) ?? false;
}
