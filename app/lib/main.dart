import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/api_client.dart';
import 'features/suggestions/suggestions_screen.dart';
import 'features/tours/tour_form_screen.dart';
import 'features/saved/saved_screen.dart';
import 'theme/app_theme.dart';

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
    theme: buildAppTheme(),
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
  // Saved list is rebuilt on each visit so new saves show up.
  int savedVisits = 0;
  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          // IndexedStack keeps form input and results when switching tabs.
          child: IndexedStack(
            index: tab,
            children: [
              SuggestionsScreen(api: api),
              TourFormScreen(api: api),
              SavedScreen(key: ValueKey(savedVisits), api: api),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() {
        if (v == 2 && tab != 2) savedVisits++;
        tab = v;
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.near_me_outlined),
          selectedIcon: Icon(Icons.near_me),
          label: 'Gợi ý nhanh',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Tour',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Đã lưu',
        ),
      ],
    ),
  );
}
