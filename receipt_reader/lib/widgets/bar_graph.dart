// widgets/bar_graph.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/models/chart_data.dart';
import 'package:receipt_reader/utils/colors.dart';

class BarGraphWidget extends StatelessWidget {
  final List<ChartData> chartDataList;
  final int selectedTimeIndex;

  const BarGraphWidget({
    super.key,
    required this.chartDataList,
    required this.selectedTimeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = chartDataList.isNotEmpty
        ? chartDataList.map((e) => e.total).reduce((a, b) => a > b ? a : b)
        : 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize = screenWidth * screenHeight * 0.000023;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: double.tryParse(maxY.toStringAsFixed(2)),
        barGroups: chartDataList.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.total,
                color: strongViolet,
                width: screenWidth * 0.033,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: screenWidth * screenHeight * 0.00008,
                getTitlesWidget: (value, meta) {
                  if ((value - maxY).abs() < (maxY * 0.1) && value != maxY) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(color: Colors.white, fontSize: fontSize),
                  );
                }),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= chartDataList.length) {
                  return const SizedBox.shrink();
                }

                final chartData = chartDataList[index];

                final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  chartData.date.toInt(),
                );

                final month = dateTime.month.toString().padLeft(2, '0');

                switch (selectedTimeIndex) {
                  case 0:
                  case 1:
                  case 3:
                    final day = dateTime.day.toString().padLeft(2, '0');
                    return Text(
                      '$day-$month',
                      style: TextStyle(
                        color: white,
                        fontSize: fontSize,
                      ),
                    );
                  case 2:
                    final year = dateTime.year;
                    return Text(
                      '$month-$year',
                      style: TextStyle(
                        color: white,
                        fontSize: fontSize,
                      ),
                    );
                  default:
                    // Fallback
                    return Text(
                      meta.formattedValue,
                      style: TextStyle(
                        color: white,
                        fontSize: fontSize,
                      ),
                    );
                }
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }
}
