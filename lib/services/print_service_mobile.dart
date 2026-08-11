import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils.dart';

class PrintService {
  // Get already paired/bonded devices
  Future<List<BluetoothDevice>> getDevices() async {
    await FlutterBluePlus.turnOn();
    return await FlutterBluePlus.bondedDevices;
  }

  Future<void> printReceipt(List<Map> cart, double total) async {
    var devices = await getDevices();
    if (devices.isEmpty) throw 'No paired printer. Pair in Android Settings';

    // Find printer by name
    var printer = devices.firstWhere(
      (d) => d.platformName.toLowerCase().contains('printer'),
      orElse: () => devices.first
    );

    // Connect
    await printer.connect(timeout: const Duration(seconds: 15));
    await Future.delayed(const Duration(milliseconds: 500)); // let it stabilize

    // Discover services and find a write characteristic
    List<BluetoothService> services = await printer.discoverServices();
    BluetoothCharacteristic? writeChar;

    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          writeChar = char;
          break;
        }
      }
      if (writeChar != null) break;
    }

    if (writeChar == null) {
      await printer.disconnect();
      throw 'No writable characteristic found. Printer may not support BLE SPP';
    }

    // Generate ESC/POS bytes
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('RESTRO PRO', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Harare, ZW', styles: PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.text(DateTime.now().toString());
    bytes += generator.hr();

    for (var item in cart) {
      bytes += generator.row([
        PosColumn(text: item['name'], width: 4),
        PosColumn(text: '${item['qty']}', width: 1),
        PosColumn(text: '\$${(item['qty'] * item['price']).toStringAsFixed(2)}', width: 3, styles: PosStyles(align: PosAlign.right))
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('TOTAL: \$${total.toStringAsFixed(2)}', styles: PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size1));
    bytes += generator.feed(2);
    bytes += generator.cut();

    // Send in chunks of 20 bytes - BLE MTU limit
    const int chunkSize = 20;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      await writeChar.write(bytes.sublist(i, end), withoutResponse: true);
      await Future.delayed(const Duration(milliseconds: 20)); // don't flood
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await printer.disconnect();
  }
}