// screens/login_page.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/widgets/custom_button.dart';
import 'package:receipt_reader/widgets/custom_text_field.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:receipt_reader/widgets/loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/utils/urls.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHost();
  }

  Future<void> _loadHost() async {
    setState(() {
      _hostController.text = Urls.host;
    });
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

  Future<void> _login(bool isForced) async {
    if (!isForced) {
      if (_formKey.currentState?.validate() != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    Urls.host = _hostController.text;

    final String email;
    final String password;
    if (isForced) {
      email = 'test@g.com';
      password = 'Test2137';
    } else {
      email = _emailController.text;
      password = _passwordController.text;
    }

    try {
      final response = await http.post(
        Urls.loginPageUrl,
        headers: {'ngrok-skip-browser-warning': '69420'},
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          setState(() {
            _isLoading = false;
            _passwordController.clear();
          });
          throw TimeoutException('Timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setBool('isLoggedIn', true);
        prefs.setString('accessToken', responseData['access']);
        prefs.setString('refreshToken', responseData['refresh']);
        prefs.setInt('userId', responseData['user']['id']);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isLoading = false;
          _passwordController.clear();
        });
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(
            responseData['error'] ?? 'Login failed. Please try again');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _passwordController.clear();
      });
      _handleError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          _isLoading
              ? const LoadingIndicator()
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 48.0),
                        const Text(
                          'Receipt Reader',
                          style: TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 48.0),
                        Card(
                          elevation: 8.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CustomTextField(
                                    labelText: "Email",
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(Icons.email),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                          .hasMatch(value)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16.0),
                                  CustomTextField(
                                    controller: _passwordController,
                                    labelText: 'Password',
                                    isPassword: true,
                                    prefixIcon: const Icon(Icons.lock),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24.0),
                                  CustomButton(
                                      onPressed: () => _login(false),
                                      color: strongViolet,
                                      text: 'Login'),
                                  const SizedBox(height: 24.0),
                                  CustomButton(
                                      onPressed: () => _login(true),
                                      color: strongViolet,
                                      text: 'Test Login'),
                                  const SizedBox(height: 12.0),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                          context, '/register');
                                    },
                                    child: const Text(
                                      "Don't have an account? Register",
                                      style: TextStyle(
                                          fontSize: 16.0, color: strongViolet),
                                    ),
                                  ),
                                ],
                              ),
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
