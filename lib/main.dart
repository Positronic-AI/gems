import 'package:flutter/material.dart';
import 'models/palette.dart';
import 'services/daily_gem.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

/// Lets screens refresh when navigation returns to them (RouteAware).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  WidgetsFlutterBinding.ensureInitialized();
  await ActivePalette.load();
  await DailyGem.loadDebugOffset();
  runApp(const GemGame());
}

class GemGame extends StatelessWidget {
  const GemGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'Gem Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
