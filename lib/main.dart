import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const OLTCApp());
}

class OLTCApp extends StatelessWidget {
  const OLTCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OLTC Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00BFA5),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    HistoryPage(),
    AnomaliesPage(),
    ChatbotPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber), label: 'Anomalies'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chatbot'),
        ],
      ),
    );
  }
}

// ── DASHBOARD ─────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> liveData = {};
  Timer? _timer;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchLive();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchLive());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchLive() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/live'));
      if (res.statusCode == 200) {
        setState(() {
          liveData = json.decode(res.body);
          loading = false;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('OLTC Monitor', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.build, color: Color(0xFF00E5FF), size: 28),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1A1A1A),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (context) => const MaintenanceModal(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── LIVE INDICATOR ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text('LIVE DATA', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── METRICS CARDS ──
                  Row(
                    children: [
                      Expanded(child: _buildEnhancedCard('Output Voltage', '${liveData['output_voltage'] ?? '0'}V', Icons.electrical_services, const Color(0xFF00E5FF), 0.85)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildEnhancedCard('Current', '${liveData['current'] ?? '0'}A', Icons.power_input, const Color(0xFF00BFA5), 0.85)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildEnhancedCard('Power', '${liveData['power'] ?? '0'}W', Icons.energy_savings_leaf, Colors.orange, 0.85)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildEnhancedCard('Temperature', '${liveData['temperature'] ?? '0'}°C', Icons.thermostat, Colors.red, 0.85)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── ACTIVE TAP SECTION ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1A1A1A), const Color(0xFF1A1A1A).withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 2),
                      boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.1), blurRadius: 12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Active SSR', style: TextStyle(color: Colors.grey, fontSize: 13, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TAP ${liveData['active_ssr'] ?? '0'}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 36, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                              ),
                              child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── TAP VOLTAGES ──
                  const Text('TAP CONFIGURATION', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: 15,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, i) {
                      bool isActive = (liveData['active_ssr'] ?? 0) == i + 1;
                      double tapVoltage = (liveData['taps'] != null && liveData['taps']['T${i + 1}'] != null) ? (liveData['taps']['T${i + 1}'] as num).toDouble() : 0;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(colors: [const Color(0xFF00E5FF).withValues(alpha: 0.3), const Color(0xFF00E5FF).withValues(alpha: 0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : LinearGradient(colors: [const Color(0xFF1A1A1A), const Color(0xFF1A1A1A)]),
                          border: Border.all(
                            color: isActive ? const Color(0xFF00E5FF) : Colors.grey.withValues(alpha: 0.2),
                            width: isActive ? 2.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), blurRadius: 8)] : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('T${i + 1}', style: TextStyle(color: isActive ? const Color(0xFF00E5FF) : Colors.grey, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text('${tapVoltage.toStringAsFixed(1)}V', style: TextStyle(color: isActive ? const Color(0xFF00E5FF) : Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildEnhancedCard(String label, String value, IconData icon, Color color, double aspectRatio) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A1A), const Color(0xFF1A1A1A).withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0.8)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── HISTORY ───────────────────────────────────────────
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/history?hours=24'));
      if (res.statusCode == 200) {
        setState(() {
          List<dynamic> allData = json.decode(res.body).reversed.toList();
history = allData.length > 50 ? allData.sublist(allData.length - 50) : allData;
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  List<FlSpot> _getVoltageSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i]['output_voltage'].toDouble()));
    }
    return spots;
  }

  List<FlSpot> _getTempSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i]['temperature'].toDouble()));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('History', style: TextStyle(color: Color(0xFF00E5FF))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)), onPressed: fetchHistory),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : history.isEmpty
              ? const Center(child: Text('No history yet.', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── VOLTAGE CHART ──
                      const Text('OUTPUT VOLTAGE (V)', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1),
                            ),
                            titlesData: const FlTitlesData(
                              show: true,
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                            ),
                            borderData: FlBorderData(show: false),
                            minY: 100,
                            maxY: 120,
                            lineBarsData: [
                              // Stable band reference lines
                              LineChartBarData(
                                spots: List.generate(history.length, (i) => FlSpot(i.toDouble(), 111.5)),
                                color: Colors.orange.withValues(alpha: 0.3),
                                barWidth: 1,
                                dotData: const FlDotData(show: false),
                                dashArray: [4, 4],
                              ),
                              LineChartBarData(
                                spots: List.generate(history.length, (i) => FlSpot(i.toDouble(), 108.5)),
                                color: Colors.orange.withValues(alpha: 0.3),
                                barWidth: 1,
                                dotData: const FlDotData(show: false),
                                dashArray: [4, 4],
                              ),
                              // Actual voltage line
                              LineChartBarData(
                                spots: _getVoltageSpots(),
                                isCurved: true,
                                color: const Color(0xFF00E5FF),
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── TEMPERATURE CHART ──
                      const Text('TEMPERATURE (°C)', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Container(
                        height: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 40,
    interval: 5,
    getTitlesWidget: (value, meta) => Text(
      value.toInt().toString(),
      style: const TextStyle(color: Colors.grey, fontSize: 10),
    ),
  ),
),
                            ),
                            borderData: FlBorderData(show: false),
minY: 28,
maxY: 55,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _getTempSpots(),
                                isCurved: true,
                                color: Colors.orange,
                                barWidth: 2.5,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.orange.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── RAW DATA LIST ──
                      const Text('RECENT READINGS', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      ...history.reversed.take(15).map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r['timestamp'].toString().substring(11, 19),
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('${r['output_voltage']}V', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                            Text('${r['current']}A', style: const TextStyle(color: Color(0xFF00BFA5))),
                            Text('${r['temperature']}°C', style: const TextStyle(color: Colors.orange)),
                            Text('TAP${r['active_ssr']}', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }
}

// ── ANOMALIES ─────────────────────────────────────────
class AnomaliesPage extends StatefulWidget {
  const AnomaliesPage({super.key});

  @override
  State<AnomaliesPage> createState() => _AnomaliesPageState();
}

class _AnomaliesPageState extends State<AnomaliesPage> {
  List<dynamic> anomalies = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAnomalies();
  }

  Future<void> fetchAnomalies() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/anomalies'));
      if (res.statusCode == 200) {
        setState(() {
          anomalies = json.decode(res.body);
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Anomalies', style: TextStyle(color: Color(0xFF00E5FF))),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)), onPressed: fetchAnomalies),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : anomalies.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 64),
                      SizedBox(height: 16),
                      Text('No anomalies detected', style: TextStyle(color: Colors.green, fontSize: 18)),
                      Text('System operating normally', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: anomalies.length,
                  itemBuilder: (context, i) {
                    final a = anomalies[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Text(a['type'].toString().replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(a['message'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(a['timestamp'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ── CHATBOT ───────────────────────────────────────────
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'role': 'bot', 'text': 'Hello! I am your OLTC assistant. Ask me about voltage, temperature, tap status, or anomalies.'}
  ];
  bool _thinking = false;

  final List<String> _suggestions = [
    'What is the current voltage?',
    'Is temperature normal?',
    'Which tap is active?',
    'Any anomalies detected?',
  ];

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _thinking = true;
    });
    _controller.clear();

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': text}),
      );

      String reply = 'Sorry, something went wrong.';
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        reply = data['answer'] ?? reply;
      }

      setState(() {
        _messages.add({'role': 'bot', 'text': reply});
        _thinking = false;
      });
    } catch (_) {
      setState(() {
        _messages.add({'role': 'bot', 'text': 'Could not connect to backend. Make sure backend.py and Ollama are running.'});
        _thinking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('OLTC Assistant', style: TextStyle(color: Color(0xFF00E5FF))),
      ),
      body: Column(
        children: [
          // Suggestions
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _suggestions.map((s) => GestureDetector(
                onTap: () => _sendMessage(s),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                  ),
                  child: Text(s, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                ),
              )).toList(),
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (_thinking && i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Thinking...', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                  );
                }
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isUser ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1A1A1A),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask about your transformer...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_controller.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MAINTENANCE MODAL ──
class MaintenanceModal extends StatefulWidget {
  const MaintenanceModal({super.key});

  @override
  State<MaintenanceModal> createState() => _MaintenanceModalState();
}

class _MaintenanceModalState extends State<MaintenanceModal> {
  Map<String, dynamic> maintenance = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMaintenance();
  }

  Future<void> fetchMaintenance() async {
    try {
      final res = await http.get(Uri.parse('http://localhost:8000/maintenance'));
      if (res.statusCode == 200) {
        setState(() {
          maintenance = json.decode(res.body);
          loading = false;
        });
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Color _getHealthColor(String? color) {
    switch (color) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'orange':
        return Colors.deepOrange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Predictive Maintenance',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 18, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getHealthColor(maintenance['health_color']).withValues(alpha: 0.1),
                    border: Border.all(color: _getHealthColor(maintenance['health_color']), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            maintenance['health_status'] ?? 'Loading...',
                            style: TextStyle(
                              color: _getHealthColor(maintenance['health_color']),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getHealthColor(maintenance['health_color']),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${maintenance['estimated_days_to_maintenance'] ?? 0} days',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMetricRow('Average Temperature', '${maintenance['avg_temperature'] ?? '0'}°C'),
                      _buildMetricRow('Maximum Temperature', '${maintenance['max_temperature'] ?? '0'}°C'),
                      _buildMetricRow('Tap Switches (Recent)', '${maintenance['tap_switches_recent'] ?? '0'} times'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This score is based on tap-switching frequency and thermal stress. Regular maintenance ensures optimal transformer performance.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}