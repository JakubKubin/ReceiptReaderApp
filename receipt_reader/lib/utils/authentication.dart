// utils/authentication.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/utils/urls.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Urls.loginPageUrl,
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return Future.error(TimeoutException('Login request timed out.'));
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setBool('isLoggedIn', true);
        prefs.setString('accessToken', responseData['access']);
        prefs.setString('refreshToken', responseData['refresh']);
        prefs.setInt('userId', responseData['user']['id']);
      } else if (response.statusCode == 404) {
        throw Future.error(Exception('Check email or password'));
      } else {
        throw Future.error(Exception('Unexpected server response'));
      }
    } on SocketException {
      return Future.error(Exception('No Internet connection'));
    } on HttpException {
      return Future.error(Exception('HTTP Exception'));
    } on FormatException {
      return Future.error(Exception('Format Exception'));
    } on Exception {
      return Future.error(Exception('Could not log in'));
    }
  }

  Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accessToken');
    String? refreshToken = prefs.getString('refreshToken');

    if (accessToken != null && !isTokenExpired(accessToken)) {
      return accessToken;
    } else if (refreshToken != null && !isTokenExpired(refreshToken)) {
      final newAccessToken = await refreshAccessToken(refreshToken);
      if (newAccessToken != null) {
        await prefs.setString('accessToken', newAccessToken);
        if (kDebugMode) print('Using new access token: $newAccessToken');
        return newAccessToken;
      }
    }
    if (kDebugMode) print('No valid tokens available');
    return null;
  }

  bool isTokenExpired(String token) {
    try {
      final payload = json.decode(
          utf8.decode(base64.decode(base64.normalize(token.split('.')[1]))));
      final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      return false;
    }
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
    final response = await http.post(
      Urls.refreshTokenUrl,
      body: {
        'refresh': refreshToken,
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['access'];
    } else {
      if (kDebugMode) {
        print('Failed to refresh access token: ${response.statusCode}');
      }
    }
    return null;
  }
}
