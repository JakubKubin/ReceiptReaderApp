// screens/settings_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  Client client = http.Client();

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _handleError(dynamic e) {
    if (kDebugMode) print(e);
    if (mounted) {
      if (e is TimeoutException) {
        ErrorHandler.showError(context, 'Request timed out. Please try again.');
      } else if (e is http.ClientException) {
        ErrorHandler.showError(context, 'Could not fetch server response.');
      } else if (e is SocketException) {
        ErrorHandler.showError(context, 'Connection error. Please try again.');
      } else {
        ErrorHandler.showError(context, 'An error occurred. Please try again.');
      }
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isLogged = prefs.getBool('isLoggedIn');
    String? accessToken = prefs.getString('accessToken');
    String? refreshToken = prefs.getString('refreshToken');
    if (!isLogged!) {
      _navigateToLogin();
    }

    if (refreshToken != null) {
      try {
        final response = await client.post(
          Urls.logOutPageUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'ngrok-skip-browser-warning': '69420'
          },
          body: {
            'refresh': refreshToken,
          },
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            setState(() {
              _isLoading = false;
            });
            throw TimeoutException(
                'The connection has timed out, Please try again!');
          },
        );

        if (response.statusCode == 200) {
          await prefs.remove('accessToken');
          await prefs.remove('refreshToken');
          await prefs.remove('userId');
          prefs.setBool('isLoggedIn', false);
          setState(() {
            _isLoading = false;
          });
          _navigateToLogin();
        } else if (response.statusCode == 401) {
          await _authService.getAccessToken();
          _logout();
        } else {
          final responseData = json.decode(response.body);
          if (responseData['error'] == 'invalid_grant') {
            await prefs.remove('accessToken');
            await prefs.remove('refreshToken');
            await prefs.remove('userId');
            prefs.setBool('isLoggedIn', false);
            _navigateToLogin();
          } else {
            throw Exception('Invalid server status: ${responseData['error']}');
          }
        }
      } catch (e) {
        _handleError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 48.0),
                        Card(
                          elevation: 8.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person),
                                  title: const Text('Account'),
                                  onTap: () {},
                                ),
                                Divider(color: Colors.grey[300]),
                                ListTile(
                                  leading: const Icon(Icons.lock),
                                  title: const Text('Change Password'),
                                  onTap: () {
                                    Navigator.pushNamed(
                                        context, '/change_password');
                                  },
                                ),
                                Divider(color: Colors.grey[300]),
                                ListTile(
                                  leading: const Icon(Icons.notifications),
                                  title: const Text('Notifications'),
                                  onTap: () {},
                                ),
                                Divider(color: Colors.grey[300]),
                                ListTile(
                                  leading: const Icon(Icons.language),
                                  title: const Text('Language'),
                                  onTap: () {},
                                ),
                                Divider(color: Colors.grey[300]),
                                const SizedBox(height: 24.0),
                                ElevatedButton(
                                  onPressed: _logout,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    backgroundColor: strongViolet,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Logout',
                                    style:
                                        TextStyle(fontSize: 18.0, color: white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
