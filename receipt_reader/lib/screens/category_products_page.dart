// screens/category_products_page.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/dashboard/products_statistic_widget.dart';
import 'package:receipt_reader/models/product.dart';
import 'package:receipt_reader/services/auth_service.dart';
import 'package:receipt_reader/services/product_service.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/widgets/custom_text_field.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';

class CategoryProductsPage extends StatefulWidget {
  final String categoryName;

  const CategoryProductsPage({super.key, required this.categoryName});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  final http.Client client = http.Client();
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService(http.Client());

  int _selectedTimeIndex = 1; // 0=1W, 1=1M, 2=1Y, 3=MAX

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
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
      } else if (e is Exception &&
          e.toString().contains('No products found for this category.')) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ErrorHandler.showError(context, 'An error occurred. Please try again.');
      }
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final List<Product> products =
          await _productService.fetchProductsByCategory(
        accessToken,
        widget.categoryName,
      );
      setState(() {
        _products.clear();
        _products.addAll(products);
      });

      _filterData();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterData() {
    DateTime now = DateTime.now();
    DateTime fromDate;

    switch (_selectedTimeIndex) {
      case 0: // 1W
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case 1: // 1M
        fromDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 2: // 1Y
        fromDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default: // MAX
        fromDate = DateTime.fromMillisecondsSinceEpoch(0);
        break;
    }

    setState(() {
      _filteredProducts = _products.where((p) {
        return p.receiptDate != null &&
            p.price != null &&
            p.receiptDate!.isAfter(fromDate);
      }).toList();
    });
  }

  void _onTimeSelected(int newIndex) {
    setState(() {
      _selectedTimeIndex = newIndex;
    });
    _filterData();
  }

  Future<void> _deleteProduct(int productId) async {
    setState(() => _isLoading = true);
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      await _productService.deleteProduct(accessToken, productId);
      await _fetchProducts();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProduct(Product updatedProduct) async {
    setState(() => _isLoading = true);
    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      await _productService.updateProduct(
          accessToken, updatedProduct, updatedProduct.id);
      await _fetchProducts();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(Product product, int index) {
    final TextEditingController nameController =
        TextEditingController(text: product.name);
    final TextEditingController priceController =
        TextEditingController(text: product.price?.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                labelText: 'Product Name',
              ),
              const SizedBox(height: 16.0),
              CustomTextField(
                controller: priceController,
                labelText: 'Price',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ErrorHandler.showError(
                    context,
                    'Product name cannot be empty',
                    height: MediaQuery.of(context).size.height / 1.2,
                  );
                  return;
                }
                final newPrice = double.tryParse(priceController.text);
                final updated = product.copyWith(
                  id: product.id,
                  name: nameController.text,
                  price: newPrice,
                  category: widget.categoryName,
                );
                Navigator.pop(ctx);
                await _updateProduct(updated);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryDialog(Product product, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Categorize ${product.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView(
                  shrinkWrap: true,
                  children: [
                    ...[
                      'Uncategorized',
                      'Groceries',
                      'Veggies',
                      'Fruits',
                      'Meat',
                      'Dairy',
                      'Bakery',
                      'Beverages',
                      'Clothing',
                      'Gas',
                      'Health',
                    ].map((String category) => ListTile(
                          title: Text(category),
                          onTap: () async {
                            Navigator.of(context).pop();
                            final updated =
                                product.copyWith(category: category);
                            await _updateProduct(updated);
                          },
                        )),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductItem(Product product, int index) {
    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: Colors.white.withOpacity(0.1),
      child: ListTile(
        title: Text(
          product.name,
          style: const TextStyle(color: Colors.white, fontSize: 18.0),
        ),
        subtitle: Text(
          'Price: ${product.price?.toStringAsFixed(2) ?? '0.00'} zł\n'
          'Receipt: ${product.receiptTitle ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70, fontSize: 14.0),
        ),
        onTap: () => _showEditDialog(product, index),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.category, color: Colors.greenAccent),
              onPressed: () => _showCategoryDialog(product, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () async {
                if (product.id != null) {
                  await _deleteProduct(product.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Text(
          'No products available in this category (time filtered)',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return _buildProductItem(_filteredProducts[index], index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: screenHeight * 0.02),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: screenHeight * 0.02),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.categoryName,
                                style: TextStyle(
                                  fontSize: screenHeight * 0.03,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          CategoryStatistic(
                            filteredProducts: _filteredProducts,
                            selectedTimeIndex: _selectedTimeIndex,
                            onTimeSelected: _onTimeSelected,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildProductList(),
                          SizedBox(height: screenHeight * 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
