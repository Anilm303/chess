import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class FriendService extends ChangeNotifier {
  List<Map<String, dynamic>> _contacts = [];
  List<String> _requests = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get contacts => _contacts;
  List<String> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isFriend(String username) {
    return _contacts.any((c) => c['username']?.toString() == username);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  Future<bool> fetchContacts(String accessToken) async {
    _setLoading(true);
    _error = null;
    try {
      final url = '${ApiService.baseUrl}/friends/contacts';
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiService.timeout);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        _contacts = (j['friends'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _setLoading(false);
        return true;
      }
      _error = resp.body;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
    return false;
  }

  Future<bool> fetchRequests(String accessToken) async {
    _setLoading(true);
    _error = null;
    try {
      final url = '${ApiService.baseUrl}/friends/requests';
      final resp = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(ApiService.timeout);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body);
        _requests = (j['requests'] as List).map((e) => e.toString()).toList();
        _setLoading(false);
        return true;
      }
      _error = resp.body;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
    return false;
  }

  Future<bool> sendRequest(String accessToken, String username) async {
    _setLoading(true);
    _error = null;
    try {
      final url = '${ApiService.baseUrl}/friends/request';
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': username}),
          )
          .timeout(ApiService.timeout);
      if (resp.statusCode == 200) {
        _setLoading(false);
        return true;
      }
      if (resp.statusCode == 400) {
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final message = body['message']?.toString() ?? '';
          if (message == 'Request already sent') {
            _error = null;
            _setLoading(false);
            return true;
          }
        } catch (_) {}
      }
      _error = resp.body;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
    return false;
  }

  Future<bool> respondRequest(
    String accessToken,
    String username,
    bool accept,
  ) async {
    _setLoading(true);
    _error = null;
    try {
      final url = '${ApiService.baseUrl}/friends/respond';
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': username, 'accept': accept}),
          )
          .timeout(ApiService.timeout);
      if (resp.statusCode == 200) {
        // refresh lists
        await fetchContacts(accessToken);
        await fetchRequests(accessToken);
        _setLoading(false);
        return true;
      }
      _error = resp.body;
    } catch (e) {
      _error = e.toString();
    }
    _setLoading(false);
    return false;
  }
}
