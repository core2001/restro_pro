import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PrintService {
  static const _printerKey = 'selected_printer_mac';
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;

  Future<void> savePrinter(String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerKey, macAddress);
  }

  Future<String?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerKey);
  }

  Future<bool> _connect(String mac) async {
    _connectedDevice = BluetoothDevice.fromId(mac);
    await _connectedDevice!.connect(timeout: const Duration(seconds: 10), autoConnect: false);
    
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          _writeCharacteristic = char;
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _writeCharacteristic = null;
  }

  Future<void> _write(Uint8List data) async {
    if (_writeCharacteristic == null) throw Exception("Not connected to printer");
    await _writeCharacteristic!.write(data, withoutResponse: true);
    await Future.delayed(const Duration(milliseconds: 30));
  }

  Future<List<int>> _escPosBytes(List<Map<String, dynamic>> cart, double total) async { // <-- MADE ASYNC
    final prefs = await SharedPreferences.getInstance(); // <-- NOW WORKS
    String name = prefs.getString('rest_name') ?? "RestroPro";
    String address = prefs.getString('rest_address') ?? "Harare, ZW";

    List<int> bytes = [];
    bytes += [27, 64]; // INIT
    bytes += [27, 97, 1]; // CENTER ALIGN
    bytes += [27, 33, 16]; // BOLD + DOUBLE HEIGHT
    bytes += utf8.encode("${name.toUpperCase()}\n");
    bytes += [27, 33, 0]; // NORMAL
    bytes += utf8.encode("$address\n");
    bytes += utf8.encode("${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}\n");
    bytes += utf8.encode("--------------------------------\n");
    bytes += [27, 97, 0]; // LEFT ALIGN
    
    for(var item in cart) {
      double qty = (item['qty'] as num).toDouble();
      double price = (item['price'] as num).toDouble();
      double lineTotal = qty * price;
      String itemName = "${item['name']}";
      String variant = item['variant'] ?? '';
      
      bytes += utf8.encode("$itemName\n");
      if(variant.isNotEmpty) bytes += utf8.encode("  $variant\n");
      
      String qtyPrice = "  ${qty}x \$${price.toStringAsFixed(2)}";
      String lineTotalStr = "\$${lineTotal.toStringAsFixed(2)}";
      String line = qtyPrice.padRight(32 - lineTotalStr.length) + lineTotalStr + "\n";
      bytes += utf8.encode(line);
    }
    
    bytes += utf8.encode("--------------------------------\n");
    bytes += [27, 69, 1]; // BOLD ON
    String totalStr = "\$${total.toStringAsFixed(2)}";
    String totalLine = "TOTAL".padRight(32 - totalStr.length) + totalStr + "\n\n";
    bytes += utf8.encode(totalLine);
    bytes += [27, 69, 0]; // BOLD OFF
    bytes += [29, 86, 0]; // FULL CUT
    bytes += [10, 10, 10]; // FEED
    return bytes;
  }

  Future<void> printReceipt(List<Map<String, dynamic>> cart, double total) async {
    String? mac = await getSavedPrinter();
    if(mac == null) throw Exception("No printer selected. Go to Printer Settings");

    bool connected = await _connect(mac);
    if(!connected) throw Exception("Could not connect. Is printer ON?");

    List<int> bytes = await _escPosBytes(cart, total); // <-- ADD AWAIT
    
    for (int i = 0; i < bytes.length; i += 20) {
      int end = (i + 20 < bytes.length) ? i + 20 : bytes.length;
      await _write(Uint8List.fromList(bytes.sublist(i, end)));
    }
    
    await Future.delayed(const Duration(milliseconds: 800));
    await _disconnect();
  }
}