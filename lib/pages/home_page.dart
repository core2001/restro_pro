import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  double todaySales = 0;
  int totalStocks = 0;
  List lowStocks = [];
  bool loading = true;

  // Now loaded from SharedPreferences
  String restaurantName = "RestroPro Kitchen";
  String restaurantAddress = "123 Samora Machel Ave, Harare, ZW";
  String restaurantPhone = "+263 77 123 4567";

  @override
  void initState() {
    super.initState();
    loadPrefs(); // load name first
  }

  loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      restaurantName = prefs.getString('rest_name') ?? restaurantName;
      restaurantAddress = prefs.getString('rest_address') ?? restaurantAddress;
      restaurantPhone = prefs.getString('rest_phone') ?? restaurantPhone;
    });
    loadData(); // then load sales/stocks
  }

  loadData() async {
    setState(() => loading = true);
    revenue = await DBHelper.getTotalRevenue();
    var stocks = await DBHelper.getStocks();
    totalStocks = stocks.length;
    lowStocks = stocks.where((s)=> (s['qty'] as num).toDouble() <= (s['low_alert'] as num).toDouble()).toList();
    
    final db = await DBHelper.database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sales = await db.rawQuery(
      "SELECT SUM(total) as total FROM sales WHERE date LIKE ?", ['%$today%']
    );
    todaySales = (sales.first['total'] as num?)?.toDouble() ?? 0;
    
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(restaurantName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)), 
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: false,
      ),
      drawer: _buildDrawer(),
      body: loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : RefreshIndicator(
            onRefresh: () => loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                
                Text('Good ${ _getGreeting() } 👋', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600)),
                Text('Here\'s what\'s happening today', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                Row(children: [
                  Expanded(child: _statCard('Today Sales', '\$${todaySales.toStringAsFixed(2)}', Icons.today, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Total Revenue', '\$${revenue.toStringAsFixed(2)}', Icons.attach_money, Colors.orange)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _statCard('Total Items', '$totalStocks', Icons.inventory_2, Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Low Stock', '${lowStocks.length}', Icons.warning, Colors.red)),
                ]),
                
                if(lowStocks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _alertCard(),
                ],
                
                const SizedBox(height: 24),
                Text('Quick Actions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, 
                  crossAxisSpacing: 16, 
                  mainAxisSpacing: 16, 
                  childAspectRatio: 1.1,
                  children: [
                    _menuCard(title: 'New Sale', subtitle: 'Take orders', icon: Icons.point_of_sale, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData)))),
                    _menuCard(title: 'Stocks', subtitle: 'Manage inventory', icon: Icons.inventory_2_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData)))),
                    _menuCard(title: 'Reports', subtitle: 'View analytics', icon: Icons.bar_chart_rounded, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage()))),
                    _menuCard(title: 'Settings', subtitle: 'App settings', icon: Icons.settings, color: Colors.grey.shade700, onTap: () async {
                      // Open settings and reload when we come back
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
                      loadPrefs(); // refresh name/address
                    }),
                  ]
                )
              ]),
            ),
          ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange])),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.restaurant_menu, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                Text(restaurantName, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(restaurantAddress, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                Text(restaurantPhone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          ListTile(leading: Icon(Icons.dashboard, color: Colors.orange), title: Text('Dashboard'), onTap: () => Navigator.pop(context)),
          ListTile(leading: Icon(Icons.point_of_sale, color: Colors.orange), title: Text('New Sale'), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData)));}),
          ListTile(leading: Icon(Icons.inventory_2_outlined, color: Colors.orange), title: Text('Stocks'), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData)));}),
          ListTile(leading: Icon(Icons.bar_chart_rounded, color: Colors.orange), title: Text('Reports'), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage()));}),
          ListTile(leading: Icon(Icons.settings, color: Colors.orange), title: Text('Settings'), onTap: () async {Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())); loadPrefs();}),
          const Divider(),
          ListTile(leading: Icon(Icons.info_outline, color: Colors.grey), title: Text('About RestroPro v1.0'), onTap: () => showAboutDialog(context: context, applicationName: restaurantName, applicationVersion: '1.0.0')),
        ],
      ),
    );
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _alertCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
        const SizedBox(width: 10),
        Expanded(child: Text('${lowStocks.length} Items Low on Stock. Tap Stocks to restock.', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.red.shade800))),
      ]),
    );
  }

  Widget _menuCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
          ])
        )
      )
    );
  }
}

// NEW PAGE: Settings to edit restaurant details
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    nameController.text = prefs.getString('rest_name') ?? "RestroPro Kitchen";
    addressController.text = prefs.getString('rest_address') ?? "123 Samora Machel Ave, Harare, ZW";
    phoneController.text = prefs.getString('rest_phone') ?? "+263 77 123 4567";
  }

  savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rest_name', nameController.text);
    await prefs.setString('rest_address', addressController.text);
    await prefs.setString('rest_phone', phoneController.text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Restaurant Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(controller: nameController, decoration: InputDecoration(labelText: 'Restaurant Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: addressController, decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: savePrefs,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text('Save Details', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))
          )
        ],
      ),
    );
  }
}