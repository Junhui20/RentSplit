import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'widgets/main_navigation.dart';
import 'providers/app_state_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RentSplitMalaysiaApp());
}

class RentSplitMalaysiaApp extends StatelessWidget {
  const RentSplitMalaysiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateProvider(),
      child: MaterialApp(
        title: 'RentSplit Malaysia',
        debugShowCheckedModeBanner: false,
        
        // Malaysian localization support
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'MY'), // English (Malaysia)
          Locale('ms', 'MY'), // Bahasa Malaysia
        ],
        locale: const Locale('en', 'MY'),
        
        // Modern Light Blue Theme
        theme: AppTheme.lightTheme,
        
        home: const MainNavigation(),
      ),
    );
  }
}