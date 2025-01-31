// services/product_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:receipt_reader/models/product.dart';
import 'package:receipt_reader/utils/urls.dart';

class ProductService {
  final http.Client client;

  ProductService(this.client);

  Future<List<Product>> fetchProductsByCategory(
      String accessToken, String categoryName) async {
    try {
      final response = await client.get(
        Urls.getCategoryProductsUrl(categoryName),
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
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Product.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        throw Exception(json.decode(response.body)['error']);
      } else {
        throw Exception(
            'Failed to fetch products: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching products by category: $e');
    }
  }

  Future<void> updateProduct(
      String accessToken, Product product, productId) async {
    try {
      final response = await client
          .put(
        Urls.changeProductUrl(productId),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
          'ngrok-skip-browser-warning': '69420',
        },
        body: product.toJson(),
      )
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timed out.');
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update product: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating product: $e');
    }
  }

  Future<void> deleteProduct(String accessToken, int productId) async {
    try {
      final response = await client.delete(
        Urls.changeProductUrl(productId),
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

      if (response.statusCode != 204) {
        throw Exception(
            'Failed to delete product: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting product: $e');
    }
  }
}
