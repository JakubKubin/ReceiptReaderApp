import 'package:flutter/material.dart';
import 'package:receipt_reader/models/product.dart';

class AddProductDialog extends StatefulWidget {
  final Function(Product) onProductAdded;

  const AddProductDialog({
    super.key,
    required this.onProductAdded,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedCategory = 'Uncategorized';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Product'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Product Price',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            // Category chooser placeholder
            InkWell(
              onTap: () => _pickCategory(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _selectedCategory,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _onAddPressed,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _onAddPressed() {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();

    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final price = double.tryParse(priceText);
    final newProduct = Product(
      name: name,
      price: price,
      category: _selectedCategory,
    );

    widget.onProductAdded(newProduct);
    Navigator.of(context).pop();
  }

  void _pickCategory(BuildContext context) {
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
                const Text(
                  'Choose Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView(
                  shrinkWrap: true,
                  children: [
                    ...[
                      'Uncategorized',
                      'Veggies',
                      'Fruits',
                      'Meat',
                      'Dairy',
                      'Bakery',
                      'Clothing',
                      'Gas'
                    ].map((String category) => ListTile(
                          title: Text(category),
                          onTap: () {
                            _selectCategory(category);
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

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
    Navigator.of(context).pop();
  }
}
