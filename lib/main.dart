import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Wallet',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState.openDrawer();
  }

  void _closeDrawer() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My wallets')),
      body: _buildBody(context),
      drawer: Drawer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('This is the Drawer'),
              RaisedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TransactionsPage()),
                  );
                },
                child: const Text('Transactions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('baby').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        return _buildList(context, snapshot.data.documents);
      },
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) => _buildListItem(context, data)).toList(),
    );
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot data) {
    final record = Record.fromSnapshot(data);

    return Padding(
      key: ValueKey(record.name),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: ListTile(
          title: Text(record.name),
          trailing: Text(record.amount.toString()),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetailScreen(record)),
            );
          },
        ),
      ),
    );
  }
}

class Record {
  final String name;
  final int amount;
  final String ref;
  final DocumentReference reference;

  Record.fromMap(Map<String, dynamic> map, {this.reference})
      : name = map['name'],
        amount = map['amount'],
        ref = map['ref'];

  Record.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);
}

class DetailScreen extends StatelessWidget {
  final Record record;

  DetailScreen(this.record);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(record.name),
      ),
      body: ListView(
        children: <Widget>[
          Text("You have: " + record.amount.toString()),
          RaisedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TransferScreen(record)),
              );
            },
            child: Text('Transfer'),
          ),
          Text("You reference is : " + record.ref),
        ],
      ),
    );
  }
}

class TransferScreen extends StatelessWidget {
  final Record record;
  final _mobile = TextEditingController();
  final _amount = TextEditingController();

  TransferScreen(this.record);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transfer"),
      ),
      body: ListView(
        children: <Widget>[
          TextField(
            controller: _mobile,
            decoration: InputDecoration(
              filled: true,
              labelText: 'Mobile number',
            ),
          ),
          SizedBox(height: 12.0),
          TextField(
            controller: _amount,
            decoration: InputDecoration(
              filled: true,
              labelText: 'Amount',
            ),
          ),
          RaisedButton(
            onPressed: () {
              // 1) deduct points from owner {ref mobile number}
              record.reference.updateData({
                'amount': FieldValue.increment(int.parse(_amount.text) * -1)
              });
              // 2) add points = {amount} from {mobile number}
              Firestore.instance
                  .collection('baby')
                  .document(_mobile.text)
                  .updateData({
                'amount': FieldValue.increment(int.parse(_amount.text))
              });
              // 3) create transaction log
              Firestore.instance.collection('transactions').add({
                'from': record.ref,
                'to': _mobile.text,
                'amount': int.parse(_amount.text),
                'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
              });
            },
            child: Text('Transfer'),
          ),
        ],
      ),
    );
  }
}

class TransactionsPage extends StatefulWidget {
  @override
  _TransactionsPageState createState() {
    return _TransactionsPageState();
  }
}

class _TransactionsPageState extends State<TransactionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Transactions')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('transactions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();

        return _buildList(context, snapshot.data.documents);
      },
    );
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) => _buildListItem(context, data)).toList(),
    );
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot data) {
    final record = TxRecord.fromSnapshot(data);

    return Padding(
      key: ValueKey(record.from),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: ListTile(
          title: Text("From: " + record.from + " To: " + record.to),
          subtitle: Text("Timestamp: " + record.timestamp),
          trailing: Text("Amount: " + record.amount.toString()),
        ),
      ),
    );
  }
}

class TxRecord {
  final String from;
  final String to;
  final int amount;
  final String timestamp;
  final DocumentReference reference;

  TxRecord.fromMap(Map<String, dynamic> map, {this.reference})
      : from = map['from'],
        to = map['to'],
        timestamp = map['timestamp'].toString(),
        amount = map['amount'];

  TxRecord.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);
}
