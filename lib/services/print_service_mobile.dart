import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial.dart'; // <- THIS IS CORRECT
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrintService {
  Future<List<BluetoothDevice>> getDevices() => FlutterBluetoothSerial.instance.getBondedDevices(); // <- NO Plus

  Future<void> printReceipt(List<Map<String, dynamic>> cart, double total) async {
    var devices = await getDevices();
    if(devices.isEmpty) throw 'No paired printer. Pair in Android Settings';
    var printer = devices.firstWhere(
      (d) => (d.name?? '').toLowerCase().contains('printer'),
      orElse: () => devices.first
    );
    var connection = await BluetoothConnection.toAddress(printer.address); // <- NO Plus

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('RESTRO PRO', styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Harare, ZW', styles: PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.text(DateTime.now().toString());
    bytes += generator.hr();

    for(var item in cart){
      bytes += generator.row([
        PosColumn(text: item['name'], width: 4),
        PosColumn(text: '${item['qty']}', width: 1),
        PosColumn(text: '\$${(item['qty']*item['price']).toStringAsFixed(2)}', width: 3, styles: PosStyles(align: PosAlign.right))
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('TOTAL: \$${total.toStringAsFixed(2)}', styles: PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size1));
    bytes += generator.feed(2);
    bytes += generator.cut();

    connection.output.add(bytes);
    await connection.output.allSent;
    connection.finish();
  }
}