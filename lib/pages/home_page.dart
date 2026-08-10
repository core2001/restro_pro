import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stocks_page.dart';
import 'sell_page.dart';
import 'reports_page.dart';
import '../database/db_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double revenue = 0;
  List lowStocks = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    revenue = await DBHelper.getTotalRevenue();
    var stocks = await DBHelper.getStocks();
    lowStocks = stocks.where((s)=> (s['qty'] as double) <= (s['low_alert'] as double)).toList();
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RestroPro', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children:[
          Card(color: Colors.orange.shade100, child: ListTile(
            title: Text('Total Revenue'),
            trailing: Text('\$${revenue.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
          )),
          if(lowStocks.isNotEmpty) Card(color: Colors.red.shade100, child: ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text('${lowStocks.length} Items Low on Stock')
          )),
          SizedBox(height: 20),
          Expanded(child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, children: [
            _menuCard('Sell', Icons.point_of_sale, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData)))),
            _menuCard('Stocks', Icons.inventory, () => Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData)))),
            _menuCard('Reports', Icons.bar_chart, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage()))),
          ]))
        ]),
      ),
    );
  }

  _menuCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
        Icon(icon, size: 40, color: Colors.orange),
        SizedBox(height: 10),
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))
      ]))
    );
  }
}