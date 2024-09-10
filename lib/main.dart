import 'package:flutter/material.dart';
import 'package:testing_app/screens/splash_screen.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const SplashScreen(),
    theme: ThemeData(
      fontFamily: 'Moderustic', // Set your custom font family here
    ),
  ));
}
