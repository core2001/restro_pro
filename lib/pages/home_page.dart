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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    setState(() => loading = true);
    revenue = await DBHelper.getTotalRevenue();
    var stocks = await DBHelper.getStocks();
    lowStocks = stocks.where((s)=> (s['qty'] as double) <= (s['low_alert'] as double)).toList();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('RestroPro', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 22)), 
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: false,
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : RefreshIndicator(
            onRefresh: () => loadData(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children:[
                // Revenue Card
                _revenueCard(),
                
                if(lowStocks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _alertCard(),
                ],
                
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quick Actions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600))
                ),
                const SizedBox(height: 12),
                
                // Menu Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2, 
                    crossAxisSpacing: 16, 
                    mainAxisSpacing: 16, 
                    children: [
                      _menuCard(
                        title: 'Sell',
                        icon: Icons.point_of_sale,
                        color: Colors.orange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData)))
                      ),
                      _menuCard(
                        title: 'Stocks',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData)))
                      ),
                      _menuCard(
                        title: 'Reports',
                        icon: Icons.bar_chart_rounded,
                        color: Colors.green,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage())),
                      ),
                    ]
                  )
                )
              ]),
            ),
          ),
    );
  }

  Widget _revenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0,6))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Revenue', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Text('\$${revenue.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))
            ],
          ),
          const Icon(Icons.attach_money, color: Colors.white, size: 40)
        ],
      ),
    );
  }

  Widget _alertCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200)
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text('${lowStocks.length} Items Low on Stock', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.red.shade800))),
        ],
      ),
    );
  }

  Widget _menuCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children:[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 14),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))
            ]
          ),
        )
      )
    );
  }
}