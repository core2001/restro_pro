import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PrintService {
  static const _printerKey = 'selected_printer_mac';
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<void> savePrinter(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerKey, macAddress);
  }

  Future<String?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerKey);
  }

  Future<List<BluetoothDevice>> scanPrinters() async {
    // blue_thermal_printer only lists bonded/paired devices
    return await bluetooth.getBondedDevices();
  }

  Future<void> printReceipt(List<Map<String, dynamic>> cart, double total) async {
    String? mac = await getSavedPrinter();
    if(mac == null) throw Exception("No printer selected. Go to Settings > Printer");

    // LOAD RESTAURANT DETAILS FROM SETTINGS - SAME AS YOURS
    final prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('rest_name') ?? "RestroPro Kitchen";
    String address = prefs.getString('rest_address') ?? "Harare, ZW";
    String phone = prefs.getString('rest_phone') ?? "";

    await bluetooth.connect(mac);
    await Future.delayed(const Duration(seconds: 1));

    // HEADER WITH RESTAURANT DETAILS
    await bluetooth.printCustom(name.toUpperCase(), 3, 1); // size 3, align center
    await bluetooth.printCustom(address, 1, 1);
    if(phone.isNotEmpty) {
      await bluetooth.printCustom(phone, 1, 1);
    }
    await bluetooth.printCustom(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), 1, 1);
    await bluetooth.printNewLine();
    
    // ITEMS - WITH VARIANT - SAME AS YOURS
    for(var item in cart) {
      double qty = (item['qty'] as num).toDouble();
      double price = (item['price'] as num).toDouble();
      String variant = item['variant'] ?? ''; // ADDED
      
      await bluetooth.printCustom('${item['name']}', 2, 0); // NAME BOLD size 2
      if(variant.isNotEmpty) {
        await bluetooth.printCustom('  $variant', 0, 0); // INDENTED VARIANT
      }
      await bluetooth.printLeftRight("  ${qty}x \$${price.toStringAsFixed(2)}", "\$${(qty*price).toStringAsFixed(2)}", 0); // INDENTED
    }
    
    await bluetooth.printNewLine();
    await bluetooth.printLeftRight("TOTAL", "\$${total.toStringAsFixed(2)}", 2); // size 2 bold right
    await bluetooth.printNewLine();
    await bluetooth.printCustom('Thank you for your business!', 1, 1);
    await bluetooth.printCustom('Powered by CoreVanta', 0, 1);
    await bluetooth.printNewLine();
    await bluetooth.printNewLine();
    await bluetooth.printNewLine(); // CY-BX58D FIX: Force feed paper
    await bluetooth.paperCut(); // CY-BX58D FIX: Cut

    await Future.delayed(const Duration(milliseconds: 800));
    await bluetooth.disconnect();
  }
}