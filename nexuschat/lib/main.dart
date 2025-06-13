import 'dart:io';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:nexuschat/menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _userLoggedIn;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? email = prefs.getString('user_email');

    setState(() {
      _userLoggedIn = email != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      dark: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
      ),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NexusChat',
        theme: theme,
        darkTheme: darkTheme,
        home: _userLoggedIn == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : (_userLoggedIn! ? const Menu() : const Login()),
      ),
    );
  }
}
