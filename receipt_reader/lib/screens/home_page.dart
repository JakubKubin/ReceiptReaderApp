// screens/home_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/dashboard/receipt_statistic_widget.dart';
import 'package:receipt_reader/models/chart_data.dart';
import 'package:receipt_reader/services/receipt_service.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/media_query_values.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';
import 'package:receipt_reader/widgets/pick_src_float_action_btn.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/models/receipt.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:receipt_reader/screens/edit_receipt_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  final AuthService _authService = AuthService();
  final http.Client client = http.Client();
  List<Receipt> receipts = [];
  int totalReceipts = 0;
  double totalSpent = 0.0;
  List<ChartData> receiptsOverTime = [];
  Map<String, dynamic> _userSummary = {};

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _retrieveReceipts().then((_) => _fetchSummary());
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

  Future<Map<String, dynamic>> fetchUserSummary() async {
    final accessToken = await AuthService().getAccessToken();
    if (accessToken == null) {
      _navigateToLogin();
      return {};
    }

    try {
      final response = await http.get(
        Urls.getUserSummaryUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          "ngrok-skip-browser-warning": "69420",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        await _authService.getAccessToken();
        return fetchUserSummary();
      } else {
        throw Exception('Failed to load user summary');
      }
    } catch (e) {
      throw Exception('An error occurred');
    }
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await fetchUserSummary();
      setState(() {
        _userSummary = summary;
      });
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<ChartData> _calculateReceiptsOverTime(List<Receipt> receipts) {
    receipts.sort((a, b) {
      DateTime dateA = DateTime.parse(a.date);
      DateTime dateB = DateTime.parse(b.date);
      return dateA.compareTo(dateB);
    });

    double cumulativeTotal = 0.0;
    List<ChartData> data = [];

    for (var receipt in receipts) {
      DateTime date = DateTime.parse(receipt.date);
      double total = double.tryParse(receipt.total) ?? 0.0;
      cumulativeTotal += total;
      data.add(ChartData(
        date: date.millisecondsSinceEpoch.toDouble(),
        total: double.tryParse(cumulativeTotal.toStringAsFixed(2)) ?? 0.0,
        count: 1,
      ));
    }
    return data;
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
          receiptsOverTime = _calculateReceiptsOverTime(receipts);

          totalReceipts = receipts.length;

          totalSpent = receipts.fold(
            0.0,
            (sum, item) => sum + (double.tryParse(item.total) ?? 0.0),
          );
          _isLoading = false;
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
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
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
  void dispose() {
    client.close();
    super.dispose();
  }

  final Map<String, IconData> categoryIcons = {
    'Uncategorized': Icons.category,
    'Groceries': Icons.shopping_cart,
    'Veggies': FontAwesomeIcons.carrot,
    'Fruits': FontAwesomeIcons.raspberryPi,
    'Meat': FontAwesomeIcons.drumstickBite,
    'Dairy': FontAwesomeIcons.cheese,
    'Bakery': FontAwesomeIcons.cookieBite,
    'Beverages': FontAwesomeIcons.glassWater,
    'Clothing': Icons.checkroom,
    'Gas': Icons.local_gas_station,
    'Health': Icons.local_hospital,
  };

  Widget _buildCategoryDashboards() {
    if (receipts.isEmpty) {
      return Column(
        children: [
          SizedBox(height: context.height / 5),
          Center(
            child: Text(
              'Add a receipt to start collecting overviews',
              style:
                  TextStyle(color: Colors.white, fontSize: context.height / 40),
            ),
          ),
        ],
      );
    }

    if (_userSummary.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white, fontSize: context.height / 40),
        ),
      );
    }

    final categoryAvg = _userSummary['category_avg'] ?? {};
    final categorySummary = _userSummary['category_summary'] ?? {};
    final numberOfCategories = categoryAvg.keys.length;

    int gridSize = 2;
    if (numberOfCategories >= 5) gridSize = 3;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.width / 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.height / 60),
          Center(
            child: Text(
              'Category Summary',
              style: TextStyle(
                fontSize: context.width * context.height * 0.0001,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: context.height / 2000),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: numberOfCategories,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridSize,
              childAspectRatio: 1,
              crossAxisSpacing: 2,
              mainAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              final category = categoryAvg.keys.elementAt(index);
              final avg = categoryAvg[category].toStringAsFixed(2);
              final total = categorySummary[category].toStringAsFixed(2);
              final icon = categoryIcons[category] ?? Icons.category;

              return InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/products/category/$category')
                      .then((_) => fetchUserSummary());
                },
                child: Card(
                  color: lightBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        context.width * context.height * 0.00005),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                        context.width * context.height * 0.00005 / gridSize),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: Colors.white,
                          size: context.width *
                              context.height *
                              0.00024 /
                              gridSize,
                        ),
                        SizedBox(height: context.height / 100),
                        Text(
                          category,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: context.width *
                                context.height *
                                0.00013 /
                                gridSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: context.height * 0.005 / gridSize),
                        Text(
                          'Total: zł $total\nAvg: zł $avg',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: context.width *
                                context.height *
                                0.0001 /
                                gridSize,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    _retrieveReceipts();
                    _fetchSummary();
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: context.height / 20),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: context.width / 50),
                          child: ReceiptStatistic(
                            receipts: receipts,
                          ),
                        ),
                        _buildCategoryDashboards(),
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
