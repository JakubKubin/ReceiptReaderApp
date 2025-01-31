// widgets/loading_indicator.dart

import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String message;

  const LoadingIndicator({super.key, this.message = 'Loading ...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16.0),
          Text(
            message,
            style: const TextStyle(fontSize: 32.0, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
