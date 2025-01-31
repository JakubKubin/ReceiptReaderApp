// widgets/pick_src_float_action_btn.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class PickSourceFloatingActionButton extends StatelessWidget {
  final BuildContext context;
  final AuthService authService;
  final http.Client client;
  final VoidCallback onPressed;
  final VoidCallback stopLoading;
  final void Function(int receiptId) onNavigateToEditReceiptPage;

  const PickSourceFloatingActionButton({
    super.key,
    required this.context,
    required this.authService,
    required this.client,
    required this.onPressed,
    required this.stopLoading,
    required this.onNavigateToEditReceiptPage,
  });

  void _showImageSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(context, ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickReceipt(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();

    final permissionStatus = await Permission.photos.request();
    if (!permissionStatus.isGranted) {
      stopLoading();
      if (!context.mounted) return;
      ErrorHandler.showError(context, 'Permission Denied');
      return;
    }

    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) {
      stopLoading();
      return;
    }

    onPressed();

    final accessToken = await authService.getAccessToken();
    if (accessToken == null) {
      stopLoading();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final request = http.MultipartRequest('POST', Urls.createReceiptUrl)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..headers['Content-Type'] = 'application/json; charset=UTF-8'
        ..headers['ngrok-skip-browser-warning'] = '69420'
        ..files.add(http.MultipartFile.fromBytes(
          'original_image',
          File(pickedFile.path).readAsBytesSync(),
          filename: path.basename(pickedFile.path),
        ));

      final response = await request.send();

      if (response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final Map<String, dynamic> responseMap = json.decode(responseData);
        final int receiptId = responseMap['id'];

        onNavigateToEditReceiptPage(receiptId);
      } else {
        throw Exception('Failed to create receipt');
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorHandler.showError(context, e.toString());
    } finally {
      stopLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showImageSourceOptions(context),
      tooltip: 'Add a new receipt',
      backgroundColor: Colors.white,
      child: const Icon(Icons.post_add_outlined, color: strongViolet),
    );
  }
}
