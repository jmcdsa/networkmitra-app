import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Address of your NetworkMitra server.
const String kBase = 'https://networkmitra.ftc4u.store/api/v1';

class ApiException implements Exception {
  final String message;
  final String code;
  final int status;
  ApiException(this.message, {this.code = 'error', this.status = 0});
  @override
  String toString() => message;
}

class Api {
  static String? token;
  static Map<String, dynamic>? user;
  static Map<String, dynamic>? plan;
  static void Function()? onUnauthorized;
  static void Function(String message)? onUpgrade;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
  }

  static Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  static Future<dynamic> call(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query}) async {
    var uri = Uri.parse('$kBase/$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = token;
    if (t != null) {
      headers['Authorization'] = 'Bearer $t';
      headers['X-Auth-Token'] = t;
    }
    http.Response r;
    try {
      final enc = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: headers, body: enc ?? '{}');
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: enc ?? '{}');
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers);
          break;
        default:
          r = await http.get(uri, headers: headers);
      }
    } catch (_) {
      throw ApiException('No internet connection. Please try again.', code: 'network');
    }
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('The server did not answer properly (${r.statusCode}).', status: r.statusCode);
    }
    if (j is Map && j['ok'] == true) {
      return j['data'];
    }
    final msg = (j is Map && j['error'] != null) ? j['error'].toString() : 'Something went wrong.';
    final code = (j is Map && j['code'] != null) ? j['code'].toString() : 'error';
    if (r.statusCode == 401) {
      await setToken(null);
      final cb = onUnauthorized;
      if (cb != null) cb();
    }
    if (r.statusCode == 402) {
      final cb = onUpgrade;
      if (cb != null) cb(msg);
    }
    throw ApiException(msg, code: code, status: r.statusCode);
  }

  static Future<dynamic> upload(String path, String field, String filePath, {Map<String, String>? fields}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kBase/$path'));
    final t = token;
    if (t != null) {
      req.headers['Authorization'] = 'Bearer $t';
      req.headers['X-Auth-Token'] = t;
    }
    req.headers['Accept'] = 'application/json';
    if (fields != null) req.fields.addAll(fields);
    req.files.add(await http.MultipartFile.fromPath(field, filePath));
    http.Response r;
    try {
      r = await http.Response.fromStream(await req.send());
    } catch (_) {
      throw ApiException('No internet connection. Please try again.', code: 'network');
    }
    dynamic j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('The server did not answer properly (${r.statusCode}).', status: r.statusCode);
    }
    if (j is Map && j['ok'] == true) return j['data'];
    final msg = (j is Map && j['error'] != null) ? j['error'].toString() : 'Something went wrong.';
    if (r.statusCode == 402) {
      final cb = onUpgrade;
      if (cb != null) cb(msg);
    }
    throw ApiException(msg, status: r.statusCode);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) => call('GET', path, query: query);
  static Future<dynamic> post(String path, Map<String, dynamic> body) => call('POST', path, body: body);
  static Future<dynamic> put(String path, Map<String, dynamic> body) => call('PUT', path, body: body);
  static Future<dynamic> delete(String path) => call('DELETE', path);

  static Future<void> refreshMe() async {
    final d = await get('me');
    user = Map<String, dynamic>.from(d['user'] as Map);
    plan = Map<String, dynamic>.from(d['plan'] as Map);
  }
}
