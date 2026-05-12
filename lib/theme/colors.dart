import 'package:flutter/material.dart';

class MessengerColors {
  // Primary Messenger Gradient Colors
  static const Color messengerBlue = Color(0xFF0084FF);
  static const Color messengerPurple = Color(0xFF7B61FF);
  static const LinearGradient messengerGradient = LinearGradient(
    colors: [messengerBlue, messengerPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backgrounds
  static const Color chatBackground = Color(0xFFF0F2F5);
  static const Color tileBackground = Colors.white;

  // Message Bubbles
  static const Color sentBubbleText = Colors.white;
  static const Color receivedBubbleBackground = Color(0xFFE4E6EB);
  static const Color receivedBubbleText = Colors.black;

  // Online Status
  static const Color onlineGreen = Color(0xFF31A24C);
  static const Color offlineGray = Color(0xFF8A8D91);

  // UI Elements
  static const Color inputFieldBackground = Color(0xFFF0F2F5);
  static const Color inputFieldHint = Color(0xFF8A8D91);
  static const Color dividerColor = Color(0xFFE5E5EA);
}

class MessengerTheme {
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: MessengerColors.messengerBlue,
      scaffoldBackgroundColor: MessengerColors.chatBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: MessengerColors.messengerBlue,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF8A8D91), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MessengerColors.inputFieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: MessengerColors.messengerBlue,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(
          color: MessengerColors.inputFieldHint,
          fontSize: 16,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MessengerColors.messengerBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MessengerColors.inputFieldBackground,
        labelStyle: const TextStyle(color: Colors.black, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: MessengerColors.messengerBlue,
        unselectedLabelColor: Color(0xFF8A8D91),
        indicatorColor: MessengerColors.messengerBlue,
        dividerColor: MessengerColors.dividerColor,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.white,
        shape: Border(),
      ),
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: MessengerColors.messengerBlue,
      scaffoldBackgroundColor: const Color(0xFF111418),
      canvasColor: const Color(0xFF111418),
      cardColor: const Color(0xFF1B1F24),
      dialogBackgroundColor: const Color(0xFF1B1F24),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF111418),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFFB0B3B8), fontSize: 14),
        bodySmall: TextStyle(color: Color(0xFFB0B3B8), fontSize: 12),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B1F24),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: MessengerColors.messengerBlue,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(color: Color(0xFF8A8D91), fontSize: 16),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MessengerColors.messengerBlue,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1B1F24),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: MessengerColors.messengerBlue,
        unselectedLabelColor: Color(0xFF8A8D91),
        indicatorColor: MessengerColors.messengerBlue,
        dividerColor: Color(0xFF2A2F36),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0xFF1B1F24),
        textColor: Colors.white,
        shape: Border(),
      ),
    );
  }
}
