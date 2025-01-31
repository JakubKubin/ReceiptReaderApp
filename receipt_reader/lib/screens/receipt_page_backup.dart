import 'package:flutter/material.dart';
import 'package:receipt_reader/utils/colors.dart';

// ignore: camel_case_types
class ReceiptPage_2 extends StatefulWidget {
  const ReceiptPage_2({super.key});

  @override
  State<ReceiptPage_2> createState() => _ReceiptPage_2();
}

Widget _buildListCard(
    String title, int completed, int total, List<String> initials) {
  double progress = total > 0 ? completed / total : 0.0;
  return Card(
    elevation: 4.0,
    margin: const EdgeInsets.only(bottom: 16.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.0,
              backgroundColor: Colors.grey[300],
              color: darkViolet,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: initials
                .map((initial) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: darkViolet,
                        child: Text(
                          initial,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    ),
  );
}

// ignore: camel_case_types
class _ReceiptPage_2 extends State<ReceiptPage_2> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [lightViolet, darkViolet],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shopping Lists',
                        style: TextStyle(
                          fontSize: 29.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      _buildListCard('Rossmann 🎀', 0, 1, ['K']),
                      const SizedBox(height: 16),
                      _buildListCard('Home', 12, 15, ['K']),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: lightViolet.withOpacity(0.7),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {},
          tooltip: 'Add a new shopping list',
          backgroundColor: Colors.white,
          child: const Icon(Icons.post_add_outlined, color: strongViolet),
        ),
      ),
    );
  }
}
