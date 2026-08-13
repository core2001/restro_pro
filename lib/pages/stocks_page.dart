import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class StocksPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const StocksPage({super.key, required this.onUpdate});

  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  List<Map<String, dynamic>> stocks = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController alert = TextEditingController();
  final TextEditingController initialQty = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    stocks = await DBHelper.getStocks();
    if (mounted) setState(() {});
  }

  Future<void> save() async {
    if (_formKey.currentState!.validate()) {
      await DBHelper.addStock({
        'name': name.text.trim(),
        'qty': double.parse(initialQty.text),
        'initial_qty': double.parse(initialQty.text),
        'unit': 'plate',
        'unit_price': double.parse(price.text),
        'low_alert': double.parse(alert.text)
      });
      if (mounted) Navigator.pop(context);
      clearForm();
      await load();
      widget.onUpdate();
    }
  }

  void clearForm() {
    name.clear();
    qty.clear();
    price.clear();
    alert.clear();
    initialQty.clear();
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New Meal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Meal Name'), validator: (v) => v!.trim().isEmpty? 'Required' : null),
              TextFormField(controller: initialQty, decoration: const InputDecoration(labelText: 'Initial Qty'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty? 'Required' : null),
              TextFormField(controller: price, decoration: const InputDecoration(labelText: 'Unit Price \$'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty? 'Required' : null),
              TextFormField(controller: alert, decoration: const InputDecoration(labelText: 'Low Stock Alert At'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty? 'Required' : null),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: save, child: const Text('Save'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))
        ],
      ),
    );
  }

  void deleteAll() {
    int countdown = 10;
    bool canDelete = false;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setState) {
            Future.delayed(const Duration(seconds: 1), () {
              if (countdown > 0 && mounted) setState(() => countdown--);
              if (countdown == 0) setState(() => canDelete = true);
            });
            return AlertDialog(
              title: const Text('⚠️ DELETE ALL DATA'),
              content: Text('This will delete all stocks and reset total revenue to zero. This cannot be undone.\n\nEnable "Yes" in $countdown seconds'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: canDelete
                      ? () async {
                            await DBHelper.deleteAllData();
                            if (mounted) Navigator.pop(context);
                            await load();
                            widget.onUpdate();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(canDelete? 'Yes, Delete All' : 'Wait...'))
              ],
            );
          });
        });
  }

  void confirmDeleteStock(Map<String, dynamic> s) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Delete ${s['name']}?'),
              content: const Text('This will remove the stock and deduct its total sales from revenue.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      await DBHelper.deleteStock(s['id']);
                      if (mounted) Navigator.pop(context);
                      await load();
                      widget.onUpdate();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('Manage Stocks', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(heroTag: 'deleteAll', onPressed: deleteAll, backgroundColor: Colors.red, child: const Icon(Icons.delete_forever)),
          const SizedBox(height: 12),
          FloatingActionButton(heroTag: 'add', onPressed: showAddDialog, backgroundColor: Colors.orange, child: const Icon(Icons.add)),
        ],
      ),
      body: stocks.isEmpty
         ? const Center(child: Text('No meals added yet'))
          : ListView(padding: const EdgeInsets.all(12), children: stocks.map((s) => _stockCard(s)).toList()),
    );
  }

  Widget _stockCard(Map<String, dynamic> s) {
    double qty = (s['qty'] as num).toDouble();
    double initial = ((s['initial_qty']?? s['qty']) as num).toDouble();
    double percent = initial > 0? qty / initial : 0;
    bool low = qty <= (s['low_alert'] as num).toDouble();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StockStatsPage(stock: s))),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(s['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => confirmDeleteStock(s))
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price: \$${(s['unit_price'] as num).toDouble().toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: low? Colors.red.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                    child: Text(low? 'Low Stock' : 'In Stock', style: TextStyle(color: low? Colors.red : Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text('Current: ${qty.toStringAsFixed(1)} / Initial: ${initial.toStringAsFixed(1)}'),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: percent.clamp(0, 1), minHeight: 8, backgroundColor: Colors.grey.shade200, color: low? Colors.red : Colors.orange),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.orange),
                      onPressed: () {
                        TextEditingController c = TextEditingController();
                        showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                                  title: Text('Top Up ${s['name']}'),
                                  content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty to add')),
                                  actions: [
                                    ElevatedButton(
                                        onPressed: () async {
                                          if(c.text.isEmpty) return;
                                          await DBHelper.topUpStock(s['id'], double.parse(c.text));
                                          if (mounted) Navigator.pop(context);
                                          await load();
                                          widget.onUpdate();
                                        },
                                        child: const Text('Add'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))
                                  ],
                                ));
                      }),
                  const Text('Top Up')
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// PRO STATS PAGE WITH PIE + BAR + LINE CHARTS
class StockStatsPage extends StatefulWidget {
  final Map<String, dynamic> stock;
  const StockStatsPage({super.key, required this.stock});

