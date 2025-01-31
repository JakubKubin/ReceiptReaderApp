// services/auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/urls.dart';

class AuthService {
  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Urls.loginPageUrl,
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setBool('isLoggedIn', true);
        prefs.setString('accessToken', responseData['access']);
        prefs.setString('refreshToken', responseData['refresh']);
        prefs.setInt('userId', responseData['user']['id']);
      } else {
        throw Exception('Login failed. Check your email or password.');
      }
    } on SocketException {
      throw Exception('No Internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred.');
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<int?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }
}
