import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
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

    BluetoothDevice device = BluetoothDevice.fromId(mac);
    await device.connect(timeout: Duration(seconds: 15));

    // Generate ESC/POS bytes
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('RESTROPRO', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Harare, ZW', styles: PosStyles(align: PosAlign.center));
    bytes += generator.text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), styles: PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    
    for(var item in cart) {
      double qty = (item['qty'] as num).toDouble();
      double price = (item['price'] as num).toDouble();
      bytes += generator.text('${item['name']}', styles: PosStyles());
      bytes += generator.text('${qty}x \$${price.toStringAsFixed(2)}  = \$${(qty*price).toStringAsFixed(2)}', styles: PosStyles());
    }
    
    bytes += generator.hr();
    bytes += generator.text('TOTAL: \$${total.toStringAsFixed(2)}', styles: PosStyles(bold: true, height: PosTextSize.size1));
    bytes += generator.cut();

    // Send to printer
    var mtu = await device.mtu.first;
    List<List<int>> chunks = [];
    for (var i = 0; i < bytes.length; i += mtu) {
      chunks.add(bytes.sublist(i, i + mtu > bytes.length ? bytes.length : i + mtu));
    }
    for (var chunk in chunks) {
      await device.writeCharacteristic(chunk, withoutResponse: true);
    }

    await Future.delayed(Duration(seconds: 1));
    await device.disconnect();
  }
}