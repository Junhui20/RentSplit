import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'widgets/main_navigation.dart';
import 'providers/app_state_provider.dart';

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
        
        // Malaysian-themed Material Design
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF1E40AF), // Deep blue
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          
          // AppBar theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            elevation: 2,
            centerTitle: true,
          ),
          
          // Card theme for better Malaysian UI
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            color: Colors.white,
          ),
          
          // Button themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          
          // Text themes optimized for currency display
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            headlineMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          
          // Input decoration for forms
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          
          // Bottom navigation
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFF1E40AF),
            unselectedItemColor: Color(0xFF64748B),
            type: BottomNavigationBarType.fixed,
          ),
          
          // Color scheme for Material 3
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1E40AF),
            secondary: Color(0xFF0EA5E9),
            surface: Colors.white,
            error: Color(0xFFEF4444),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF1E293B),
            onError: Colors.white,
          ),
          
          // Use Material 3
          useMaterial3: true,
        ),
        
        home: const MainNavigation(),
      ),
    );
  }
}