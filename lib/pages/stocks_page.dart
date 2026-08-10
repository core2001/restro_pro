import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class StocksPage extends StatefulWidget {
  final VoidCallback onUpdate;
  const StocksPage({super.key, required this.onUpdate});
  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  List stocks = [];
  final _formKey = GlobalKey<FormState>();
  TextEditingController name = TextEditingController();
  TextEditingController qty = TextEditingController();
  TextEditingController price = TextEditingController();
  TextEditingController alert = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  load() async {
    stocks = await DBHelper.getStocks();
    setState((){});
  }

  save() async {
    if(_formKey.currentState!.validate()){
      await DBHelper.addStock({
        'name': name.text,
        'qty': double.parse(qty.text),
        'unit': 'plate',
        'unit_price': double.parse(price.text),
        'low_alert': double.parse(alert.text)
      });
      Navigator.pop(context);
      load();
      widget.onUpdate();
    }
  }

  showAddDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Add New Meal'),
      content: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children:[
        TextFormField(controller: name, decoration: InputDecoration(labelText: 'Meal Name'), validator: (v)=>v!.isEmpty?'Required':null),
        TextFormField(controller: qty, decoration: InputDecoration(labelText: 'Initial Qty'), keyboardType: TextInputType.number),
        TextFormField(controller: price, decoration: InputDecoration(labelText: 'Unit Price \$'), keyboardType: TextInputType.number),
        TextFormField(controller: alert, decoration: InputDecoration(labelText: 'Low Stock Alert At'), keyboardType: TextInputType.number),
      ])),
      actions: [TextButton(onPressed: Navigator.of(context).pop, child: Text('Cancel')), ElevatedButton(onPressed: save, child: Text('Save'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Stocks'), backgroundColor: Colors.orange),
      floatingActionButton: FloatingActionButton(onPressed: showAddDialog, child: Icon(Icons.add)),
      body: ListView(children: stocks.map((s)=>Card(
        child: ListTile(
          title: Text(s['name']),
          subtitle: Text('Qty: ${s['qty']} | Price: \$${s['unit_price']}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children:[
            IconButton(icon: Icon(Icons.add), onPressed: (){
              TextEditingController c = TextEditingController();
              showDialog(context: context, builder: (_)=>AlertDialog(
                title: Text('Top Up ${s['name']}'),
                content: TextField(controller: c, keyboardType: TextInputType.number),
                actions: [ElevatedButton(onPressed: () async {
                  await DBHelper.topUpStock(s['id'], double.parse(c.text));
                  Navigator.pop(context); load(); widget.onUpdate();
                }, child: Text('Add'))]
              ));
            }),
            IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () async {
              await DBHelper.deleteStock(s['id']); load(); widget.onUpdate();
            })
          ])
        )
      )).toList()),
    );
  }
}