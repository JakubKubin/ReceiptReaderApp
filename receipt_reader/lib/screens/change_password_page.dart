import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/widgets/custom_text_field.dart';
import 'package:receipt_reader/widgets/custom_button.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  final http.Client client = http.Client();

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

  Future<void> _changePassword() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String? accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await client
          .post(
        Urls.changePasswordUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      )
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          setState(() {
            _isLoading = false;
          });
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ErrorHandler.showError(context, 'Password changed successfully',
            backgroundColor: Colors.green[600]);
        Navigator.pop(context);
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errors = jsonDecode(response.body);
        String errorMessage = errors.values.join('\n');
        throw Exception(errorMessage);
      } else {
        throw Exception('Failed to change password. Try again later.');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                          'Change Password',
                          style: TextStyle(
                            fontSize: 32.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 48.0),
                        // Form Card
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
                                    controller: _currentPasswordController,
                                    labelText: 'Current Password',
                                    isPassword: true,
                                    prefixIcon: const Icon(Icons.lock),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your current password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16.0),
                                  CustomTextField(
                                    controller: _newPasswordController,
                                    labelText: 'New Password',
                                    isPassword: true,
                                    prefixIcon: const Icon(Icons.lock),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a new password';
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
                                        return 'Please confirm your password';
                                      }
                                      if (value !=
                                          _newPasswordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24.0),
                                  CustomButton(
                                    onPressed: _changePassword,
                                    text: 'Change Password',
                                    fontSize: 18,
                                    color: darkViolet,
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
