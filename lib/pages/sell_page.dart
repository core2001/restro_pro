import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/print_service_mobile.dart';

class SellPage extends StatefulWidget {
  final VoidCallback onSale;
  const SellPage({super.key, required this.onSale});
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  List stocks = [];
  List cart = [];
  final printer = PrintService();

  @override
  void initState() {
    super.initState();
    DBHelper.getStocks().then((v)=>setState(()=>stocks=v));
  }

  addToCart(Map stock) {
    if(stock['qty'] <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Out of stock')));
      return;
    }
    setState((){
      var existing = cart.where((c)=>c['stock_id']==stock['id']).toList();
      if(existing.isEmpty) cart.add({'stock_id': stock['id'], 'name': stock['name'], 'qty': 1.0, 'price': stock['unit_price']});
      else existing.first['qty'] += 1.0;
    });
  }

  checkout() async {
    double total = cart.fold(0, (sum, i)=> sum + (i['qty']*i['price']));
    await DBHelper.makeSale(cart, total);
    await printer.printReceipt(cart, total);
    cart.clear();
    widget.onSale();
    setState((){});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale complete & Printed')));
  }

  @override
  Widget build(BuildContext context) {
    double total = cart.fold(0, (sum, i)=> sum + (i['qty']*i['price']));
    return Scaffold(
      appBar: AppBar(title: Text('New Sale'), backgroundColor: Colors.orange),
      body: Column(children:[
        Expanded(child: GridView.count(crossAxisCount: 2, children: stocks.map((s)=>
          Card(child: InkWell(onTap: ()=>addToCart(s), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
            Text(s['name'], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            Text('\$${s['unit_price']}', style: TextStyle(color: Colors.grey)),
            Text('Left: ${s['qty']}', style: TextStyle(fontSize: 12, color: s['qty']<5? Colors.red:Colors.green))
          ])))
        ).toList())),
        Container(height: 200, child: ListView(children: cart.map((i)=>ListTile(
          title: Text(i['name']), 
          trailing: Text('${i['qty']} x \$${i['price']}')
        )).toList())),
        Container(padding: EdgeInsets.all(12), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total: \$${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ElevatedButton(onPressed: cart.isEmpty? null : checkout, child: Text('Pay & Print'))
          ],
        ))
      ]),
    );
  }
}