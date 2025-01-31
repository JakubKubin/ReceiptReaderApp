// widgets/custom_button.dart

import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final double fontSize;
  final double veritcalPadding;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF601AB6),
    this.textColor = Colors.white,
    this.fontSize = 16.0,
    this.veritcalPadding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: EdgeInsets.symmetric(vertical: veritcalPadding)),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
    );
  }
}
