// dashboard/overview_statistic_widget.dart

import 'package:flutter/material.dart';
import 'package:receipt_reader/models/chart_data.dart';
import 'package:receipt_reader/models/receipt.dart';
import 'package:receipt_reader/widgets/bar_graph.dart';

import '../../utils/colors.dart';

class ReceiptStatistic extends StatefulWidget {
  final List<Receipt> receipts;

  const ReceiptStatistic({
    super.key,
    required this.receipts,
  });

  @override
  State<ReceiptStatistic> createState() => _ReceiptStatisticState();
}

class _ReceiptStatisticState extends State<ReceiptStatistic> {
  int _selectedTimeIndex = 1;
  final List<String> _times = ['1W', '1M', '1Y', 'MAX'];
  List<Receipt> _filteredReceiptsByTime = [];
  List<ChartData> _filteredReceipts = [];
  double totalInTime = 0;

  @override
  void initState() {
    super.initState();
    _filterData();
  }

  void _filterData() {
    DateTime now = DateTime.now();
    DateTime fromDate;
    totalInTime = 0;

    switch (_selectedTimeIndex) {
      case 0: // 1W
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case 1: // 1M
        fromDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 2: // 1Y
        fromDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default: // MAX
        fromDate = DateTime.fromMillisecondsSinceEpoch(0);
        break;
    }

    _filteredReceiptsByTime = widget.receipts.where((data) {
      return DateTime.parse(data.date).isAfter(fromDate);
    }).toList();

    for (var receipt in _filteredReceiptsByTime) {
      totalInTime += double.tryParse(receipt.total)!;
    }

    if (_selectedTimeIndex == 0 || _selectedTimeIndex == 1) {
      _filteredReceipts = _groupByDay(_filteredReceiptsByTime);
    } else if (_selectedTimeIndex == 2) {
      _filteredReceipts = _groupByMonth(_filteredReceiptsByTime);
    } else {
      _filteredReceipts = _groupByDay(_filteredReceiptsByTime);
    }

    setState(() {});
  }

  List<ChartData> _groupByDay(List<Receipt> receipts) {
    final Map<String, double> dailyTotals = {};
    for (var receipt in receipts) {
      final receiptDate = DateTime.parse(receipt.date);
      final dateKey = "${receiptDate.year}-"
          "${receiptDate.month.toString().padLeft(2, '0')}-"
          "${receiptDate.day.toString().padLeft(2, '0')}";

      dailyTotals[dateKey] =
          (dailyTotals[dateKey] ?? 0) + double.tryParse(receipt.total)!;
    }

    return dailyTotals.entries.map((data) {
      final dateParts = data.key.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      final dateTime = DateTime(year, month, day);

      return ChartData(
        date: dateTime.millisecondsSinceEpoch.toDouble(),
        total: double.parse((data.value).toStringAsFixed(2)),
        count: 1,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ChartData> _groupByMonth(List<Receipt> receipts) {
    final Map<String, double> monthlyTotals = {};

    for (var receipt in receipts) {
      final receiptDate = DateTime.parse(receipt.date);

      final dateKey = "${receiptDate.year}-"
          "${receiptDate.month.toString().padLeft(2, '0')}";

      monthlyTotals[dateKey] =
          (monthlyTotals[dateKey] ?? 0) + double.parse(receipt.total);
    }

    return monthlyTotals.entries.map((data) {
      final dateParts = data.key.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final dateTime = DateTime(year, month, 1);

      return ChartData(
        date: dateTime.millisecondsSinceEpoch.toDouble(),
        total: double.parse((data.value).toStringAsFixed(2)),
        count: 1,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: screenWidth * screenHeight * 0.00115,
      height: screenWidth * screenHeight * 0.0007,
      constraints: BoxConstraints(
        minWidth: screenWidth * 0.9,
      ),
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * screenWidth * 0.00001,
        horizontal: screenWidth * 0.035,
      ),
      decoration: BoxDecoration(
        color: lightBlack,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      color: darkGrey,
                      fontSize: screenHeight * screenWidth * 0.00003,
                    ),
                  ),
                  Text(
                    '${totalInTime.toStringAsFixed(2)} zł',
                    style: TextStyle(
                      fontSize: screenHeight * screenWidth * 0.000037,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: _times
                    .map((e) =>
                        _buildTimeSelector(context, _times.indexOf(e), e))
                    .toList(),
              ),
            ],
          ),
          SizedBox(height: screenWidth * screenHeight * 0.00001),
          // Chart
          Expanded(
            child: BarGraphWidget(
              chartDataList: _filteredReceipts,
              selectedTimeIndex: _selectedTimeIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(BuildContext context, int index, String label) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
          _filterData();
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(
            horizontal: screenHeight * screenWidth * 0.000024),
        padding: EdgeInsets.symmetric(
            horizontal: screenHeight * screenWidth * 0.00004,
            vertical: screenHeight * screenWidth * 0.00002),
        decoration: BoxDecoration(
          color: _selectedTimeIndex == index ? strongViolet : lightBlack,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedTimeIndex == index ? Colors.white : darkGrey,
            fontSize: screenHeight * screenWidth * 0.000039,
          ),
        ),
      ),
    );
  }
}
