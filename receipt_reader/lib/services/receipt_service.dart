// services/receipt_service.dart

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:receipt_reader/models/product.dart';
import 'package:receipt_reader/utils/urls.dart';

class ReceiptService {
  final http.Client client;

  ReceiptService(this.client);

  Future<http.Response> fetchReceipts(String accessToken, int userId) async {
    try {
      final response = await client.get(
        Urls.getUserDataUrl(userId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );
      return response;
    } catch (e) {
      throw Exception('Error fetching receipts: $e');
    }
  }

  Future<http.Response> deleteReceipt(String accessToken, int receiptId) async {
    try {
      final response = await client.delete(
        Urls.deleteReceiptUrl(receiptId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );
      return response;
    } catch (e) {
      throw Exception('Error deleting receipt: $e');
    }
  }

  void parseReceiptText(
      String text,
      List<Product> products,
      Function(String) setAddress,
      Function(String) setDate,
      Function(String) setTotal) {
    final List<String> rawLines =
        text.split('\n').where((line) => line.trim().isNotEmpty).toList();

    final RegExp addressPattern = RegExp(r'\d{2}\s*-\s*\d{3}\s*');
    final RegExp numericLineRegex = RegExp(r'^[0-9.,\s]+$');
    final RegExp pricePattern = RegExp(r'(\d+[.,]?\d*)[A-Za-z]?$');
    final RegExp serverPricePattern = RegExp(r'&&([\d.]+)&&');
    final RegExp serverCategoryPattern = RegExp(r'##([^#]+)##');
    final RegExp unwantedPattern = RegExp(r'\b(x|«|X)\d+[.,]?\d*\b');
    final RegExp unwantedPatternWithSzt =
        RegExp(r'\b\d+\s*szt\b', caseSensitive: false);
    final RegExp singleLetterOrDigitPattern = RegExp(r'\b[A-Za-z0-9]\b');
    final RegExp datePattern = RegExp(r'\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}\b');
    final RegExp unwantedPatternXdigits = RegExp(r'\s+\d+[xX][.,]?\d*');
    final RegExp unwantedDotCommaDigits =
        RegExp(r'[.,]?\d+\s?|(?<=\s)\d+(?=\s?)');

    String? addressString;
    final List<String> toDeleteTriggers = [
      'adres',
      'siedziba',
      'siedziby',
      'nip',
      'paragon',
      'ptu',
      'piu',
      '---',
      '...',
      '———',
      'sprzedaz',
      'sprzedaż',
      'rozliczenie',
      'platnosci',
      'płatności',
      'opodatkowana',
      'podsuma',
      'podsuma:',
      'podsuna',
      'podsuna:',
      'nr:',
      '___',
      'rej:',
      'rabat',
      'kupon',
      'opust',
      'karta',
      'łatnicza',
      'płatnicza',
      'platnicza',
    ];

    for (var line in rawLines) {
      String name = line;
      double? price;
      String? category;

      final lowerLine = line.toLowerCase().trim();

      if (lowerLine.contains('paragon')) {
        products.clear();
      }

      if (toDeleteTriggers.any((t) => lowerLine.contains(t))) {
        continue;
      }

      final serverPriceMatch = serverPricePattern.firstMatch(line);
      if (serverPriceMatch != null) {
        price = double.tryParse(serverPriceMatch.group(1)!);
        name = name.replaceFirst(serverPricePattern, '').trim();
      }

      final serverCategoryMatch = serverCategoryPattern.firstMatch(line);
      if (serverCategoryMatch != null) {
        category = serverCategoryMatch.group(1);
        name = name.replaceFirst(serverCategoryPattern, '').trim();
      }

      final priceMatch = pricePattern.firstMatch(name);
      if (priceMatch != null && price == null) {
        final priceText = priceMatch.group(1)?.replaceAll(',', '.');
        if (priceText != null) {
          price = double.tryParse(priceText);
        }
        name = name.substring(0, priceMatch.start).trim();
      }

      if (lowerLine.contains('suma') ||
          (lowerLine.contains('suna') || (lowerLine.contains('sumą')))) {
        final RegExp numberRegex = RegExp(r'(\d+[.,]?\d*)');
        final match = numberRegex.firstMatch(line);
        if (match != null) {
          final parsed = match.group(1)?.replaceAll(',', '.');
          if (parsed != null && double.tryParse(parsed) != null) {
            setTotal(parsed);
          }
        }
        continue;
      }

      if (numericLineRegex.hasMatch(name)) {
        continue;
      }

      if (addressString == null &&
          (lowerLine.contains('ul') ||
              lowerLine.contains('pl') ||
              addressPattern.hasMatch(lowerLine))) {
        addressString = line;
        setAddress(line);
        continue;
      }

      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch != null) {
        setDate(dateMatch.group(0)!);
        continue;
      }

      name = name.replaceAll(unwantedPattern, '').trim();
      name = name.replaceAll(unwantedPatternWithSzt, '').trim();
      name = name.replaceAll(singleLetterOrDigitPattern, '').trim();
      name = name.replaceAll(unwantedPatternXdigits, '').trim();
      name = name.replaceAll('«', '').trim();
      name = name.replaceAll(unwantedDotCommaDigits, '').trim();
      if (price != null && (price > 100000 || price < 0.00) ||
          name.length < 2) {
        continue;
      }
      products.add(Product(name: name, price: price, category: category));
    }
  }
}
