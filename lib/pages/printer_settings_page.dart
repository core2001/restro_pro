import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart'; // CHANGED
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
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance; // CHANGED
  
  List<BluetoothDevice> pairedDevices = []; // CHANGED: now from blue_thermal_printer
  String? selectedMac;
  bool loading = false; // was scanning
  bool connecting = false;
  BluetoothDevice? connectedDevice; // track last selected

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
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  loadSaved() async {
    selectedMac = await printer.getSavedPrinter();
    setState(() {});
  }

  loadPaired() async {
    setState(() => loading = true);
    try {
      pairedDevices = await bluetooth.getBondedDevices(); // CHANGED
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading printers: $e'), backgroundColor: Colors.red)
      );
    }
    setState(() => loading = false);
  }

  // REMOVED scan() - blue_thermal_printer doesn't scan. Only shows paired

  // UPDATED: Now uses blue_thermal_printer connect
  select(BluetoothDevice device) async {
    setState(() => connecting = true);
    try {
      // 1. Try to connect to verify
      await bluetooth.connect(device.address!);
      await Future.delayed(const Duration(milliseconds: 800));
      await bluetooth.disconnect(); // disconnect after test

      // 2. If connection worked, save it
      await printer.savePrinter(device.address!);
      setState(() {
        selectedMac = device.address;
        connectedDevice = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer selected: ${device.name}'), backgroundColor: Colors.green)
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: loading? null : loadPaired, tooltip: 'Refresh'), // CHANGED: refresh instead of scan
          if(selectedMac != null)
            IconButton(icon: const Icon(Icons.print), onPressed: connecting? null : testPrint, tooltip: 'Test Print')
        ]
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '1. Pair printer in Android Bluetooth Settings first with PIN 0000\n2. Tap printer below to select\n3. Tap printer icon to test print',
                  style: GoogleFonts.poppins(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: loading? null : loadPaired, // CHANGED: Refresh paired
                  icon: Icon(loading? Icons.sync : Icons.refresh), 
                  label: Text(loading ? 'Loading...' : 'Refresh Paired Printers'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50))
                ),
              ],
            ),
          ),
          
          if(connecting) const LinearProgressIndicator(color: Colors.orange),

          Expanded(
            child: (pairedDevices.isEmpty && !loading)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print_disabled, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No paired printers found', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Go to Android Settings > Bluetooth > Pair CY-BX58D-6696', 
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
                    ]
                  ],
                )
          )
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice d) {
    bool isSelected = selectedMac == d.address; // CHANGED
    bool isConnected = isSelected && connectedDevice?.address == d.address;

    return ListTile(
      leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.orange),
      title: Text(d.name ?? "Unknown Printer"),
      subtitle: Text(d.address ?? ""),
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