// dashboard/overview_statistic_widget.dart

import 'package:flutter/material.dart';
import 'package:receipt_reader/models/chart_data.dart';

import '../../utils/colors.dart';
import 'line_chart.dart';

class OverviewStatistic extends StatefulWidget {
  final double totalSpent;
  final List<ChartData> receiptsOverTime;

  const OverviewStatistic({
    super.key,
    required this.totalSpent,
    required this.receiptsOverTime,
  });

  @override
  State<OverviewStatistic> createState() => _OverviewStatisticState();
}

class _OverviewStatisticState extends State<OverviewStatistic> {
  int _selectedTimeIndex = 1;
  final List<String> _times = ['1W', '1M', '1Y', 'MAX'];
  List<ChartData> _filteredReceiptsOverTime = [];
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

    _filteredReceiptsOverTime = widget.receiptsOverTime
        .where((data) => DateTime.fromMillisecondsSinceEpoch(data.date.toInt())
            .isAfter(fromDate))
        .toList();

    for (var i = 0; i < _filteredReceiptsOverTime.length; i++) {
      final data = _filteredReceiptsOverTime[i];
      if (i == 0) {
        if (data == widget.receiptsOverTime.first) {
          totalInTime += data.total;
        } else {
          for (var j = 0; j < widget.receiptsOverTime.length; j++) {
            if (data == widget.receiptsOverTime[j]) {
              totalInTime += widget.receiptsOverTime[j].total -
                  widget.receiptsOverTime[j - 1].total;
            }
          }
        }
      } else {
        totalInTime += (_filteredReceiptsOverTime[i].total -
            _filteredReceiptsOverTime[i - 1].total);
      }
    }
    setState(() {});
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
          minHeight: screenHeight * 0.25,
          maxWidth: screenWidth * 0.95,
          maxHeight: screenHeight * 0.27),
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.01,
        horizontal: screenWidth * 0.035,
      ),
      decoration: BoxDecoration(
        color: lightBlack,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
          Expanded(
            child: LineChartWidget(
              receiptsOverTime: _filteredReceiptsOverTime,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(BuildContext context, int index, String label) {
    double screenHeight = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
          _filterData();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _selectedTimeIndex == index ? strongViolet : lightBlack,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _selectedTimeIndex == index ? Colors.white : darkGrey,
            fontSize: screenHeight * 0.015,
          ),
        ),
      ),
    );
  }
}
