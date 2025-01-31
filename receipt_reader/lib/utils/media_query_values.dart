// utils/media_query_values.dart

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

extension MediaQueryValues on BuildContext {
  double get height => MediaQuery.of(this).size.height;
  double get width => MediaQuery.of(this).size.width;
  double get toPadding => MediaQuery.of(this).viewPadding.top;
  double get bottom => MediaQuery.of(this).viewInsets.bottom;
}
