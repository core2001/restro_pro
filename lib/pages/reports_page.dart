import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import '../database/db_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> stocks = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> topups = [];
  double revenue = 0;
  bool loading = true;
  String restaurantName = "RestroPro Kitchen";

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    
    final prefs = await SharedPreferences.getInstance();
    restaurantName = prefs.getString('rest_name') ?? restaurantName;

    stocks = await DBHelper.getStocks();
    sales = await DBHelper.getSales();
    topups = await DBHelper.getTopUps();
    revenue = await DBHelper.getTotalRevenue();
    setState(() => loading = false);
  }

  // NEW: RESET SALES WITH COUNTDOWN
  void resetSalesDialog() {
    int countdown = 10;
    bool canReset = false;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setState) {
            Future.delayed(const Duration(seconds: 1), () {
              if (countdown > 0 && mounted) setState(() => countdown--);
              if (countdown == 0) setState(() => canReset = true);
            });
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('⚠️ DELETE ALL RECEIPTS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18, color: Colors.red)),
              content: Text(
                'This will permanently delete all ${sales.length} sales records and reset Total Revenue to \$0.00. This cannot be undone.\n\nEnable "Delete" in $countdown seconds',
                style: TextStyle(fontSize: isTablet? 16 : 14)
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text('Cancel', style: TextStyle(fontSize: isTablet? 16 : 14))
                ),
                ElevatedButton(
                    onPressed: canReset
                      ? () async {
                            await DBHelper.clearAllSales(); // YOU NEED THIS IN DBHELPER
                            if (mounted) Navigator.pop(context);
                            await load();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All receipts deleted'), backgroundColor: Colors.red)
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(canReset? 'Delete' : 'Wait $countdown', style: TextStyle(fontSize: isTablet? 16 : 14)))
              ],
            );
          });
        });
  }

  Future<void> _showReceiptPopup(Map<String, dynamic> sale) async {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final db = await DBHelper.database;
    final items = await db.rawQuery('''
      SELECT si.qty, si.price, s.name 
      FROM sale_items si 
      JOIN stocks s ON si.stock_id = s.id 
      WHERE si.sale_id = ?
    ''', [sale['id']]);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Timer(const Duration(seconds: 6), () {
          if(Navigator.canPop(context)) Navigator.pop(context);
        });

        double total = (sale['total'] as num).toDouble();
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(Icons.receipt_long, size: isTablet? 50 : 40, color: Colors.orange),
              const SizedBox(height: 8),
              Text('Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18)),
              Text(
                sale['date'].toString().substring(0,16), 
                style: TextStyle(fontSize: isTablet? 14 : 12, color: Colors.grey)
              )
            ],
          ),
          content: SizedBox(
            width: size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                ...items.map((item) {
                  double qty = (item['qty'] as num).toDouble();
                  double price = (item['price'] as num).toDouble();
                  String name = item['name'].toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(fontSize: isTablet? 16 : 14, fontWeight: FontWeight.w600)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Qty: $qty x \$${price.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: isTablet? 14 : 12, color: Colors.grey.shade700)),
                            Text('\$${(qty * price).toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: isTablet? 15 : 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 18 : 16)),
                    Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 18 : 16)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Auto closing in 6s...', style: TextStyle(fontSize: isTablet? 13 : 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  generatePDF() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(theme: pw.ThemeData.withFont(base: font, bold: fontBold)),
      build: (context) => [
        pw.Header(level: 0, child: pw.Text('$restaurantName Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.Text('Harare, ZW • ${DateTime.now().toString().substring(0,16)}'),
        pw.Divider(),
        pw.Text('Total Revenue: \$${revenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        
        pw.Text('Stock Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Meal', 'Qty Left', 'Price', 'Value', 'Status'],
          data: stocks.map((s){
            double qty = (s['qty'] as num).toDouble();
            double price = (s['unit_price'] as num).toDouble();
            double lowAlert = (s['low_alert'] as num).toDouble();
            String status = qty <= lowAlert ? 'LOW' : 'OK';
            return [s['name'], qty.toStringAsFixed(1), '\$${price.toStringAsFixed(2)}', '\$${(qty * price).toStringAsFixed(2)}', status];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 20),
        
        pw.Text('Recent Sales', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Date', 'Total'],
          data: sales.map((s)=>[s['date'].toString().substring(0,16), '\$${(s['total'] as num).toDouble().toStringAsFixed(2)}']).toList(),
        )
      ]
    ));

    final dir = await getApplicationDocumentsDirectory();
    final safeName = restaurantName.replaceAll(' ', '_');
    final file = File('${dir.path}/${safeName}_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path)], text: '$restaurantName Report');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18)), 
        backgroundColor: Colors.orange, 
        elevation: 0,
        actions:[ 
          IconButton(
            icon: Icon(Icons.delete_forever, size: isTablet? 28 : 24), // RESET ICON
            onPressed: sales.isEmpty ? null : resetSalesDialog, 
            tooltip: 'Reset All Receipts',
            color: Colors.white
          ),
          IconButton(icon: Icon(Icons.picture_as_pdf, size: isTablet? 28 : 24), onPressed: generatePDF, tooltip: 'Export PDF') 
        ]
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : RefreshIndicator(
          onRefresh: load,
          child: Center( // CENTER ON TABLET
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: EdgeInsets.all(isTablet? 24 : 16),
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet? 28 : 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Revenue', style: GoogleFonts.poppins(color: Colors.white70, fontSize: isTablet? 16 : 14)),
                        Text('\$${revenue.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: isTablet? 36 : 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(height: isTablet? 32 : 24),

                  Text('Stock Details', style: GoogleFonts.poppins(fontSize: isTablet? 22 : 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: isTablet? 16 : 12),
                  
                  // RESPONSIVE GRID FOR STOCK CARDS
                  isTablet 
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isLandscape? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: stocks.length,
                      itemBuilder: (context, index) => _stockCard(stocks[index], isTablet),
                    )
                  : Column(children: stocks.map((s) => _stockCard(s, isTablet)).toList()),

                  SizedBox(height: isTablet? 32 : 24),
                  Text('Sales History', style: GoogleFonts.poppins(fontSize: isTablet? 22 : 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: isTablet? 16 : 12),
                  
                  ...sales.map((s) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => _showReceiptPopup(s),
                      leading: Icon(Icons.receipt_long, color: Colors.green, size: isTablet? 32 : 24),
                      title: Text(s['date'].toString().substring(0,16), style: TextStyle(fontSize: isTablet? 16 : 14)),
                      trailing: Text('\$${(s['total'] as num).toDouble().toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet? 18 : 16)),
                    ),
                  )),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _stockCard(Map<String, dynamic> s, bool isTablet) {
    double qty = (s['qty'] as num).toDouble();
    double price = (s['unit_price'] as num).toDouble();
    double lowAlert = (s['low_alert'] as num).toDouble();
    bool isLow = qty <= lowAlert;

    return Card(
      margin: EdgeInsets.only(bottom: isTablet? 0 : 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isTablet? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(s['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: isTablet? 18 : 16, fontWeight: FontWeight.w600))),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isTablet? 12 : 10, vertical: isTablet? 6 : 4),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(isLow ? 'LOW STOCK' : 'IN STOCK',
                    style: TextStyle(color: isLow ? Colors.red.shade800 : Colors.green.shade800, fontSize: isTablet? 13 : 11, fontWeight: FontWeight.bold)
                  ),
                )
              ],
            ),
            SizedBox(height: isTablet? 14 : 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _detailItem('Quantity', '$qty', isTablet),
                _detailItem('Unit Price', '\$${price.toStringAsFixed(2)}', isTablet),
                _detailItem('Value', '\$${(qty * price).toStringAsFixed(2)}', isTablet),
              ],
            ),
            if (isLow) ...[
              SizedBox(height: isTablet? 10 : 8),
              Text('Alert at: $lowAlert', style: TextStyle(color: Colors.red.shade700, fontSize: isTablet? 14 : 12))
            ]
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: isTablet? 14 : 12)),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isTablet? 16 : 14)),
      ],
    );
  }
}