import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart'; // ADDED
import '../services/print_service_mobile.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final printer = PrintService();
  List<BluetoothDevice> pairedDevices = []; // ADDED
  List<ScanResult> devices = [];
  String? selectedMac;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    await _requestPermissions(); // ADDED
    await loadSaved();
    await loadPaired(); // ADDED
  }

  // ADDED: Request permissions for Android 12+
  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  loadSaved() async {
    selectedMac = await printer.getSavedPrinter();
    setState(() {});
  }

  // ADDED: Load already paired bluetooth devices
  loadPaired() async {
    if (await FlutterBluePlus.isOn) {
      pairedDevices = await FlutterBluePlus.bondedDevices;
      setState(() {});
    }
  }

  scan() async {
    setState(() => scanning = true);
    devices = [];
    
    if (!await FlutterBluePlus.isOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please turn on Bluetooth'), backgroundColor: Colors.red)
      );
      setState(() => scanning = false);
      return;
    }

    // Listen to scan results
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        devices = results.where((r) => r.device.name.isNotEmpty).toList();
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    setState(() => scanning = false);

    if(devices.isEmpty && pairedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No printers found. Make sure printer is ON and in pairing mode'), backgroundColor: Colors.orange)
      );
    }
  }

  select(BluetoothDevice device) async { // CHANGED: now accepts BluetoothDevice
    await printer.savePrinter(device.remoteId.str);
    setState(() => selectedMac = device.remoteId.str);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer saved: ${device.name}'), backgroundColor: Colors.green)
    );
  }

  // ADDED: Test print function
  testPrint() async {
    if(selectedMac == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a printer first'), backgroundColor: Colors.red)
      );
      return;
    }
    try {
      await printer.printReceipt([
        {'name': 'Test Item', 'variant': 'Sadza', 'qty': 1.0, 'price': 1.00}
      ], 1.00);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test print sent!'), backgroundColor: Colors.green)
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange,
        actions: [
          if(selectedMac != null)
            IconButton(icon: const Icon(Icons.print), onPressed: testPrint, tooltip: 'Test Print') // ADDED
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
          
          Expanded(
            child: (pairedDevices.isEmpty && devices.isEmpty && !scanning)
              ? Center( // FIXED: Show message instead of white page
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print_disabled, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No printers found', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Tap "Scan for Printers" or pair in Bluetooth settings', 
                        style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center)
                    ],
                  ),
                )
              : ListView(
                  children: [
                    // SHOW PAIRED DEVICES FIRST
                    if(pairedDevices.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Paired Printers', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                      ...pairedDevices.map((d) => ListTile(
                        leading: Icon(Icons.print, color: selectedMac == d.remoteId.str ? Colors.green : Colors.orange),
                        title: Text(d.name),
                        subtitle: Text(d.remoteId.str),
                        trailing: selectedMac == d.remoteId.str ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () => select(d),
                      )),
                      const Divider()
                    ],

                    // SHOW SCANNED DEVICES
                    if(devices.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Nearby Printers', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                      ...devices.map((d) => ListTile(
                        leading: Icon(Icons.print_outlined, color: selectedMac == d.device.remoteId.str ? Colors.green : Colors.grey),
                        title: Text(d.device.name),
                        subtitle: Text(d.device.remoteId.str),
                        trailing: selectedMac == d.device.remoteId.str ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        onTap: () => select(d.device),
                      ))
                    ]
                  ],
                )
          )
        ],
      ),
    );
  }
}