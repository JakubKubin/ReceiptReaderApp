// widgets/gradient_background.dart

import 'package:flutter/material.dart';
import 'package:receipt_reader/utils/colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget? child;
  final List<Color> colors;

  const GradientBackground(
      {super.key, this.child, this.colors = const [lightViolet, darkViolet]});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
