import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/api_client.dart';
import 'features/suggestions/suggestions_screen.dart';
import 'features/tours/tour_form_screen.dart';
import 'features/saved/saved_screen.dart';

void main() => runApp(const DiDauApp());

class DiDauApp extends StatelessWidget {
  const DiDauApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Đi Đâu',
    debugShowCheckedModeBanner: false,
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      fontFamily: 'RobotoLocal',
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff167565)),
      scaffoldBackgroundColor: const Color(0xfffaf8f3),
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final api = ApiClient();
  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đi Đâu')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: tab == 0
            ? SuggestionsScreen(api: api)
            : tab == 1
            ? TourFormScreen(api: api)
            : SavedScreen(api: api),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.near_me_outlined),
          label: 'Gợi ý nhanh',
        ),
        NavigationDestination(icon: Icon(Icons.route_outlined), label: 'Tour'),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          label: 'Đã lưu',
        ),
      ],
    ),
  );
}
