// models/product.dart

import 'dart:convert';

class Product {
  int? id;
  String name;
  double? price;
  String? category;
  String? receiptTitle;
  DateTime? receiptDate;

  Product({
    this.id,
    required this.name,
    this.price,
    this.category,
    this.receiptTitle,
    this.receiptDate,
  });

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? category,
    String? receiptTitle,
    DateTime? receiptDate,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      receiptTitle: receiptTitle ?? this.receiptTitle,
      receiptDate: receiptDate ?? this.receiptDate,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'receipt_title': receiptTitle,
      'receipt_date': receiptDate.toString(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: map['price'] as double?,
      category: map['category'] as String?,
      receiptTitle: map['receipt_title'] as String?,
      receiptDate: map['receipt_date'] != null
          ? DateTime.parse(map['receipt_date'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int?,
      name: json['name'] as String,
      price: double.tryParse(json['price']?.toString() ?? '0.0'),
      category: json['category'] as String?,
      receiptTitle: json['receipt_title'] as String?,
      receiptDate: json['receipt_date'] != null
          ? DateTime.parse(json['receipt_date'])
          : null,
    );
  }

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, category: $category, receipt_title: $receiptTitle, receipt_date: $receiptDate)';
}
