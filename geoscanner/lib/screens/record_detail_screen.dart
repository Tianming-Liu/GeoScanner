import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geoscanner/widgets/animated_map.dart';

class RecordDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recordData;

  const RecordDetailScreen({Key? key, required this.recordData})
      : super(key: key);

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  String _selectedSensor = 't';

  // Map the sensor key to the sensor name
  final Map<String, String> _sensorNameMap = {
    't': 'Temperature',
    'h': 'Humidity',
    'p': 'Pressure',
    'g': 'Gas',
    'no': 'Noise',
    'mvc': 'Motor Vehicles',
    'nmvc': 'Non-Motor Vehicles',
    'pc': 'People Count',
    'sp': 'Sky Percentage',
    'tp': 'Tree Percentage',
  };

  // load local svg file to display the sensor icon
  final Map<String, IconData> _sensorIconMap = {
    'g': Icons.grain,
    'h': Icons.water_drop,
    'p': Icons.air,
    't': Icons.thermostat,
    'no': Icons.graphic_eq,
    'mvc': Icons.directions_car,
    'nmvc': Icons.directions_bike,
    'pc': Icons.emoji_people,
    'sp': Icons.cloud,
    'tp': Icons.nature,
  };

  Map<String, Map<String, double>> _calculateStats() {
    Map<String, Map<String, double>> stats = {
      for (var key in _sensorNameMap.keys)
        key: {
          'avg': 0.0,
          'max': double.negativeInfinity,
          'min': double.infinity
        }
    };

    Map<String, List<double>> values = {
      for (var key in _sensorNameMap.keys) key: []
    };

    for (var entry in widget.recordData['sensorData']) {
      for (var key in _sensorNameMap.keys) {
        double? value;
        if (entry['sensorData'] != null && entry['sensorData'][key] != null) {
          value = (entry['sensorData'][key] as num).toDouble();
        } else if (entry['phoneData'] != null &&
            entry['phoneData'][key] != null) {
          value = (entry['phoneData'][key] as num).toDouble();
        } else if (entry['dlData'] != null && entry['dlData'][key] != null) {
          value = (entry['dlData'][key] as num).toDouble();
        }

        if (value != null) {
          values[key]!.add(value);
        }
      }
    }

    for (var key in _sensorNameMap.keys) {
      if (values[key]!.isNotEmpty) {
        stats[key]!['avg'] =
            values[key]!.reduce((a, b) => a + b) / values[key]!.length;
        stats[key]!['max'] = values[key]!.reduce((a, b) => a > b ? a : b);
        stats[key]!['min'] = values[key]!.reduce((a, b) => a < b ? a : b);
      } else {
        stats[key]!['avg'] = double.nan;
        stats[key]!['max'] = double.nan;
        stats[key]!['min'] = double.nan;
      }
    }

    return stats;
  }

  List<FlSpot> _createSensorDataSpots() {
    List<FlSpot> spots = [];
    int index = 0;
    for (var entry in widget.recordData['sensorData']) {
      double? value;
      if (entry['sensorData'] != null &&
          entry['sensorData'][_selectedSensor] != null) {
        value = entry['sensorData'][_selectedSensor];
      } else if (entry['phoneData'] != null &&
          entry['phoneData'][_selectedSensor] != null) {
        value = entry['phoneData'][_selectedSensor];
      } else if (entry['dlData'] != null &&
          entry['dlData'][_selectedSensor] != null) {
        value = entry['dlData'][_selectedSensor];
      }

      if (value != null) {
        spots.add(FlSpot(index.toDouble(), value));
        index++;
      }
    }
    return spots;
  }

  Map<String, double> _calculateYRange(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return {'minY': 0, 'maxY': 0};
    }

    double minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    // Leave 10% padding on the top and bottom
    double range = maxY - minY;
    double padding = range * 0.2; // 10% padding

    return {'minY': minY - padding, 'maxY': maxY + padding};
  }

  double _calculateAverageValue() {
    List<FlSpot> spots = _createSensorDataSpots();
    if (spots.isEmpty) return 0.0;
    double sum = spots.map((spot) => spot.y).reduce((a, b) => a + b);
    return sum / spots.length;
  }

  String _getSensorUnit(String sensorKey) {
    final Map<String, String> sensorUnits = {
      't': '°C',
      'h': '%',
      'p': 'hPa',
      'g': 'ppm',
      'no': 'dB',
      'mvc': 'count',
      'nmvc': 'count',
      'pc': 'count',
      'sp': '%',
      'tp': '%',
    };
    return sensorUnits[sensorKey] ?? '';
  }

  String _formatStartTime(String time) {
    List<String> parts = time.split('_');
    String datePart = parts[0];
    String timePart = parts[1];

    List<String> timeParts = timePart.split(':');
    String hours = timeParts[0].padLeft(2, '0');
    String minutes = timeParts[1].padLeft(2, '0');
    String seconds = timeParts[2].padLeft(2, '0');

    return '$datePart    $hours:$minutes:$seconds';
  }

  String _formatEndTime(String time) {
    List<String> parts = time.split('_');
    String timePart = parts[1];

    List<String> timeParts = timePart.split(':');
    String hours = timeParts[0].padLeft(2, '0');
    String minutes = timeParts[1].padLeft(2, '0');
    String seconds = timeParts[2].padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _getTimeRange() {
    String startTime = _formatStartTime(widget.recordData['startTime']);
    String endTime = _formatEndTime(widget.recordData['endTime']);
    return '$startTime - $endTime';
  }

  List<LatLng> _createRouteCoords() {
    List<LatLng> routeCoords = [];
    for (var entry in widget.recordData['sensorData']) {
      var phoneData = entry['phoneData'];
      if (phoneData != null &&
          phoneData['la'] != null &&
          phoneData['lo'] != null) {
        double lat = phoneData['la'];
        double lng = phoneData['lo'];
        routeCoords.add(LatLng(lat, lng));
      }
    }
    return routeCoords;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, double>> stats = _calculateStats();
    List<FlSpot> spots = _createSensorDataSpots();
    Map<String, double> yRange = _calculateYRange(spots);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Record Detail',
          style: TextStyle(
              fontFamily: GoogleFonts.marcellus().fontFamily,
              color: const Color.fromARGB(255, 75, 75, 75),
              fontSize: 22,
              fontWeight: FontWeight.w400),
        ),
        backgroundColor: const Color.fromARGB(255, 245, 245, 245),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: const Color.fromARGB(255, 190, 190, 190),
            height: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(2, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              height: 175.0, // 设定 ListView 的高度，使其只占据屏幕的一小部分
              child: ListView.builder(
                itemCount: _sensorNameMap.keys.length,
                itemBuilder: (context, index) {
                  String key = _sensorNameMap.keys.elementAt(index);
                  String name = _sensorNameMap[key] ?? key;
                  IconData sensorIcon = _sensorIconMap[key]!;
                  double avg = stats[key]!['avg']!;
                  double max = stats[key]!['max']!;
                  double min = stats[key]!['min']!;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSensor = key;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: _selectedSensor == key
                              ? const Color.fromARGB(255, 0, 122, 255)
                              : Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.1,
                              child: Icon(sensorIcon,
                                  color: _selectedSensor == key
                                      ? const Color.fromARGB(255, 252, 252, 252)
                                      : Colors.black),
                            ),
                            // add a line to separate the elements
                            Container(
                              height: 20,
                              width: 1,
                              color: _selectedSensor == key
                                  ? const Color.fromARGB(255, 252, 252, 252)
                                  : const Color.fromARGB(255, 145, 145, 145),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.3,
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.roboto(
                                  textStyle: TextStyle(
                                    color: _selectedSensor == key
                                        ? const Color.fromARGB(
                                            255, 255, 255, 255)
                                        : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 20,
                              width: 1,
                              color: _selectedSensor == key
                                  ? const Color.fromARGB(255, 252, 252, 252)
                                  : const Color.fromARGB(255, 145, 145, 145),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.15,
                              child: Column(
                                children: [
                                  Text(
                                    avg.isNaN ? 'N/A' : avg.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                    ),
                                  ),
                                  Text(
                                    'AVG',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                      fontWeight: FontWeight.w100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 20,
                              width: 1,
                              color: _selectedSensor == key
                                  ? const Color.fromARGB(255, 252, 252, 252)
                                  : const Color.fromARGB(255, 145, 145, 145),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.15,
                              child: Column(
                                children: [
                                  Text(
                                    max.isNaN ? 'N/A' : max.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                    ),
                                  ),
                                  Text(
                                    'MAX',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                      fontWeight: FontWeight.w100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 20,
                              width: 1,
                              color: _selectedSensor == key
                                  ? const Color.fromARGB(255, 252, 252, 252)
                                  : const Color.fromARGB(255, 145, 145, 145),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.15,
                              child: Column(
                                children: [
                                  Text(
                                    min.isNaN ? 'N/A' : min.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                    ),
                                  ),
                                  Text(
                                    'MIN',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _selectedSensor == key
                                          ? const Color.fromARGB(
                                              255, 255, 255, 255)
                                          : Colors.black,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily,
                                      fontWeight: FontWeight.w100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 15.0, left: 10.0, right: 10.0),
            child: SizedBox(
              height: 150.0,
              child: LineChart(
                LineChartData(
                  minY: yRange['minY'],
                  maxY: yRange['maxY'],
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color.fromARGB(255, 0, 122, 255),
                      barWidth: 4,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromARGB(255, 218, 236, 255),
                            Color.fromARGB(255, 246, 250, 255),
                          ],
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: GoogleFonts.roboto(
                              textStyle: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              value.toInt().toString(),
                              style: GoogleFonts.roboto(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Text(
                          _getTimeRange(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      axisNameSize: 30,
                      sideTitles: const SideTitles(
                        showTitles: false,
                        reservedSize: 0,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      axisNameWidget: RotatedBox(
                        quarterTurns: 4,
                        child: Text(
                          '${_sensorNameMap[_selectedSensor]} (${_getSensorUnit(_selectedSensor)})',
                          style: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      axisNameSize: 24,
                      sideTitles: const SideTitles(
                        showTitles: false,
                        reservedSize: 0,
                      ),
                    ),
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: false,
                    verticalInterval: 1,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: _calculateAverageValue(),
                        color: const Color.fromARGB(255, 50, 50, 50),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 5, top: 15),
                          style: GoogleFonts.roboto(
                            textStyle: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
            child: Text(
              'Sensing Route',
              style: TextStyle(
                  fontFamily: GoogleFonts.roboto().fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.37,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: AnimatedMap(
              routeCoordinates: _createRouteCoords(),
              showLocationMarker: false,
            ),
          ),
        ],
      ),
    );
  }
}
