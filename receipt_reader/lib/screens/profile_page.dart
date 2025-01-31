// screens/profile_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/urls.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  Client client = http.Client();
  Map<String, dynamic>? _userData;
  double _totalSpent = 0.0;
  int _receiptCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

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

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    bool? isLogged = prefs.getBool('isLoggedIn');

    if (!isLogged!) {
      _navigateToLogin();
    }

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      _navigateToLogin();
      return;
    }

    try {
      final response = await client.get(
        Urls.getUserDataUrl(userId!),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          setState(() {
            _isLoading = false;
          });
          throw TimeoutException('Request timed out.');
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
          _isLoading = false;

          if (_userData != null && _userData!.containsKey('receipts')) {
            List<dynamic> receipts = _userData!['receipts'];
            _receiptCount = receipts.length;
            _totalSpent = receipts.fold(0.0, (sum, item) {
              double total = 0.0;
              if (item['total'] != null) {
                total = double.tryParse(item['total'].toString()) ?? 0.0;
              }
              return sum + total;
            });
          } else {
            _receiptCount = 0;
            _totalSpent = 0.0;
          }
        });
      } else if (response.statusCode == 401) {
        await _authService.getAccessToken();
        _fetchUserData();
      } else {
        final responseData = json.decode(response.body);
        if (responseData['error'] == 'invalid_grant') {
          await prefs.remove('accessToken');
          await prefs.remove('refreshToken');
          await prefs.remove('userId');
          prefs.setBool('isLoggedIn', false);
          _navigateToLogin();
          throw Exception('Token expired');
        } else {
          throw Exception('Invalid server status: ${responseData['error']}');
        }
      }
    } catch (e) {
      _handleError(e);
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userData == null
                  ? const Center(
                      child: Text(
                        'Failed to load profile data',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 64.0),
                          Text(
                            _userData!['username'],
                            style: const TextStyle(
                              fontSize: 28.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _userData!['email'],
                            style: const TextStyle(
                              fontSize: 18.0,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 32.0),
                          Card(
                            elevation: 8.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.attach_money),
                                    title: const Text('Total Money Spent'),
                                    subtitle: Text(
                                      'zł ${_totalSpent.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16.0),
                                    ),
                                  ),
                                  Divider(color: Colors.grey[300]),
                                  ListTile(
                                    leading: const Icon(Icons.receipt_long),
                                    title: const Text('Number of Receipts'),
                                    subtitle: Text(
                                      '$_receiptCount',
                                      style: const TextStyle(fontSize: 16.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ],
      ),
    );
  }
}
