// screens/fullscreen_image_page.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:receipt_reader/utils/authentication.dart';
import 'package:receipt_reader/utils/error_handler.dart';
import 'package:receipt_reader/utils/urls.dart';
import 'package:http/http.dart' as http;

class FullscreenImagePage extends StatefulWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String? tag;
  final int? receiptId;

  const FullscreenImagePage({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.tag,
    this.receiptId,
  });

  @override
  FullscreenImagePageState createState() => FullscreenImagePageState();
}

class FullscreenImagePageState extends State<FullscreenImagePage> {
  ImageProvider? imageProvider;
  Uint8List? _currentImageBytes;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _currentImageBytes = widget.imageBytes;
    if (_currentImageBytes != null) {
      imageProvider = MemoryImage(_currentImageBytes!);
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(widget.imageUrl!);
    }
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

  Future<void> _cropImage() async {
    if (_currentImageBytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final tempImageFile = await File('${tempDir.path}/temp_image.png')
        .writeAsBytes(_currentImageBytes!);

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: tempImageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile != null) {
      final croppedBytes = await croppedFile.readAsBytes();

      setState(() {
        _currentImageBytes = croppedBytes;
        imageProvider = MemoryImage(_currentImageBytes!);
      });

      if (widget.receiptId != null) {
        await _updateReceiptImage(widget.receiptId!, File(croppedFile.path));
      }
    }
  }

  Future<void> _updateReceiptImage(int receiptId, File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    final accessToken = await _authService.getAccessToken();

    if (accessToken == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final request =
          http.MultipartRequest('PUT', Urls.updateReceiptUrl(receiptId))
            ..headers['Authorization'] = 'Bearer $accessToken'
            ..headers['ngrok-skip-browser-warning'] = '69420';

      request.files.add(http.MultipartFile.fromBytes(
          '${widget.tag}_image', File(imageFile.path).readAsBytesSync(),
          filename: path.basename(imageFile.path)));

      final response = await request.send();

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final responseData = await response.stream.bytesToString();
        if (!mounted) return;
        if (kDebugMode) print(responseData);
        Navigator.pop(context, false);
        throw Exception('Failed to update receipt image');
      }
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageProvider == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Image is not available',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.crop),
              onPressed: _cropImage,
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Hero(
        tag: widget.tag ?? 'receiptImage',
        child: PhotoView(
          imageProvider: imageProvider,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
}
