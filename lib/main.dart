import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/form_screen.dart';

void main() {
  runApp(FLY2WApp());
}

class FLY2WApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLY2W 365',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/form': (context) => FormScreen(),
      },
    );
  }
}
