import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADD THIS
import '../database/db_helper.dart';
import 'printer_settings_page.dart';
import '../services/print_service_mobile.dart';

class SellPage extends StatefulWidget {
  final VoidCallback onSale;
  const SellPage({super.key, required this.onSale});
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  List<Map<String, dynamic>> stocks = [];
  List<Map<String, dynamic>> cart = [];
  final printer = PrintService();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStocks();
  }

  loadStocks() async {
    stocks = await DBHelper.getStocks();
    setState(() => loading = false);
  }

  addToCart(Map<String, dynamic> stock) {
    double stockQty = (stock['qty'] as num).toDouble();
    if(stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stock['name']} is Out of Stock'), backgroundColor: Colors.red)
      );
      return;
    }
    setState((){
      var existing = cart.where((c)=>c['stock_id']==stock['id']).toList();
      if(existing.isEmpty) {
        cart.add({
          'stock_id': stock['id'], 
          'name': stock['name'], 
          'qty': 1.0, 
          'price': (stock['unit_price'] as num).toDouble(),
        }); // REMOVED low_alert from cart
      }
      else {
        double existingQty = (existing.first['qty'] as num).toDouble();
        if(existingQty >= stockQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Not enough stock'), backgroundColor: Colors.orange)
          );
          return;
        }
        existing.first['qty'] = existingQty + 1.0;
      }
    });
  }

  removeFromCart(Map<String, dynamic> item) {
    setState((){
      double qty = (item['qty'] as num).toDouble();
      if(qty > 1) item['qty'] = qty - 1.0;
      else cart.remove(item);
    });
  }

  showReceiptDialog(double total, List<Map<String, dynamic>> cartToShow) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptDialog(cart: cartToShow, total: total)
    );
    Future.delayed(const Duration(seconds: 3), () {
      if(mounted) Navigator.of(context).pop();
    });
  }

  checkout() async {
    if(cart.isEmpty) return;
    double total = cart.fold(0.0, (sum, i)=> sum + ((i['qty'] as num)*(i['price'] as num)));
    
    await DBHelper.makeSale(cart, total); 
    
    for(var item in cart) {
      var stock = stocks.firstWhere((s) => s['id'] == item['stock_id']);
      double newQty = (stock['qty'] as num).toDouble() - (item['qty'] as num).toDouble();
      await DBHelper.updateStockQty(stock['id'] as int, newQty);
    }
    
    final cartCopy = List<Map<String, dynamic>>.from(cart.map((e) => Map<String, dynamic>.from(e)));
    showReceiptDialog(total, cartCopy);
    
    try {
      await printer.printReceipt(cartCopy, total);
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale saved. Print failed: $e'), backgroundColor: Colors.orange)
      );
    }
    
    setState((){
      cart.clear();
      loading = true;
    });
    await loadStocks();
    widget.onSale();
  }

  @override
  Widget build(BuildContext context) {
    double total = cart.fold(0.0, (sum, i)=> sum + ((i['qty'] as num)*(i['price'] as num)));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('New Sale', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_bluetooth),
            onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => PrinterSettingsPage()))
          )
        ]
      ),
      body: loading 
       ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : Column(children:[
            Expanded(
              flex: 3,
              child: GridView.count(
                padding: const EdgeInsets.all(12),
                crossAxisCount: 2, 
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: stocks.map((s) => _productCard(s)).toList()
              )
            ),
            
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Cart (${cart.length})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                Expanded(
                  child: cart.isEmpty 
                   ? Center(child: Text('Tap items to add', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView(children: cart.map((i) => ListTile(
                        dense: true,
                        title: Text(i['name']), 
                        subtitle: Text('\$${(i['price'] as num).toDouble().toStringAsFixed(2)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: Icon(Icons.remove_circle_outline, size: 20), onPressed: ()=>removeFromCart(i)),
                            Text('${(i['qty'] as num).toDouble()}', style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: Icon(Icons.add_circle_outline, size: 20), onPressed: ()=>addToCart(stocks.firstWhere((s)=>s['id']==i['stock_id']))),
                          ],
                        )
                      )).toList()
                ),
                ), 
              ]),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: TextStyle(color: Colors.grey.shade600)),
                      Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: cart.isEmpty? null : checkout,
                    icon: Icon(Icons.print),
                    label: Text('Pay & Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                  )
                ],
              )
            )
          ]),
    );
  }

  Widget _productCard(Map<String, dynamic> s) {
    double qty = (s['qty'] as num).toDouble();
    bool outOfStock = qty <= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: outOfStock? null : ()=>addToCart(s),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children:[
              Icon(Icons.fastfood, size: 32, color: outOfStock? Colors.grey : Colors.orange),
              const SizedBox(height: 8),
              Text(s['name'], textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('\$${(s['unit_price'] as num).toDouble().toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text('Left: $qty', style: TextStyle(fontSize: 12, color: outOfStock? Colors.red : (qty < 5? Colors.orange : Colors.green), fontWeight: FontWeight.w600))
            ]
          ),
        )
      ),
    );
  }
}


// UPDATED RECEIPT DIALOG
class _ReceiptDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final double total;
  const _ReceiptDialog({required this.cart, required this.total});

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  String name = "RestroPro Kitchen";
  String address = "Harare, ZW";
  String phone = "";

  @override
  void initState() {
    super.initState();
    loadRestaurantDetails();
  }

  loadRestaurantDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('rest_name') ?? "RestroPro Kitchen";
      address = prefs.getString('rest_address') ?? "Harare, ZW";
      phone = prefs.getString('rest_phone') ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 40, color: Colors.orange),
            const SizedBox(height: 8),
            Text(name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(address, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            if(phone.isNotEmpty) Text(phone, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Divider(thickness: 1, color: Colors.grey.shade300),
            
            ...widget.cart.map((item) {
              double qty = (item['qty'] as num).toDouble();
              double price = (item['price'] as num).toDouble();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row( // REMOVED STOCK QUALITY ROW
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['name']}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Qty: $qty x \$${price.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    Text('\$${(qty * price).toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
            
            Divider(thickness: 1, color: Colors.grey.shade300),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('\$${widget.total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Thank you for your business!', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
            Text('Powered by CoreVanta', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}