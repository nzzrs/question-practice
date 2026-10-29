import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../core/domain/models.dart';
import '../features/home/home_page.dart';
import 'providers.dart';
import 'theme.dart';

class QuestionPracticeApp extends ConsumerWidget {
  const QuestionPracticeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    return M3EMaterialApp(
      title: 'question practice',
      debugShowCheckedModeBanner: false,
      data: appThemeData(),
      autoTheming: true,
      dynamicColoring: settings.dynamicColor,
      drawUnderSystemBars: true,
      home: const HomePage(),
    );
  }
}
