//main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receipt_reader/screens/category_products_page.dart';
import 'package:receipt_reader/screens/change_password_page.dart';
import 'package:receipt_reader/screens/receipt_page.dart';
import 'package:receipt_reader/screens/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'screens/home_page.dart';
import 'screens/profile_page.dart';
import 'screens/login_page.dart';
import 'package:receipt_reader/screens/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String _title = 'Receipt Reader';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      debugShowCheckedModeBanner: false,
      home: const AuthCheck(),
      onGenerateRoute: (RouteSettings settings) {
        final Uri uri = Uri.parse(settings.name ?? '');
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'products') {
          if (uri.pathSegments[1] == 'category') {
            final String category = uri.pathSegments[2];
            return MaterialPageRoute(
              builder: (context) =>
                  CategoryProductsPage(categoryName: category),
            );
          }
        }

        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
                builder: (context) => const MyMainPage(toIndex: 0));
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/register':
            return MaterialPageRoute(
                builder: (context) => const RegisterPage());
          case '/settings':
            return MaterialPageRoute(
                builder: (context) => const SettingsPage());
          case '/profile':
            return MaterialPageRoute(builder: (context) => const ProfilePage());
          case '/all_receipts':
            return MaterialPageRoute(builder: (context) => const ReceiptPage());
          case '/change_password':
            return MaterialPageRoute(
                builder: (context) => const ChangePasswordPage());
          default:
            return null;
        }
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (kDebugMode) print('isloggedIn: $isLoggedIn');

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class MyMainPage extends StatefulWidget {
  const MyMainPage({super.key, required this.toIndex});
  final int toIndex;
  @override
  State<MyMainPage> createState() => _MyMainPageState();
}

class _MyMainPageState extends State<MyMainPage> {
  Client client = http.Client();
  late int _index;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _index = widget.toIndex;
    _pageController = PageController(initialPage: _index);
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
    });
  }

  final pages = [
    const HomePage(),
    const ReceiptPage(),
    const ProfilePage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: pages,
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7),
          child: GNav(
            backgroundColor: Colors.black,
            color: Colors.white,
            activeColor: Colors.white,
            tabBackgroundColor: const Color.fromARGB(255, 48, 48, 48),
            gap: 3,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14),
            tabs: const [
              GButton(icon: Icons.home, text: 'Home'),
              GButton(icon: Icons.shopping_cart, text: 'Receipt'),
              GButton(icon: Icons.account_circle, text: 'Account'),
              GButton(icon: Icons.settings, text: 'Settings'),
            ],
            selectedIndex: _index,
            onTabChange: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
