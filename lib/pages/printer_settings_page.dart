import 'dart:async'; // <-- ADD THIS
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/print_service_mobile.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final printer = PrintService();
  List<BluetoothDevice> pairedDevices = [];
  List<ScanResult> scanResults = [];
  String? selectedMac;
  bool scanning = false;
  bool connecting = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  init() async {
    await _requestPermissions();
    await loadSaved();
    await loadPaired();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  loadSaved() async {
    selectedMac = await printer.getSavedPrinter();
    setState(() {});
  }

  loadPaired() async {
    if (await FlutterBluePlus.isOn) {
      pairedDevices = await FlutterBluePlus.bondedDevices;
      setState(() {});
    }
  }

  scan() async {
    setState(() {scanning = true; scanResults = [];});
    
    if (!await FlutterBluePlus.isOn) {
      _snack('Please turn on Bluetooth', Colors.red);
      setState(() => scanning = false);
      return;
    }

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results.where((r) => r.device.name.isNotEmpty).toList();
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();

    setState(() => scanning = false);
    if(scanResults.isEmpty && pairedDevices.isEmpty) {
      _snack('No printers found. Turn printer ON', Colors.orange);
    }
  }

  select(BluetoothDevice device) async {
    setState(() => connecting = true);
    try {
      await printer.savePrinter(device.remoteId.str);
      setState(() => selectedMac = device.remoteId.str);
      _snack('Printer saved: ${device.name}', Colors.green);
    } catch(e) {
      _snack('Failed to save: $e', Colors.red);
    } finally {
      setState(() => connecting = false);
    }
  }

  testPrint() async {
    if(selectedMac == null) return _snack('Please select a printer first', Colors.red);
    setState(() => connecting = true);
    try {
      await printer.printReceipt([
        {'name': 'Test Sadza', 'variant': 'With Chicken', 'qty': 2.0, 'price': 5.00},
        {'name': 'Coke', 'variant': '', 'qty': 1.0, 'price': 1.50}
      ], 11.50);
      _snack('Test print sent!', Colors.green);
    } catch(e) {
      _snack('Print failed: $e', Colors.red);
    } finally {
      setState(() => connecting = false);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: scanning? null : loadPaired),
          if(selectedMac != null)
            IconButton(icon: const Icon(Icons.print), onPressed: connecting? null : testPrint, tooltip: 'Test Print')
        ]
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: scanning? null : scan, 
              icon: Icon(scanning? Icons.sync : Icons.search), 
              label: Text(scanning ? 'Scanning...' : 'Scan for Printers'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50))
            ),
          ),
          if(connecting) const LinearProgressIndicator(color: Colors.orange),
          Expanded(
            child: ListView(
              children: [
                if(pairedDevices.isNotEmpty) _header('Paired Printers'),
                ...pairedDevices.map((d) => _buildDeviceTile(d)),
                if(scanResults.isNotEmpty) _header('Nearby Printers'),
                ...scanResults.map((r) => _buildScanTile(r.device)),
              ],
            )
          )
        ],
      ),
    );
  }

  Widget _header(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)));
  
  Widget _buildDeviceTile(BluetoothDevice d) {
    bool isSelected = selectedMac == d.remoteId.str;
    return ListTile(
      leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.orange),
      title: Text(d.name.isEmpty ? "Unknown Device" : d.name),
      subtitle: Text(d.remoteId.str),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
      tileColor: isSelected ? Colors.green.withOpacity(0.1) : null,
      onTap: connecting ? null : () => select(d),
    );
  }

  Widget _buildScanTile(BluetoothDevice d) {
    bool isSelected = selectedMac == d.remoteId.str;
    return ListTile(
      leading: Icon(Icons.bluetooth_searching, color: isSelected ? Colors.green : Colors.blue),
      title: Text(d.name),
      subtitle: Text(d.remoteId.str),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
      onTap: connecting ? null : () => select(d),
    );
  }
}