// widgets/receipt_card.dart

import 'package:flutter/material.dart';
import 'package:receipt_reader/models/receipt.dart';
import 'package:receipt_reader/utils/colors.dart';
import 'package:receipt_reader/utils/media_query_values.dart';

class ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ReceiptCard({
    super.key,
    required this.receipt,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: context.height / 200, vertical: context.height / 200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.height / 70),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.width / 40, vertical: context.height / 50),
        leading: const CircleAvatar(
          backgroundColor: strongViolet,
          child: Icon(Icons.receipt, color: Colors.white),
        ),
        title: Text(
          receipt.title,
          style: TextStyle(
            fontSize: context.height / 50,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${receipt.date.substring(0, 10)} ${receipt.date.substring(11, 19)}',
              style: TextStyle(fontSize: context.height / 55),
            ),
            Text(
              'Total: ${receipt.total}',
              style: TextStyle(fontSize: context.height / 55),
            ),
          ],
        ),
        onTap: onEdit,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: lightBlack),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
