// widgets/custom_text_field.dart

import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool isPassword;
  final bool readOnly;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Function()? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.isPassword = false,
    this.readOnly = false,
    this.suffixIcon,
    this.validator,
    this.onTap,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          suffixIcon: suffixIcon,
          prefixIcon: prefixIcon),
    );
  }
}
