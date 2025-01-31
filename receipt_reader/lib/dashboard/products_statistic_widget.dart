import 'package:flutter/material.dart';
import 'package:receipt_reader/models/chart_data.dart';
import 'package:receipt_reader/models/product.dart';
import 'package:receipt_reader/widgets/bar_graph.dart';

import '../../utils/colors.dart';

class CategoryStatistic extends StatelessWidget {
  final List<Product> filteredProducts;
  final int selectedTimeIndex;
  final ValueChanged<int> onTimeSelected;

  CategoryStatistic({
    super.key,
    required this.filteredProducts,
    required this.selectedTimeIndex,
    required this.onTimeSelected,
  });

  final List<String> _times = ['1W', '1M', '1Y', 'MAX'];

  List<ChartData> _groupData(List<Product> products, int timeIndex) {
    if (timeIndex == 0 || timeIndex == 1) {
      return _groupByDay(products);
    } else if (timeIndex == 2) {
      return _groupByMonth(products);
    } else {
      return _groupByDay(products);
    }
  }

  List<ChartData> _groupByDay(List<Product> products) {
    final Map<String, double> dailyTotals = {};
    for (var product in products) {
      if (product.receiptDate == null || product.price == null) continue;
      final dateKey = "${product.receiptDate!.year}-"
          "${product.receiptDate!.month.toString().padLeft(2, '0')}-"
          "${product.receiptDate!.day.toString().padLeft(2, '0')}";

      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + product.price!;
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

  List<ChartData> _groupByMonth(List<Product> products) {
    final Map<String, double> monthlyTotals = {};
    for (var product in products) {
      if (product.receiptDate == null || product.price == null) continue;
      final dateKey = "${product.receiptDate!.year}-"
          "${product.receiptDate!.month.toString().padLeft(2, '0')}";

      monthlyTotals[dateKey] = (monthlyTotals[dateKey] ?? 0) + product.price!;
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

    final double totalInTime = filteredProducts.fold(
      0.0,
      (sum, product) => sum + (product.price ?? 0),
    );

    final List<ChartData> chartData =
        _groupData(filteredProducts, selectedTimeIndex);

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
                    .asMap()
                    .entries
                    .map((e) => _buildTimeSelector(context, e.key, e.value))
                    .toList(),
              ),
            ],
          ),
          SizedBox(height: screenWidth * screenHeight * 0.00001),
          // Chart
          Expanded(
            child: BarGraphWidget(
              chartDataList: chartData,
              selectedTimeIndex: selectedTimeIndex,
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
        onTimeSelected(index);
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: screenHeight * screenWidth * 0.000024,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: screenHeight * screenWidth * 0.00004,
          vertical: screenHeight * screenWidth * 0.00002,
        ),
        decoration: BoxDecoration(
          color: (selectedTimeIndex == index) ? strongViolet : lightBlack,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: (selectedTimeIndex == index) ? Colors.white : darkGrey,
            fontSize: screenHeight * screenWidth * 0.000039,
          ),
        ),
      ),
    );
  }
}
