import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
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
  TextEditingController name = TextEditingController();
  TextEditingController qty = TextEditingController();
  TextEditingController price = TextEditingController();
  TextEditingController alert = TextEditingController();
  TextEditingController initialQty = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  load() async {
    stocks = await DBHelper.getStocks();
    setState((){});
  }

  save() async {
    if(_formKey.currentState!.validate()){
      await DBHelper.addStock({
        'name': name.text,
        'qty': double.parse(initialQty.text),
        'initial_qty': double.parse(initialQty.text),
        'unit': 'plate',
        'unit_price': double.parse(price.text),
        'low_alert': double.parse(alert.text)
      });
      Navigator.pop(context);
      clearForm();
      load();
      widget.onUpdate();
    }
  }

  clearForm() {
    name.clear(); qty.clear(); price.clear(); alert.clear(); initialQty.clear();
  }

  showAddDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add New Meal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
        TextFormField(controller: name, decoration: InputDecoration(labelText: 'Meal Name'), validator: (v)=>v!.isEmpty?'Required':null),
        TextFormField(controller: initialQty, decoration: InputDecoration(labelText: 'Initial Qty'), keyboardType: TextInputType.number, validator: (v)=>v!.isEmpty?'Required':null),
        TextFormField(controller: price, decoration: InputDecoration(labelText: 'Unit Price \$'), keyboardType: TextInputType.number, validator: (v)=>v!.isEmpty?'Required':null),
        TextFormField(controller: alert, decoration: InputDecoration(labelText: 'Low Stock Alert At'), keyboardType: TextInputType.number, validator: (v)=>v!.isEmpty?'Required':null),
      ]))),
      actions: [
        TextButton(onPressed: ()=>Navigator.of(context).pop(), child: Text('Cancel')), 
        ElevatedButton(onPressed: save, child: Text('Save'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))
      ],
    ));
  }

  deleteAll() {
    int countdown = 10;
    bool canDelete = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          Future.delayed(Duration(seconds: 1), () {
            if(countdown > 0 && mounted) setState(()=>countdown--);
            if(countdown == 0) setState(()=>canDelete = true);
          });
          return AlertDialog(
            title: Text('⚠️ DELETE ALL DATA'),
            content: Text('This will delete all stocks and reset total revenue to zero. This cannot be undone.\n\nEnable "Yes" in $countdown seconds'),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(
                onPressed: canDelete? () async {
                  await DBHelper.deleteAllData(); // You need to add this in DBHelper
                  Navigator.pop(context);
                  load();
                  widget.onUpdate();
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(canDelete? 'Yes, Delete All' : 'Wait...')
              )
            ],
          );
        });
      }
    );
  }

  confirmDeleteStock(Map s) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Delete ${s['name']}?'),
      content: Text('This will remove the stock and deduct its total sales from revenue.'),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            await DBHelper.deleteStock(s['id']); // Make this also deduct revenue in DBHelper
            Navigator.pop(context);
            load();
            widget.onUpdate();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Delete')
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('Manage Stocks', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'deleteAll',
            onPressed: deleteAll, 
            backgroundColor: Colors.red,
            child: Icon(Icons.delete_forever)
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: showAddDialog, 
            backgroundColor: Colors.orange,
            child: Icon(Icons.add)
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(12),
        children: stocks.map((s)=>_stockCard(s)).toList()
      ),
    );
  }

  Widget _stockCard(Map s) {
    double qty = (s['qty'] as num).toDouble();
    double initial = (s['initial_qty']?? s['qty'] as num).toDouble();
    double percent = initial > 0? qty / initial : 0;
    bool low = qty <= (s['low_alert'] as num).toDouble();

    return GestureDetector(
    onTap: ()=> Navigator.push(context, MaterialPageRoute(builder: (context)=>StockStatsPage(stock: s))),
      child: Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(s['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red), 
                    onPressed: ()=>confirmDeleteStock(s)
                  )
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price: \$${(s['unit_price'] as num).toDouble().toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: low? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text(
                      low? 'Low Stock' : 'In Stock', 
                      style: TextStyle(color: low? Colors.red : Colors.green, fontWeight: FontWeight.w600, fontSize: 12)
                    ),
                  )
                ],
              ),
              SizedBox(height: 12),
              Text('Current: ${qty.toStringAsFixed(1)} / Initial: ${initial.toStringAsFixed(1)}'),
              SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percent.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: low? Colors.red : Colors.orange,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.orange), 
                    onPressed: (){
                      TextEditingController c = TextEditingController();
                      showDialog(context: context, builder: (_)=>AlertDialog(
                        title: Text('Top Up ${s['name']}'),
                        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Qty to add')),
                        actions: [ElevatedButton(onPressed: () async {
                          await DBHelper.topUpStock(s['id'], double.parse(c.text));
                          Navigator.pop(context); load(); widget.onUpdate();
                        }, child: Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))]
                      ));
                    }
                  ),
                  Text('Top Up')
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// NEW: PRO STATS PAGE WITH 2 LINES
class StockStatsPage extends StatefulWidget {
  final Map stock;
  const StockStatsPage({super.key, required this.stock});
  @override
  State<StockStatsPage> createState() => _StockStatsPageState();
}

