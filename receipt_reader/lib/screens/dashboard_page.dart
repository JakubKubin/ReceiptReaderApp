// screens/dashboard_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/urls.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  Client client = http.Client();
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    bool? isLogged = prefs.getBool('isLoggedIn');

    if (!isLogged!) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
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
          if (kDebugMode) print('Timeout');
          return Future.error(TimeoutException('Request timed out.'));
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
          _isLoading = false;
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
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          if (!mounted) return;
          ErrorHandler.showError(
              context, 'Invalid server status: ${responseData['error']}');
        }
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) print(e);
      if (!mounted) return;
      ErrorHandler.showError(context, 'Request timed out. Please try again');
    } on ClientException catch (e) {
      if (kDebugMode) print(e);
      if (!mounted) return;
      ErrorHandler.showError(context, 'Could not load profile data');
    } catch (e) {
      if (kDebugMode) print(e);
      if (!mounted) return;
      ErrorHandler.showError(context, 'An error occurred. Please try again');
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
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(
                  child: Text('Failed to load profile data'),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Email'),
                        subtitle: Text(_userData!['email']),
                      ),
                      ListTile(
                        title: const Text('Username'),
                        subtitle: Text(_userData!['username']),
                      ),
                    ],
                  ),
                ),
    );
  }
}