  @override
  State<StockStatsPage> createState() => _StockStatsPageState();
}

class _StockStatsPageState extends State<StockStatsPage> {
  List<Map<String, dynamic>> history = [];
  bool loading = true;
  int touchedPieIndex = -1;
  int touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    history = await DBHelper.getStockHistory(widget.stock['id']);
    if (mounted) setState(() => loading = false);
  }

  DateTime _safeParseDate(dynamic date) {
    try {
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      if (date is String) return DateTime.parse(date.replaceAll(' ', 'T'));
    } catch (e) {
      debugPrint("Date parse error: $e");
    }
    return DateTime.now();
  }

  String generateFeedback() {
    if (history.isEmpty) return "No data yet. Start selling to see insights.";
    double sold = 0;
    double topup = 0;
    for (var h in history) {
      if (h['type'] == 'SALE') sold += (-(h['qty_change'] as num).toDouble());
      if (h['type'] == 'TOPUP') topup += (h['qty_change'] as num).toDouble();
    }
    double current = (widget.stock['qty'] as num).toDouble();
    double alert = (widget.stock['low_alert'] as num).toDouble();
    if (current <= alert) return "⚠️ URGENT: ${widget.stock['name']} is low on stock. Only ${current.toStringAsFixed(1)} left. Top up now!";
    if (sold > topup * 2) return "🔥 HOT ITEM: ${widget.stock['name']} sold ${sold.toStringAsFixed(0)}. Demand is high. Increase stock!";
    if (sold < 5 && topup > 20) return "📉 SLOW MOVER: ${widget.stock['name']} isn't selling. Consider a discount or combo.";
    return "✅ STEADY: ${widget.stock['name']} is selling well. Current stock: ${current.toStringAsFixed(1)}";
  }

  @override
  Widget build(BuildContext context) {
    double current = (widget.stock['qty'] as num).toDouble();
    double initial = ((widget.stock['initial_qty']?? current) as num).toDouble();
    double sold = (initial - current).clamp(0, double.infinity);

    List<FlSpot> stockSpots = [];
    List<FlSpot> saleSpots = [];
    for (int i = 0; i < history.length; i++) {
      var h = history[i];
      stockSpots.add(FlSpot(i.toDouble(), (h['qty_after'] as num).toDouble()));
      if (h['type'] == 'SALE') saleSpots.add(FlSpot(i.toDouble(), (h['qty_after'] as num).toDouble()));
    }

    Map<String, double> salesByDay = {};
    Map<String, double> topupsByDay = {};
    for (var h in history) {
      String day = DateFormat('dd/MM').format(_safeParseDate(h['date']));
      if (h['type'] == 'SALE') salesByDay[day] = (salesByDay[day]?? 0) + (-(h['qty_change'] as num).toDouble());
      if (h['type'] == 'TOPUP') topupsByDay[day] = (topupsByDay[day]?? 0) + (h['qty_change'] as num).toDouble();
    }
    List<String> last7Days = salesByDay.keys.toList().reversed.take(7).toList().reversed.toList();

    if (loading) {
      return Scaffold(appBar: AppBar(title: Text(widget.stock['name'])), body: const Center(child: CircularProgressIndicator(color: Colors.orange)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.stock['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Analytics for ${widget.stock['name']}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Stock Breakdown', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    history.isEmpty
                      ? const Center(child: Text('No history yet', style: TextStyle(color: Colors.grey)))
                        : AspectRatio(
                            aspectRatio: 1.3,
                            child: PieChart(PieChartData(
                                pieTouchData: PieTouchData(touchCallback: (event, response) {
                                  setState(() {
                                    touchedPieIndex = response?.touchedSection?.touchedSectionIndex?? -1;
                                  });
                                }),
                                sectionsSpace: 2,
                                sections: [
                                  PieChartSectionData(color: Colors.orange, value: current, title: '${current.toStringAsFixed(0)}', radius: touchedPieIndex == 0? 60 : 50, titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  PieChartSectionData(color: Colors.red.shade400, value: sold, title: '${sold.toStringAsFixed(0)}', radius: touchedPieIndex == 1? 60 : 50, titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))
                                ],
                                centerSpaceRadius: 30))),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [_legend(Colors.orange, 'In Stock'), const SizedBox(width: 16), _legend(Colors.red.shade400, 'Sold')])
                  ]))),
          const SizedBox(height: 20),
          Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Last 7 Days Activity', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    last7Days.isEmpty
                      ? const Center(child: Text('No activity in last 7 days', style: TextStyle(color: Colors.grey)))
                        : AspectRatio(
                            aspectRatio: 1.6,
                            child: BarChart(BarChartData(
                                barTouchData: BarTouchData(touchCallback: (event, response) {
                                  setState(() {
                                    touchedBarIndex = response?.spot?.touchedBarGroupIndex?? -1;
                                  });
                                }),
                                titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
                                      if (v.toInt() < last7Days.length) return Padding(padding: const EdgeInsets.only(top: 4), child: Text(last7Days[v.toInt()], style: const TextStyle(fontSize: 10)));
                                      return const Text('');
                                    })),
                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(last7Days.length, (i) {
                                  String day = last7Days[i];
                                  return BarChartGroupData(x: i, barRods: [
                                    BarChartRodData(toY: salesByDay[day]?? 0, color: Colors.red, width: 8, borderRadius: BorderRadius.circular(4)),
                                    BarChartRodData(toY: topupsByDay[day]?? 0, color: Colors.green, width: 8, borderRadius: BorderRadius.circular(4))
                                  ], showingTooltipIndicators: touchedBarIndex == i? [0, 1] : []);
                                }),
                                groupsSpace: 12))),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [_legend(Colors.red, 'Sales'), const SizedBox(width: 16), _legend(Colors.green, 'Topups')])
                  ]))),
          const SizedBox(height: 20),
          Text('Stock Level Over Time', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          stockSpots.isEmpty
            ? const Center(child: Text('No history to show', style: TextStyle(color: Colors.grey)))
              : AspectRatio(
                  aspectRatio: 1.7,
                  child: LineChart(LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) => Text('D${v.toInt() + 1}', style: const TextStyle(fontSize: 10)))),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(spots: stockSpots, isCurved: true, color: Colors.orange, barWidth: 3, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.2))),
                        LineChartBarData(spots: saleSpots, color: Colors.red, barWidth: 0, dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 5, color: Colors.red, strokeWidth: 2, strokeColor: Colors.white)))
                      ]))),
          const SizedBox(height: 24),
          Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Feedback', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(generateFeedback(), style: const TextStyle(fontSize: 14))
                  ]))),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 12))]);
  }
}