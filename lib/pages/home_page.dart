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

  String restaurantName = "RestroPro Kitchen";
  String restaurantAddress = "123 Samora Machel Ave, Harare, ZW";
  String restaurantPhone = "+263 77 123 4567";

  @override
  void initState() {
    super.initState();
    loadPrefs();
  }

  loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      restaurantName = prefs.getString('rest_name') ?? restaurantName;
      restaurantAddress = prefs.getString('rest_address') ?? restaurantAddress;
      restaurantPhone = prefs.getString('rest_phone') ?? restaurantPhone;
    });
    loadData();
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600; // RESPONSIVE CHECK
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(restaurantName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 24 : 20)), 
        backgroundColor: Colors.orange,
        elevation: 0,
        centerTitle: false,
      ),
      drawer: _buildDrawer(isTablet),
      body: loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : RefreshIndicator(
            onRefresh: () => loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isTablet? 24 : 16),
              child: Center( // CENTER CONTENT ON TABLET
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200), // Max width for big tablets
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    
                    Text('Good ${ _getGreeting() } 👋', style: GoogleFonts.poppins(fontSize: isTablet? 18 : 16, color: Colors.grey.shade600)),
                    Text('Here\'s what\'s happening today', style: GoogleFonts.poppins(fontSize: isTablet? 24 : 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: isTablet? 28 : 20),
                    
                    // RESPONSIVE STATS: 2x2 on phone, 4x1 on tablet landscape
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isTablet && isLandscape? 4 : 2, 
                      crossAxisSpacing: isTablet? 20 : 12,
                      mainAxisSpacing: isTablet? 20 : 12,
                      childAspectRatio: isTablet? 1.4 : 1.6,
                      children: [
                        _statCard('Today Sales', '\$${todaySales.toStringAsFixed(2)}', Icons.today, Colors.green, isTablet),
                        _statCard('Total Revenue', '\$${revenue.toStringAsFixed(2)}', Icons.attach_money, Colors.orange, isTablet),
                        _statCard('Total Items', '$totalStocks', Icons.inventory_2, Colors.blue, isTablet),
                        _statCard('Low Stock', '${lowStocks.length}', Icons.warning, Colors.red, isTablet),
                      ],
                    ),
                    
                    if(lowStocks.isNotEmpty) ...[
                      SizedBox(height: isTablet? 28 : 20),
                      _alertCard(isTablet),
                    ],
                    
                    SizedBox(height: isTablet? 32 : 24),
                    Text('Quick Actions', style: GoogleFonts.poppins(fontSize: isTablet? 22 : 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: isTablet? 16 : 12),
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isTablet? 4 : 2, // 4 cols on tablet
                      crossAxisSpacing: isTablet? 20 : 16, 
                      mainAxisSpacing: isTablet? 20 : 16, 
                      childAspectRatio: isTablet? 1.2 : 1.1,
                      children: [
                        _menuCard(title: 'New Sale', subtitle: 'Take orders', icon: Icons.point_of_sale, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData))), isTablet: isTablet),
                        _menuCard(title: 'Stocks', subtitle: 'Manage inventory', icon: Icons.inventory_2_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData))), isTablet: isTablet),
                        _menuCard(title: 'Reports', subtitle: 'View analytics', icon: Icons.bar_chart_rounded, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage())), isTablet: isTablet),
                        _menuCard(title: 'Settings', subtitle: 'App settings', icon: Icons.settings, color: Colors.grey.shade700, onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
                          loadPrefs();
                        }, isTablet: isTablet),
                      ]
                    )
                  ]),
                ),
              ),
            ),
          ),
    );
  }

  Drawer _buildDrawer(bool isTablet) {
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
                Icon(Icons.restaurant_menu, size: isTablet? 50 : 40, color: Colors.white),
                const SizedBox(height: 10),
                Text(restaurantName, style: GoogleFonts.poppins(fontSize: isTablet? 24 : 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(restaurantAddress, style: GoogleFonts.poppins(fontSize: isTablet? 14 : 12, color: Colors.white70)),
                Text(restaurantPhone, style: GoogleFonts.poppins(fontSize: isTablet? 14 : 12, color: Colors.white70)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.dashboard, color: Colors.orange), title: Text('Dashboard', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.point_of_sale, color: Colors.orange), title: Text('New Sale', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => SellPage(onSale: loadData)));}),
          ListTile(leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange), title: Text('Stocks', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => StocksPage(onUpdate: loadData)));}),
          ListTile(leading: const Icon(Icons.bar_chart_rounded, color: Colors.orange), title: Text('Reports', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () {Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsPage()));}),
          ListTile(leading: const Icon(Icons.settings, color: Colors.orange), title: Text('Settings', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () async {Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage())); loadPrefs();}),
          const Divider(),
          ListTile(leading: const Icon(Icons.info_outline, color: Colors.grey), title: Text('About $restaurantName v1.0', style: TextStyle(fontSize: isTablet? 18 : 16)), onTap: () => showAboutDialog(context: context, applicationName: restaurantName, applicationVersion: '1.0.0')),
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

  Widget _statCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet? 20 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: isTablet? 32 : 24),
        SizedBox(height: isTablet? 12 : 8),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: isTablet? 14 : 12)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: isTablet? 20 : 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _alertCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet? 18 : 14),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: isTablet? 28 : 24),
        const SizedBox(width: 10),
        Expanded(child: Text('${lowStocks.length} Items Low on Stock. Tap Stocks to restock.', style: GoogleFonts.poppins(fontSize: isTablet? 16 : 14, fontWeight: FontWeight.w600, color: Colors.red.shade800))),
      ]),
    );
  }

  Widget _menuCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, required bool isTablet}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(isTablet? 20 : 16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
            Container(padding: EdgeInsets.all(isTablet? 18 : 14), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: isTablet? 36 : 28, color: color)),
            SizedBox(height: isTablet? 16 : 12),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: isTablet? 18 : 15, fontWeight: FontWeight.w600)),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: isTablet? 13 : 11, color: Colors.grey.shade600)),
          ])
        )
      )
    );
  }
}

// SETTINGS PAGE - ALSO RESPONSIVE
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18)), backgroundColor: Colors.orange),
      body: Center( // CENTER ON TABLET
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.all(isTablet? 24 : 16),
            children: [
              Text('Restaurant Details', style: GoogleFonts.poppins(fontSize: isTablet? 22 : 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'Restaurant Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: InputDecoration(labelText: 'Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: savePrefs,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: Size(double.infinity, isTablet? 60 : 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text('Save Details', style: GoogleFonts.poppins(fontSize: isTablet? 18 : 16, fontWeight: FontWeight.w600))
              )
            ],
          ),
        ),
      ),
    );
  }
}