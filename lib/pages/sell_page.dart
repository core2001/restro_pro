import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
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
    if((stock['qty'] as double) <= 0) {
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
          'price': stock['unit_price']
        });
      }
      else {
        if(existing.first['qty'] >= stock['qty']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Not enough stock'), backgroundColor: Colors.orange)
          );
          return;
        }
        existing.first['qty'] += 1.0;
      }
    });
  }

  removeFromCart(Map<String, dynamic> item) {
    setState((){
      if(item['qty'] > 1) item['qty'] -= 1.0;
      else cart.remove(item);
    });
  }

  showReceiptDialog(double total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptDialog(cart: cart, total: total)
    );
    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if(mounted) Navigator.of(context).pop();
    });
  }

  checkout() async {
    if(cart.isEmpty) return;
    double total = cart.fold(0.0, (sum, i)=> sum + (i['qty']*i['price']));
    
    // 1. Save sale
    await DBHelper.makeSale(cart, total); 
    
    // 2. Deduct stock qty for each item
    for(var item in cart) {
      var stock = stocks.firstWhere((s) => s['id'] == item['stock_id']);
      double newQty = (stock['qty'] as double) - (item['qty'] as double);
      await DBHelper.updateStockQty(stock['id'], newQty);
    }
    
    // 3. Show Pro Receipt on screen
    showReceiptDialog(total);
    
    // 4. Print receipt
    try {
      await printer.printReceipt(cart, total);
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
    double total = cart.fold(0.0, (sum, i)=> sum + (i['qty']*i['price']));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('New Sale', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orange,
        elevation: 0,
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
                        subtitle: Text('\$${(i['price'] as double).toStringAsFixed(2)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: Icon(Icons.remove_circle_outline, size: 20), onPressed: ()=>removeFromCart(i)),
                            Text('${i['qty']}', style: TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: Icon(Icons.add_circle_outline, size: 20), onPressed: ()=>addToCart(stocks.firstWhere((s)=>s['id']==i['stock_id']))),
                          ],
                        )
                      )).toList()
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

  Widget _productCard(Map s) {
    double qty = (s['qty'] as double);
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
              Text('\$${(s['unit_price'] as double).toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(
                'Left: $qty', 
                style: TextStyle(
                  fontSize: 12, 
                  color: outOfStock? Colors.red : (qty < 5? Colors.orange : Colors.green),
                  fontWeight: FontWeight.w600
                )
              )
            ]
          ),
        )
      ),
    );
  }
}


/// PRO RECEIPT DIALOG
class _ReceiptDialog extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final double total;
  const _ReceiptDialog({required this.cart, required this.total});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 40, color: Colors.orange),
            const SizedBox(height: 8),
            Text('RESTROPRO', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Harare, ZW', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Divider(thickness: 1, color: Colors.grey.shade300),
            
            // Items
            ...cart.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${item['name']}', style: GoogleFonts.poppins(fontSize: 13))),
                  Text('${item['qty']} x \$${(item['price'] as double).toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13)),
                  const SizedBox(width: 8),
                  Text('\$${((item['qty'] as double)*(item['price'] as double)).toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
            
            Divider(thickness: 1, color: Colors.grey.shade300),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Thank you for your business!', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
            Text('Powered by RestroPro', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}