// screens/edit_receipt_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/models/product.dart';
import 'package:receipt_reader/screens/fullscreen_image_page.dart';
import 'package:receipt_reader/services/receipt_service.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:receipt_reader/utils/media_query_values.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as picker;
import 'package:receipt_reader/widgets/add_product_dialog.dart';
import 'package:receipt_reader/widgets/gradient_background.dart';

class EditReceiptPage extends StatefulWidget {
  final int receiptId;

  const EditReceiptPage({super.key, required this.receiptId});

  @override
  State<EditReceiptPage> createState() => _EditReceiptPageState();
}

class _EditReceiptPageState extends State<EditReceiptPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final http.Client client = http.Client();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  DateTime? _selectedDate;
  String? _originalImageUrl;
  String? _processedImageUrl;
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  int _currentPage = 0;

  final ReceiptService _receiptService = ReceiptService(http.Client());

  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProductsReceiptDetails();
    _fetchReceiptDetails();
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

  void _parseReceiptText(String text) {
    _products.clear();
    _receiptService.parseReceiptText(
      _textController.text,
      _products,
      (address) => setState(() => _addressController.text = address),
      (date) => setState(() => _dateController.text = date),
      (total) => setState(() => _totalController.text = total),
    );
  }

  void _joinReceiptText() {
    _textController.text = _products.map((product) {
      String line = product.name;
      if (product.price != null) {
        line += ' &&${product.price!.toStringAsFixed(2)}&&';
      }
      if (product.category != null && product.category!.isNotEmpty) {
        line += ' ##${product.category}##';
      }
      return line;
    }).join('\n');
  }

  Future<void> _fetchProductsReceiptDetails() async {
    setState(() => _isLoading = true);

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final productsResponse = await client.get(
        Urls.getReceiptProductsUrl(widget.receiptId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );
      if (productsResponse.statusCode == 200) {
        final List<dynamic> productsData =
            json.decode(utf8.decode(productsResponse.bodyBytes));
        setState(() {
          _products = productsData
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } else if (productsResponse.statusCode == 401) {
        await _authService.getAccessToken();
        _fetchReceiptDetails();
      } else if (productsResponse.statusCode == 404) {
        final Map<String, dynamic> productsData =
            json.decode(utf8.decode(productsResponse.bodyBytes));
        if (productsData['error'] !=
            'No products found for the specified receipt.') {
          throw Exception('Failed to fetch receipt details');
        }
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _fetchReceiptDetails() async {
    setState(() => _isLoading = true);

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await client.get(
        Urls.receiveSpecificReceiptUrl(widget.receiptId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _titleController.text = responseData['title'] ?? '';
          _textController.text = responseData['text'] ?? '';
          _addressController.text = responseData['address'] ?? '';
          final dateString = responseData['date_of_shopping'] ?? '';

          if (dateString.isNotEmpty) {
            _selectedDate = DateTime.parse(dateString);
            _dateController.text = _selectedDate!.toLocal().toString();
          }
          _totalController.text = responseData['total']?.toString() ?? '0.00';
          _originalImageUrl = responseData['original_image'] as String?;
          _processedImageUrl = responseData['processed_image'] as String?;
        });

        if (_products.isEmpty) {
          _parseReceiptText(_textController.text);
        }

        await _fetchImages(accessToken);
      } else if (response.statusCode == 401) {
        await _authService.getAccessToken();
        _fetchReceiptDetails();
      } else {
        throw Exception('Failed to fetch receipt details');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchImages(String accessToken) async {
    try {
      if (_originalImageUrl != null && _originalImageUrl!.isNotEmpty) {
        final imageResponse = await client.get(
          Uri.parse(_originalImageUrl!),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (imageResponse.statusCode == 200) {
          _originalImageBytes = imageResponse.bodyBytes;
        }
      }

      if (_processedImageUrl != null && _processedImageUrl!.isNotEmpty) {
        final imageResponse = await client.get(
          Uri.parse(_processedImageUrl!),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (imageResponse.statusCode == 200) {
          _processedImageBytes = imageResponse.bodyBytes;
        }
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => {});
    }
  }

  Future<void> _updateReceipt() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    _joinReceiptText();

    final title = _titleController.text;
    final text = _textController.text;
    final address = _addressController.text;
    var date = _dateController.text;

    if (date.length <= 16) {
      date += ':00.000';
    }
    if (date == '' || date.length != 23) {
      date = _selectedDate != null ? _selectedDate!.toIso8601String() : '';
    }
    final total = double.tryParse(_totalController.text) ?? 0.00;

    try {
      final response = await client
          .put(
        Urls.updateReceiptUrl(widget.receiptId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
        body: json.encode({
          'title': title,
          'text': text,
          'address': address,
          'date_of_shopping': date,
          'total': total,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop();
      } else if (response.statusCode == 401) {
        await _authService.getAccessToken();
        _updateReceipt();
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        throw Exception(responseData['error'] ?? 'Failed to update receipt');
      }
    } catch (e) {
      _handleError(e);
      setState(() => _isLoading = false);
    }
  }

  void _deleteReceipt(int id) async {
    setState(() => _isLoading = true);

    try {
      final accessToken = await _authService.getAccessToken();
      if (accessToken == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await _receiptService.deleteReceipt(accessToken, id);

      if (response.statusCode == 204) {
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to delete receipt:');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    picker.DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2000, 1, 1),
      maxTime: DateTime.now(),
      onConfirm: (date) {
        setState(() {
          _selectedDate = date;
          _dateController.text = _selectedDate!.toLocal().toString();
        });
      },
      currentTime: _selectedDate ?? DateTime.now(),
      locale: picker.LocaleType.en,
    );
  }

  void _showEditTextDialog(Product product, int index) {
    final TextEditingController textController =
        TextEditingController(text: product.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Product Text'),
          content: TextField(
            controller: textController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Product Text',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = textController.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    _products[index] = product.copyWith(name: newName);
                  });
                  Navigator.of(context).pop();
                } else {
                  ErrorHandler.showError(
                      context, 'Product text cannot be empty.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddProductDialog(
        onProductAdded: (newProduct) {
          setState(() {
            _products.add(newProduct);
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    client.close();
    _titleController.dispose();
    _textController.dispose();
    _addressController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Widget _buildImageSection() {
    List<Widget> imagePages = [];

    if (_processedImageBytes != null) {
      imagePages.add(
        GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => FullscreenImagePage(
                  imageBytes: _processedImageBytes,
                  imageUrl: _processedImageUrl,
                  receiptId: widget.receiptId,
                  tag: 'processed',
                ),
              ),
            )
                .then((cropped) {
              if (cropped == true) {
                _titleController.clear();
                _textController.clear();
                _addressController.clear();
                _dateController.clear();
                _totalController.clear();
                _products.clear();

                _fetchReceiptDetails();
              }
            });
          },
          child: Hero(
            tag: 'processed',
            child: Image.memory(
              _processedImageBytes!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    if (_originalImageBytes != null) {
      imagePages.add(
        GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => FullscreenImagePage(
                  imageBytes: _originalImageBytes,
                  imageUrl: _originalImageUrl,
                  receiptId: widget.receiptId,
                  tag: 'original',
                ),
              ),
            )
                .then((cropped) {
              if (cropped == true) {
                _titleController.clear();
                _textController.clear();
                _addressController.clear();
                _dateController.clear();
                _totalController.clear();
                _products.clear();

                _fetchReceiptDetails();
              }
            });
          },
          child: Hero(
            tag: 'original',
            child: Image.memory(
              _originalImageBytes!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    if (imagePages.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        SizedBox(
          height: context.height / 1.5,
          child: PageView(
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: imagePages,
          ),
        ),
        SizedBox(height: context.height / 70),
        if (imagePages.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(imagePages.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 12 : 12,
                height: _currentPage == index ? 12 : 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? white : darkGrey,
                ),
              );
            }),
          ),
      ],
    );
  }

  void _showAddPriceDialog(Product product, int index) {
    final TextEditingController priceController =
        TextEditingController(text: product.price?.toString() ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Price'),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Enter price',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(priceController.text.trim());
                if (newPrice != null) {
                  setState(() {
                    _products[index] = product.copyWith(price: newPrice);
                  });
                  Navigator.of(context).pop();
                } else {
                  ErrorHandler.showError(
                      context, 'Please enter a valid price.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineItem(Product product, int index) {
    return Card(
      elevation: 3.0,
      margin: EdgeInsets.symmetric(vertical: context.height / 250),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.height / 85),
      ),
      color: Colors.white.withOpacity(0.1),
      child: ListTile(
        title: Text(
          product.name,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          '${product.price != null ? '${product.price!.toStringAsFixed(2)} zł' : ''}'
          '${product.category != null ? ' [${product.category}]' : ''}',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_money, color: Colors.amber),
              onPressed: () => _showAddPriceDialog(product, index),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
              onPressed: () => _showCategoryDialog(product, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _products.removeAt(index);
                });
              },
            ),
          ],
        ),
        onTap: () => _showEditTextDialog(product, index),
      ),
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
                      fontSize: 18, fontWeight: FontWeight.bold),
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
                          onTap: () {
                            setState(() {
                              _products[index].category = category;
                            });
                            Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
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
                          EdgeInsets.symmetric(horizontal: context.width / 18),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Edit Receipt',
                                style: TextStyle(
                                  fontSize: context.height / 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.white),
                                onPressed: () {
                                  _deleteReceipt(widget.receiptId);
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: context.height / 150),
                          _buildImageSection(),
                          SizedBox(height: context.height / 75),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: _titleController,
                                  labelText: 'Title',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter the title';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: context.height / 70),
                                Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Receipt Items:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: context.height / 50,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: context.height / 100),
                                ElevatedButton.icon(
                                  onPressed: _showAddProductDialog,
                                  icon: const Icon(Icons.add,
                                      color: Colors.greenAccent),
                                  label: const Text(
                                    'Add New Item',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          context.height / 85),
                                    ),
                                  ),
                                ),
                                SizedBox(height: context.height / 100),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    return _buildLineItem(
                                        _products[index], index);
                                  },
                                ),
                                SizedBox(height: context.height / 55),
                                _buildTextField(
                                  controller: _addressController,
                                  labelText: 'Address',
                                ),
                                SizedBox(height: context.height / 55),
                                _buildTextField(
                                  controller: _dateController,
                                  labelText: 'Date and Time',
                                  readOnly: true,
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  onTap: _pickDateTime,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select the date and time';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: context.height / 55),
                                _buildTextField(
                                  controller: _totalController,
                                  labelText: 'Total',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter the total amount';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Please enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: context.height / 45),
                                ElevatedButton(
                                  onPressed: _updateReceipt,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(
                                        double.infinity, context.height / 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          context.height / 85),
                                    ),
                                    backgroundColor: white,
                                    foregroundColor: strongViolet,
                                    textStyle: TextStyle(
                                        fontSize: context.height / 45),
                                  ),
                                  child: const Text('Save Changes'),
                                ),
                                SizedBox(height: context.height / 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool readOnly = false,
    Widget? suffixIcon,
    void Function()? onTap,
    int? maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Color.fromARGB(190, 255, 255, 255)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white70),
          borderRadius: BorderRadius.circular(context.height / 85),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white),
          borderRadius: BorderRadius.circular(context.height / 85),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
