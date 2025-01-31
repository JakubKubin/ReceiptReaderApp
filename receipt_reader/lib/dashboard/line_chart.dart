import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:receipt_reader/models/chart_data.dart';

import '../../utils/colors.dart';

class LineChartWidget extends StatefulWidget {
  final List<ChartData> receiptsOverTime;

  const LineChartWidget({super.key, required this.receiptsOverTime});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

double calculateInterval(double maxX, double minX) {
  double range = maxX - minX;
  return (range / 10).roundToDouble();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  List<Color> gradientColors = [
    strongViolet,
    lightViolet,
    darkViolet,
    lightViolet,
  ];

  bool showAvg = false;

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 2,
          child: Padding(
            padding: const EdgeInsets.only(
              right: 1,
              left: 1,
              top: 1,
              bottom: 1,
            ),
            child: LineChart(
              showAvg ? avgData() : mainData(),
            ),
          ),
        ),
        Positioned(
          top: screenHeight * 0.004,
          left: screenWidth * 0.014,
          child: SizedBox(
            width: screenWidth * 0.2,
            height: screenHeight * 0.04,
            child: TextButton(
              onPressed: () {
                setState(() {
                  showAvg = !showAvg;
                });
              },
              child: Text(
                'avg',
                style: TextStyle(
                  fontSize: screenWidth * 0.025,
                  color: showAvg ? Colors.white.withOpacity(0.7) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double? lastDisplayedYAxisValue;

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: screenWidth * screenHeight * 0.0000255,
      color: darkGrey,
    );
    if (lastDisplayedYAxisValue != null &&
        (value - lastDisplayedYAxisValue!).abs() <
            (lastDisplayedYAxisValue! * 0.15)) {
      return const SizedBox.shrink();
    }

    lastDisplayedYAxisValue = value;

    return Text(value.toStringAsFixed(0),
        style: style, textAlign: TextAlign.center);
  }

  LineChartData mainData() {
    if (widget.receiptsOverTime.isEmpty) {
      return LineChartData(
        lineBarsData: [],
        titlesData: const FlTitlesData(show: false),
      );
    }

    double minX = widget.receiptsOverTime.first.date;
    double maxX = widget.receiptsOverTime.last.date;
    double maxY = widget.receiptsOverTime
        .map((data) => data.total)
        .reduce((a, b) => a > b ? a : b);

    double xInterval = calculateInterval(maxX, minX);
    if (xInterval == 0) xInterval = 1;

    double yInterval = (maxY / 5).roundToDouble();
    if (yInterval == 0) yInterval = 1;

    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: yInterval,
        verticalInterval: xInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: darkGrey.withOpacity(0.1),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: darkGrey.withOpacity(0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: screenWidth * screenHeight * 0.00005,
            interval: xInterval,
            getTitlesWidget: (value, meta) {
              final isCloseToLast = (maxX - value).abs() < (xInterval * 0.7);
              final isNotLastValue = value != maxX;

              if (isCloseToLast && isNotLastValue) {
                return const SizedBox.shrink();
              }
              final isCloseToFirst = (minX - value).abs() < (xInterval * 0.7);
              final isNotFirstValue = value != minX;

              if (isCloseToFirst && isNotFirstValue) {
                return const SizedBox.shrink();
              }

              DateTime date =
                  DateTime.fromMillisecondsSinceEpoch(value.toInt());
              String formattedDate = '${date.day}/${date.month}';
              final style = TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * screenHeight * 0.0000255,
                color: darkGrey,
              );

              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(formattedDate, style: style),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: screenWidth * 0.06,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: (maxY + (maxY * 0.2)).roundToDouble(),
      lineBarsData: [
        LineChartBarData(
          spots: widget.receiptsOverTime.map((data) {
            return FlSpot(data.date, data.total);
          }).toList(),
          isCurved: false,
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors
                  .map((color) => color.withOpacity(0.15))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData avgData() {
    if (widget.receiptsOverTime.isEmpty) {
      return LineChartData(
        lineBarsData: [],
        titlesData: const FlTitlesData(show: false),
      );
    }
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double minX = widget.receiptsOverTime.first.date;
    double maxX = widget.receiptsOverTime.last.date;
    double maxY = widget.receiptsOverTime
        .map((data) => data.total)
        .reduce((a, b) => a > b ? a : b);

    double xInterval = calculateInterval(maxX, minX);
    if (xInterval == 0) xInterval = 1;
    double yInterval = (maxY / 5).roundToDouble();
    if (yInterval == 0) yInterval = 1;
    double averageTotal = 0.0;
    if (widget.receiptsOverTime.isNotEmpty) {
      double sumTotal =
          widget.receiptsOverTime.fold(0.0, (sum, data) => sum + data.total);
      int count = widget.receiptsOverTime.length;
      averageTotal = (sumTotal / count).roundToDouble();
    }

    List<FlSpot> avgSpots = [
      FlSpot(minX, averageTotal),
      FlSpot(maxX, averageTotal),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: yInterval,
        verticalInterval: xInterval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: darkGrey.withOpacity(0.1),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: darkGrey.withOpacity(0.1),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: screenHeight * 0.025,
            interval: xInterval,
            getTitlesWidget: (value, meta) {
              final isCloseToLast = (maxX - value).abs() < (xInterval * 0.6);
              final isNotLastValue = value != maxX;

              if (isCloseToLast && isNotLastValue) {
                return const SizedBox.shrink();
              }
              final isCloseToFirst = (minX - value).abs() < (xInterval * 0.6);
              final isNotFirstValue = value != minX;

              if (isCloseToFirst && isNotFirstValue) {
                return const SizedBox.shrink();
              }

              DateTime date =
                  DateTime.fromMillisecondsSinceEpoch(value.toInt());
              String formattedDate = '${date.day}/${date.month}';
              final style = TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * screenHeight * 0.0000255,
                color: darkGrey,
              );

              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(formattedDate, style: style),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: yInterval,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: screenWidth *
                screenHeight *
                0.00007, //screenWidth * screenHeight * 0.0000255
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: (maxY + (maxY * 0.2)).round().toDouble(),
      lineBarsData: [
        LineChartBarData(
          spots: avgSpots,
          isCurved: false,
          gradient: LinearGradient(
            colors: gradientColors,
          ),
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(
            show: false,
          ),
          belowBarData: BarAreaData(
            show: false,
          ),
        ),
      ],
    );
  }
}
