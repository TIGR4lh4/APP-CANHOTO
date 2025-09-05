import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ import necessário
import 'screens/login.dart';
import 'screens/empresa_nf_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canhoto NF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,

      // ✅ Localizações para DatePicker, TimePicker etc
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // português Brasil
        Locale('en', 'US'), // inglês
      ],

      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/empresas': (context) => EmpresaNFScreen(),
      },
    );
  }
}
