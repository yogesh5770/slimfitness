import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:animate_do/animate_do.dart';

class WeightChartView extends StatefulWidget {
  final String? userId; // null = current user, otherwise admin viewing a member
  const WeightChartView({super.key, this.userId});

  @override
  State<WeightChartView> createState() => _WeightChartViewState();
}

class _WeightChartViewState extends State<WeightChartView> {
  final _db = FirebaseDatabase.instance.ref();
  List<FlSpot> _spots = [];
  double _minWeight = 0;
  double _maxWeight = 100;
  List<String> _dateLabels = [];

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  String get _uid => widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  void _loadWeightData() async {
    final snap = await _db.child('weight_logs/$_uid').get();
    if (!snap.exists) return;

    final data = Map<String, dynamic>.from(snap.value as Map);
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Take last 30 entries
    final recent = sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;

    List<FlSpot> spots = [];
    List<String> labels = [];
    double min = double.infinity, max = double.negativeInfinity;

    for (int i = 0; i < recent.length; i++) {
      final w = (recent[i].value as num).toDouble();
      spots.add(FlSpot(i.toDouble(), w));
      labels.add(recent[i].key.split('-').sublist(1).join('/'));
      if (w < min) min = w;
      if (w > max) max = w;
    }

    if (mounted) {
      setState(() {
        _spots = spots;
        _dateLabels = labels;
        _minWeight = (min - 5).clamp(0, 500);
        _maxWeight = max + 5;
      });
    }
  }

  void _logWeight() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('LOG WEIGHT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '72.5',
            hintStyle: const TextStyle(color: Colors.white12),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            filled: true, fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () async {
              final w = double.tryParse(controller.text.trim());
              if (w != null && w > 0) {
                final now = DateTime.now();
                final key = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                await _db.child('weight_logs/$_uid/$key').set(w);
                Navigator.pop(ctx);
                _loadWeightData();
              }
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        title: const Text('WEIGHT PROGRESS', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      floatingActionButton: widget.userId == null
          ? FloatingActionButton(
              onPressed: _logWeight,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('LAST 30 ENTRIES', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        if (_spots.isNotEmpty)
                          Text('${_spots.last.y.toStringAsFixed(1)} kg', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: _spots.isEmpty
                          ? const Center(child: Text('No data yet. Log your first weight!', style: TextStyle(color: Colors.white24, fontSize: 12)))
                          : LineChart(
                              LineChartData(
                                minY: _minWeight,
                                maxY: _maxWeight,
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: const TextStyle(color: Colors.white24, fontSize: 9)))),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _spots,
                                    isCurved: true,
                                    color: Theme.of(context).primaryColor,
                                    barWidth: 3,
                                    dotData: FlDotData(show: _spots.length < 15),
                                    belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withOpacity(0.1)),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
