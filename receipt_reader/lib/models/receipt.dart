// models/receipt.dart

import 'dart:convert';

class Receipt {
  final int id;
  final String title;
  final String originalImageUrl;
  final String processedImageUrl;
  final String text;
  final String address;
  final String date;
  final String total;
  final String createdAt;

  Receipt({
    required this.id,
    required this.title,
    required this.originalImageUrl,
    required this.processedImageUrl,
    required this.text,
    required this.address,
    required this.date,
    required this.total,
    required this.createdAt,
  });

  Receipt copyWith({
    required int id,
    required String title,
    required String originalImageUrl,
    required String processedImageUrl,
    required String text,
    required String address,
    required String total,
    required String date,
    required String createdAt,
  }) {
    return Receipt(
        id: id,
        title: title,
        originalImageUrl: originalImageUrl,
        processedImageUrl: processedImageUrl,
        text: text,
        address: address,
        total: total,
        date: date,
        createdAt: createdAt);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'originalImageUrl': originalImageUrl,
      'processedImageUrl': processedImageUrl,
      'total': total,
      'date_of_shopping': date,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
        id: map['id'] as int,
        title: map['title'] as String,
        originalImageUrl: map['originalImageUrl'] as String,
        processedImageUrl: map['processedImageUrl'] as String,
        text: map['text'] as String,
        address: map['address'] as String,
        total: map['total'] as String,
        date: map['date_of_shopping'] as String,
        createdAt: map['createdAt'] as String);
  }

  String toJson() => json.encode(toMap());

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      originalImageUrl: json['original_image'] as String? ?? '',
      processedImageUrl: json['processed_image'] as String? ?? '',
      text: json['text'] as String? ?? '',
      address: json['address'] as String? ?? '',
      total: json['total']?.toString() ?? '0.0',
      date: json['date_of_shopping'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'Receipt(id: $id, title: $title, originalImageUrl: $originalImageUrl, processedImageUrl: $processedImageUrl, total: $total, date: $date)';

  @override
  bool operator ==(covariant Receipt other) {
    if (identical(this, other)) return true;

    return other.id == id;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ originalImageUrl.hashCode;
}
