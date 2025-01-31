// utils/error_handler.dart

import 'package:flutter/material.dart';
import 'package:receipt_reader/utils/media_query_values.dart';

class ErrorHandler {
  static void showError(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    double? fontSize,
        double? height,
  }) {
    final double fontSize0 = fontSize ?? context.height / 50;
    final backGroundColor = backgroundColor ?? Colors.redAccent;
    final height0 = height ?? context.height;
    SnackBar snackBar = SnackBar(
      content: Text(message, style: TextStyle(fontSize: fontSize0)),
      backgroundColor: backGroundColor,
      dismissDirection: DismissDirection.up,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
          bottom: height0 - height0 / 5, left: 10, right: 10),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
