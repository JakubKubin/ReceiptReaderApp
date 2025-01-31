// screens/register_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/widgets/custom_button.dart';
import 'package:receipt_reader/widgets/custom_text_field.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/urls.dart';
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;

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

  Future<void> _register() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text;
    final password = _passwordController.text;
    final username = _usernameController.text;
    try {
      final response = await http.post(
        Urls.registerPageUrl,
        body: {
          'email': email,
          'password': password,
          'username': username,
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          setState(() {
            _isLoading = false;
            _passwordController.clear();
            _repeatPasswordController.clear();
          });
          throw TimeoutException('Request timed out');
        },
      );

      if (kDebugMode) print('Register response code: ${response.statusCode}}');
      if (kDebugMode) print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setBool('isLoggedIn', true);
        prefs.setString('accessToken', responseData['access']);
        prefs.setString('refreshToken', responseData['refresh']);
        prefs.setInt('userId', responseData['user']['id']); // Store user ID

        if (!mounted) return;

        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isLoading = false;
          _passwordController.clear();
          _repeatPasswordController.clear();
        });
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['error'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _passwordController.clear();
        _repeatPasswordController.clear();
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
              ? const Center(child: CircularProgressIndicator())
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
                                    controller: _usernameController,
                                    labelText: 'Username',
                                    prefixIcon: const Icon(Icons.person),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your username';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16.0),
                                  CustomTextField(
                                    controller: _emailController,
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email),
                                    keyboardType: TextInputType.emailAddress,
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
                                    prefixIcon: const Icon(Icons.lock),
                                    isPassword: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters long';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16.0),
                                  CustomTextField(
                                    controller: _repeatPasswordController,
                                    labelText: 'Repeat Password',
                                    isPassword: true,
                                    prefixIcon: const Icon(Icons.lock),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24.0),
                                  CustomButton(
                                    onPressed: _register,
                                    text: 'Register',
                                    fontSize: 18,
                                    color: darkViolet,
                                  ),
                                  const SizedBox(height: 12.0),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                          context, '/login');
                                    },
                                    child: const Text(
                                      'Already have an account? Log in',
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
