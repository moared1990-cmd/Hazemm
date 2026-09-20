import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: const Color(0xFF3B6FE0),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
