import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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

  @override
  void initState() {
    super.initState();
    load();
  }

  load() async {
    stocks = await DBHelper.getStocks();
    sales = await DBHelper.getSales();
    topups = await DBHelper.getTopUps();
    revenue = await DBHelper.getTotalRevenue();
    setState((){});
  }

  generatePDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Header(text: 'RestroPro Stock Report'),
        pw.Text('Total Revenue: \$${revenue.toStringAsFixed(2)}'),
        pw.SizedBox(height: 20),
        pw.Text('Current Stock:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Meal', 'Qty', 'Price'],
          data: stocks.map((s)=>[s['name'], s['qty'].toString(), '\$${s['unit_price']}']).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Recent Sales:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Table.fromTextArray(
          headers: ['Date', 'Total'],
          data: sales.map((s)=>[s['date'].toString().substring(0,10), '\$${s['total']}']).toList(),
        )
      ]
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/report.pdf');
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path)], text: 'RestroPro Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reports'), backgroundColor: Colors.orange, actions:[
        IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: generatePDF)
      ]),
      body: ListView(
        padding: EdgeInsets.all(12),
        children: [
          Card(child: ListTile(title: Text('Total Revenue'), trailing: Text('\$${revenue.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Text('Stock Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         ...stocks.map((s)=>ListTile(title: Text(s['name']), trailing: Text('Qty: ${s['qty']}'))),
          Text('Sales History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         ...sales.map((s)=>ListTile(title: Text(s['date'].toString().substring(0,16)), trailing: Text('\$${s['total']}'))),
        ],
      ),
    );
  }
}