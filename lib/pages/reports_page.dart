import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../database/db_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List stocks = [];
  List sales = [];
  List topups = [];
  double revenue = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  load() async {
    setState(() => loading = true);
    stocks = await DBHelper.getStocks();
    sales = await DBHelper.getSales();
    topups = await DBHelper.getTopUps();
    revenue = await DBHelper.getTotalRevenue();
    setState(() => loading = false);
  }

  generatePDF() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(theme: pw.ThemeData.withFont(base: font, bold: fontBold)),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text('RestroPro Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))
        ),
        pw.Text('Harare, ZW • ${DateTime.now().toString().substring(0,16)}'),
        pw.Divider(),
        pw.Text('Total Revenue: \$${revenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        
        pw.Text('Stock Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Meal', 'Qty', 'Price', 'Value', 'Status'],
          data: stocks.map((s){
            double qty = (s['qty'] as num).toDouble();
            double price = (s['unit_price'] as num).toDouble();
            double lowAlert = (s['low_alert'] as num).toDouble();
            String status = qty <= lowAlert ? 'LOW' : 'OK';
            return [
              s['name'], 
              qty.toString(), 
              '\$${price.toStringAsFixed(2)}',
              '\$${(qty * price).toStringAsFixed(2)}',
              status
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 20),
        
        pw.Text('Recent Sales', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Date', 'Total'],
          data: sales.map((s)=>[s['date'].toString().substring(0,16), '\$${(s['total'] as num).toStringAsFixed(2)}']).toList(),
        )
      ]
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/RestroPro_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path)], text: 'RestroPro Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange, 
        elevation: 0,
        actions:[
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: generatePDF, tooltip: 'Export PDF')
        ]
      ),
      body: loading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Revenue Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Revenue', style: GoogleFonts.poppins(color: Colors.white70)),
                    Text('\$${revenue.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Stock Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // Group each stock with its details
              ...stocks.map((s) => _stockCard(s)),

              const SizedBox(height: 24),
              Text('Sales History', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...sales.map((s) => Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: Text(s['date'].toString().substring(0,16)),
                  trailing: Text('\$${(s['total'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
              const SizedBox(height: 40),
            ],
          ),
        ),
    );
  }

  Widget _stockCard(Map s) {
    double qty = (s['qty'] as num).toDouble();
    double price = (s['unit_price'] as num).toDouble();
    double lowAlert = (s['low_alert'] as num).toDouble();
    bool isLow = qty <= lowAlert;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(s['name'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(
                    isLow ? 'LOW STOCK' : 'IN STOCK',
                    style: TextStyle(color: isLow ? Colors.red.shade800 : Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _detailItem('Quantity', '${qty.toString()}'),
                _detailItem('Unit Price', '\$${price.toStringAsFixed(2)}'),
                _detailItem('Value', '\$${(qty * price).toStringAsFixed(2)}'),
              ],
            ),
            if (isLow) ...[
              const SizedBox(height: 8),
              Text('Alert at: ${lowAlert.toString()}', style: TextStyle(color: Colors.red.shade700, fontSize: 12))
            ]
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ],
    );
  }
}