// screens/receipt_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/screens/edit_receipt_page.dart';
import 'package:receipt_reader/services/receipt_service.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/models/receipt.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/media_query_values.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:receipt_reader/widgets/pick_src_float_action_btn.dart';
import 'package:receipt_reader/widgets/receipt_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  List<Receipt> receipts = [];
  final http.Client client = http.Client();

  @override
  void initState() {
    super.initState();
    _retrieveReceipts();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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

  Future<void> _retrieveReceipts() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLogged = prefs.getBool('isLoggedIn') ?? false;

    if (!isLogged) {
      _navigateToLogin();
      return;
    }

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      _navigateToLogin();
      return;
    }

    final userId = prefs.getInt('userId');

    try {
      final response =
          await ReceiptService(client).fetchReceipts(accessToken, userId!);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> receiptsData = responseData['receipts'];
        final List<Receipt> loadedReceipts = receiptsData.map((receiptData) {
          return Receipt.fromJson(receiptData);
        }).toList();

        setState(() {
          receipts = loadedReceipts;
        });
      } else if (response.statusCode == 401) {
        await _authService.getAccessToken();
        _retrieveReceipts();
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
          throw Exception(responseData['error'] ?? 'Failed to fetch receipts');
        }
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deleteReceipt(int receiptId) async {
    setState(() {
      _isLoading = true;
    });
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      _navigateToLogin();
      return;
    }

    try {
      final response =
          await ReceiptService(client).deleteReceipt(accessToken, receiptId);

      if (response.statusCode == 204) {
        setState(() {
          receipts.removeWhere((receipt) => receipt.id == receiptId);
        });
      } else {
        throw Exception('Failed to delete receipt');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToEditReceiptPage(int receiptId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (context) => EditReceiptPage(
                    receiptId: receiptId,
                  )),
        )
        .then((value) => _retrieveReceipts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          const GradientBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    _retrieveReceipts();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: context.height / 20),
                        receipts.isEmpty
                            ? Column(
                                children: [
                                  SizedBox(height: context.height / 2.5),
                                  Center(
                                    child: Text(
                                      'Add a receipt to get started',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: context.height / 40),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: EdgeInsets.only(
                                  right: context.width / 40,
                                  left: context.width / 40,
                                  top: context.height / 90,
                                  bottom: 0,
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: receipts.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return ReceiptCard(
                                    receipt: receipts[index],
                                    onDelete: () =>
                                        _deleteReceipt(receipts[index].id),
                                    onEdit: () => _navigateToEditReceiptPage(
                                        receipts[index].id),
                                  );
                                },
                              ),
                        SizedBox(height: context.height / 11),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: lightViolet.withOpacity(0.7),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: PickSourceFloatingActionButton(
            context: context,
            authService: _authService,
            client: client,
            onPressed: () {
              setState(() => _isLoading = true);
            },
            stopLoading: () {
              setState(() => _isLoading = false);
            },
            onNavigateToEditReceiptPage: (int receiptId) {
              _navigateToEditReceiptPage(receiptId);
            },
          )),
    );
  }
}