class _StockStatsPageState extends State<StockStatsPage> {
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  loadHistory() async {
    history = await DBHelper.getStockHistory(widget.stock['id']);
    setState(() {});
  }

  String generateFeedback() {
    if(history.isEmpty) return "No data yet. Start selling to see insights.";
    
    double sold = 0;
    double topup = 0;
    for(var h in history) {
      if(h['type'] == 'SALE') sold += (-(h['qty_change'] as num).toDouble());
      if(h['type'] == 'TOPUP') topup += (h['qty_change'] as num).toDouble();
    }
    
    double current = (widget.stock['qty'] as num).toDouble();
    double alert = (widget.stock['low_alert'] as num).toDouble();
    
    if(current <= alert) return "⚠️ URGENT: ${widget.stock['name']} is low on stock. Only ${current.toStringAsFixed(1)} left. Top up now!";
    if(sold > topup * 2) return "🔥 HOT ITEM: ${widget.stock['name']} sold ${sold.toStringAsFixed(0)}. Demand is high. Increase stock!";
    if(sold < 5 && topup > 20) return "📉 SLOW MOVER: ${widget.stock['name']} isn't selling. Consider a discount or combo.";
    return "✅ STEADY: ${widget.stock['name']} is selling well. Current stock: ${current.toStringAsFixed(1)}";
  }

  @override
  Widget build(BuildContext context) {
    List<FlSpot> stockSpots = [];
    List<FlSpot> saleSpots = [];

    for(int i=0; i<history.length; i++) {
      var h = history[i];
      stockSpots.add(FlSpot(i.toDouble(), (h['qty_after'] as num).toDouble()));
      if(h['type'] == 'SALE') {
        saleSpots.add(FlSpot(i.toDouble(), (h['qty_after'] as num).toDouble()));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stock['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock Level Over Time', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                _legend(Colors.orange, "Stock Level"),
                SizedBox(width: 16),
                _legend(Colors.red, "Sale Event")
              ],
            ),
            SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta)=>Text('Day ${v.toInt()+1}'))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    // LINE 1: Stock Level
                    LineChartBarData(
                      spots: stockSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.2)),
                    ),
                    // LINE 2: Sale Events as red dots
                    LineChartBarData(
                      spots: saleSpots,
                      color: Colors.red,
                      barWidth: 0,
                      dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index)=>
                        FlDotCirclePainter(radius: 5, color: Colors.red, strokeWidth: 2, strokeColor: Colors.white)
                      ),
                    ),
                  ]
                )
              ),
            ),
            SizedBox(height: 24),
            Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Feedback', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text(generateFeedback(), style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(children: [
      Container(width: 12, height: 12, color: color),
      SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12))
    ]);
  }
}
