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
  List<ScanResult> devices = [];
  String? selectedMac;
  bool scanning = false;
  bool connecting = false;
  BluetoothDevice? connectedDevice; // NEW: track live connection

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    await _requestPermissions();
    await loadSaved();
    await loadPaired();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
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
    setState(() => scanning = true);
    devices = [];
    
    if (!await FlutterBluePlus.isOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please turn on Bluetooth'), backgroundColor: Colors.red)
      );
      setState(() => scanning = false);
      return;
    }

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

  // UPDATED: Now actually connects to test it
  select(BluetoothDevice device) async {
    setState(() => connecting = true);
    try {
      // 1. Try to connect to verify it's a real printer
      await device.connect(timeout: const Duration(seconds: 8), autoConnect: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await device.discoverServices(); // this will fail if not ESC/POS
      await device.disconnect(); // disconnect after test

      // 2. If connection worked, save it
      await printer.savePrinter(device.remoteId.str);
      setState(() {
        selectedMac = device.remoteId.str;
        connectedDevice = device; // mark as last connected
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer connected: ${device.name}'), backgroundColor: Colors.green)
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => connecting = false);
    }
  }

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
          
          if(connecting) const LinearProgressIndicator(color: Colors.orange), // NEW

          Expanded(
            child: (pairedDevices.isEmpty && devices.isEmpty && !scanning)
              ? Center(
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
                    if(pairedDevices.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Paired Printers', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                      ...pairedDevices.map((d) => _buildDeviceTile(d)),
                      const Divider()
                    ],

                    if(devices.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Nearby Printers', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                      ...devices.map((d) => _buildDeviceTile(d.device))
                    ]
                  ],
                )
          )
        ],
      ),
    );
  }

  // NEW HELPER: Builds tile with "Connected" status
  Widget _buildDeviceTile(BluetoothDevice d) {
    bool isSelected = selectedMac == d.remoteId.str;
    bool isConnected = isSelected && connectedDevice?.remoteId == d.remoteId; // we just connected to it

    return ListTile(
      leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.orange),
      title: Text(d.name),
      subtitle: Text(d.remoteId.str),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if(isSelected) 
            Chip(
              label: Text(isConnected ? 'Connected' : 'Selected', style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: isConnected ? Colors.green : Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          const SizedBox(width: 8),
          if(isSelected) const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
      onTap: connecting ? null : () => select(d),
    );
  }
}