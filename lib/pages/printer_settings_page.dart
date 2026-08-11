import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/print_service_mobile.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final printer = PrintService();
  List<ScanResult> devices = [];
  String? selectedMac;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  loadSaved() async {
    selectedMac = await printer.getSavedPrinter();
    setState(() {});
  }

  scan() async {
    setState(() => scanning = true);
    devices = await printer.scanPrinters();
    setState(() => scanning = false);
  }

  select(ScanResult r) async {
    await printer.savePrinter(r.device.remoteId.str);
    setState(() => selectedMac = r.device.remoteId.str);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer saved: ${r.device.name}'), backgroundColor: Colors.green)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Printer Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: scan, 
              icon: Icon(Icons.search), 
              label: Text(scanning ? 'Scanning...' : 'Scan for Printers'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: Size(double.infinity, 50))
            ),
          ),
          Expanded(
            child: ListView(
              children: devices.map((d) => ListTile(
                leading: Icon(Icons.print, color: selectedMac == d.device.remoteId.str ? Colors.green : Colors.grey),
                title: Text(d.device.name),
                subtitle: Text(d.device.remoteId.str),
                trailing: selectedMac == d.device.remoteId.str ? Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () => select(d),
              )).toList(),
            )
          )
        ],
      ),
    );
  }
}