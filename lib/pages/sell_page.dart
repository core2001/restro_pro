import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  final List<String> variants = ['Sadza', 'Rice', 'Chips', 'Plain'];

  @override
  void initState() {
    super.initState();
    loadStocks();
  }

  loadStocks() async {
    stocks = await DBHelper.getStocks();
    setState(() => loading = false);
  }

  showVariantPicker(Map<String, dynamic> stock) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Option for ${stock['name']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18)),
        content: SizedBox(
          width: size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: variants.map((v) => ListTile(
              title: Text(v, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 18 : 16)),
              onTap: () {
                Navigator.pop(context);
                addToCart(stock, v);
              },
            )).toList(),
          ),
        ),
      )
    );
  }

  addToCart(Map<String, dynamic> stock, String variant) {
    double stockQty = (stock['qty'] as num).toDouble();
    
    // Check total qty in cart for this stock_id
    double qtyInCart = cart.where((c)=>c['stock_id']==stock['id']).fold(0.0, (sum, i)=> sum + (i['qty'] as num).toDouble());
    
    if(qtyInCart >= stockQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stock['name']} is Out of Stock'), backgroundColor: Colors.red)
      );
      return;
    }
    
    setState((){
      var existing = cart.where((c)=>c['stock_id']==stock['id'] && c['variant']==variant).toList();
      if(existing.isEmpty) {
        cart.add({
          'stock_id': stock['id'], 
          'name': stock['name'], 
          'variant': variant,
          'qty': 1.0, 
          'price': (stock['unit_price'] as num).toDouble(),
        }); 
      }
      else {
        existing.first['qty'] = (existing.first['qty'] as num).toDouble() + 1.0;
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
    
    // NEW: Group by stock_id and subtract total qty from main stock
    Map<int, double> stockDeductions = {};
    for(var item in cart) {
      int stockId = item['stock_id'];
      double qty = (item['qty'] as num).toDouble();
      stockDeductions[stockId] = (stockDeductions[stockId]?? 0.0) + qty;
    }
    
    stockDeductions.forEach((stockId, totalQtyToDeduct) async {
      var stock = stocks.firstWhere((s) => s['id'] == stockId);
      double newQty = (stock['qty'] as num).toDouble() - totalQtyToDeduct;
      await DBHelper.updateStockQty(stockId, newQty);
    });
    
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
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('New Sale', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isTablet? 22 : 18)), 
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_bluetooth, size: isTablet? 28 : 24),
            onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_) => PrinterSettingsPage()))
          )
        ]
      ),
      body: loading 
     ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : Column(children:[
            Expanded(
              flex: isTablet? 5 : 3,
              child: GridView.builder(
                padding: EdgeInsets.all(isTablet? 20 : 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet? (isLandscape? 5 : 4) : 2,
                  crossAxisSpacing: isTablet? 20 : 12,
                  mainAxisSpacing: isTablet? 20 : 12,
                  childAspectRatio: isTablet? 1.0 : 0.9,
                ),
                itemCount: stocks.length,
                itemBuilder: (context, index) => _productCard(stocks[index], isTablet),
              )
            ),
            
            // CART SECTION - REDUCED HEIGHT: was 0.32 now 0.26
            Container(
              height: size.height * (isTablet? 0.38 : 0.26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: Column(children: [
                Padding(
                  padding: EdgeInsets.all(isTablet? 16 : 12),
                  child: Text('Cart (${cart.length})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isTablet? 20 : 16)),
                ),
                Expanded(
                  child: cart.isEmpty 
                 ? Center(child: Text('Tap items to add', style: TextStyle(color: Colors.grey.shade500, fontSize: isTablet? 16 : 14)))
                    : ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        var i = cart[index];
                        return ListTile(
                            dense:!isTablet,
                            title: Text('${i['name']} - ${i['variant']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isTablet? 18 : 15)),
                            subtitle: Text('\$${(i['price'] as num).toDouble().toStringAsFixed(2)} each', style: TextStyle(fontSize: isTablet? 15 : 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: Icon(Icons.remove_circle_outline, size: isTablet? 28 : 20), onPressed: ()=>removeFromCart(i)),
                                Text('${(i['qty'] as num).toDouble()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTablet? 18 : 16)),
                                IconButton(icon: Icon(Icons.add_circle_outline, size: isTablet? 28 : 20), onPressed: ()=>addToCart(stocks.firstWhere((s)=>s['id']==i['stock_id']), i['variant'])),
                              ],
                            )
                          );
                      }
                    ),
                ), 
              ]),
            ),
            
            Container(
              padding: EdgeInsets.all(isTablet? 20 : 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: isTablet? 16 : 14)),
                      Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: isTablet? 32 : 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: cart.isEmpty? null : checkout,
                    icon: Icon(Icons.print, size: isTablet? 28 : 24),
                    label: Text('Pay & Print', style: TextStyle(fontSize: isTablet? 18 : 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isTablet? 30 : 20, vertical: isTablet? 18 : 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                  )
                ],
              )
            )
          ]),
    );
  }

  Widget _productCard(Map<String, dynamic> s, bool isTablet) {
    double qty = (s['qty'] as num).toDouble();
    bool outOfStock = qty <= 0;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: outOfStock? null : ()=>showVariantPicker(s),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isTablet? 16 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children:[
              Icon(Icons.fastfood, size: isTablet? 48 : 32, color: outOfStock? Colors.grey : Colors.orange),
              SizedBox(height: isTablet? 12 : 8),
              Text(s['name'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isTablet? 18 : 14)),
              const SizedBox(height: 4),
              Text('\$${(s['unit_price'] as num).toDouble().toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700, fontSize: isTablet? 16 : 14)),
              const SizedBox(height: 4),
              Text('Left: $qty', style: TextStyle(fontSize: isTablet? 14 : 12, color: outOfStock? Colors.red : (qty < 5? Colors.orange : Colors.green), fontWeight: FontWeight.w600))
            ]
          ),
        )
      ),
    );
  }
}


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
      name = prefs.getString('rest_name')?? "RestroPro Kitchen";
      address = prefs.getString('rest_address')?? "Harare, ZW";
      phone = prefs.getString('rest_phone')?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 600? 420.0 : 320.0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
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
              String variant = item['variant']?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['name']}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('$variant - Qty: $qty x \$${price.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
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