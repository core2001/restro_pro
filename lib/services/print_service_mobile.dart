import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PrintService {
  static const _printerKey = 'selected_printer_mac';

  Future<void> savePrinter(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerKey, macAddress);
  }

  Future<String?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerKey);
  }

  Future<List<ScanResult>> scanPrinters() async {
    List<ScanResult> results = [];
    FlutterBluePlus.scanResults.listen((r) => results = r);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();
    return results.where((r) => r.device.name.isNotEmpty).toList();
  }

  Future<void> printReceipt(List<Map<String, dynamic>> cart, double total) async {
    if(await FlutterBluePlus.isOn == false) {
      throw Exception("Please turn on Bluetooth");
    }

    String? mac = await getSavedPrinter();
    if(mac == null) throw Exception("No printer selected. Go to Settings > Printer");

    // LOAD RESTAURANT DETAILS FROM SETTINGS
    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('rest_name') ?? "RestroPro Kitchen";
    String address = prefs.getString('rest_address') ?? "Harare, ZW";
    String phone = prefs.getString('rest_phone') ?? "";

    BluetoothDevice device = BluetoothDevice.fromId(mac); // Updated for flutter_blue_plus v1.32+
    await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
    List<BluetoothService> services = await device.discoverServices();

    // Find writable characteristic
    BluetoothCharacteristic? characteristic;
    for (var service in services) {
      for (var c in service.characteristics) {
        if(c.properties.write || c.properties.writeWithoutResponse) {
          characteristic = c;
          break;
        }
      }
      if(characteristic != null) break;
    }
    if(characteristic == null) {
      await device.disconnect();
      throw Exception("Printer not supported - no write characteristic found");
    }

    // Generate ESC/POS bytes - CY-BX58D is 58mm
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile); // CHANGED: mm58 for CY-BX58D
    List<int> bytes = [];

    // CY-BX58D FIX 1: INIT PRINTER - clears buffer
    bytes += [0x1B, 0x40]; // ESC @

    // HEADER WITH RESTAURANT DETAILS
    bytes += generator.text(name.toUpperCase(), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text(address, styles: const PosStyles(align: PosAlign.center));
    if(phone.isNotEmpty) {
      bytes += generator.text(phone, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    
    // ITEMS - WITH VARIANT
    for(var item in cart) {
      double qty = (item['qty'] as num).toDouble();
      double price = (item['price'] as num).toDouble();
      String variant = item['variant'] ?? '';
      
      bytes += generator.text('${item['name']}', styles: const PosStyles(bold: true)); // NAME BOLD
      if(variant.isNotEmpty) {
        bytes += generator.text('  $variant'); // INDENTED VARIANT
      }
      bytes += generator.row([
        PosColumn(text: '  ${qty}x \$${price.toStringAsFixed(2)}', width: 7), // INDENTED
        PosColumn(text: '\$${(qty*price).toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    
    bytes += generator.hr();
    bytes += generator.text('TOTAL: \$${total.toStringAsFixed(2)}', styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size1));
    bytes += generator.feed(3); // CY-BX58D FIX 2: Feed paper
    bytes += generator.text('Thank you for your business!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Powered by CoreVanta', styles: const PosStyles(align: PosAlign.center, width: PosTextSize.size1));
    bytes += generator.feed(2);
    bytes += generator.cut(); // CY-BX58D FIX 3: Cut command

    // CY-BX58D FIX 4: Send in chunks of 16 bytes with 50ms delay
    int chunkSize = 16; // Was 20, CY-BX58D buffer is small
    for (var i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      await characteristic.write(bytes.sublist(i, end), withoutResponse: false); // withoutResponse: false is more stable
      await Future.delayed(const Duration(milliseconds: 50)); // CY-BX58D needs this
    }

    await Future.delayed(const Duration(milliseconds: 800)); // Let printer finish
    await device.disconnect();
  }
}