import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const PaletteApp());

// ------------------------------------------------------------------- Цвет

// Цвет храним как три числа 0..255 и сами считаем HEX и яркость
class PaletteColor {
  const PaletteColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  Color get color => Color.fromARGB(255, r, g, b);

  String get hex {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${h(r)}${h(g)}${h(b)}'.toUpperCase();
  }

  // Светлый ли цвет: от этого зависит, чёрным или белым писать текст
  bool get isLight => (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.6;
}

// HSL (оттенок, насыщенность, светлота) -> RGB.
// В HSL удобно подбирать красивые сочетания: меняем оттенок на заданный угол.
PaletteColor hslToColor(double h, double s, double l) {
  final hue = (h % 360) / 60;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - (hue % 2 - 1).abs());

  double r = 0, g = 0, b = 0;
  if (hue < 1) {
    r = c;
    g = x;
  } else if (hue < 2) {
    r = x;
    g = c;
  } else if (hue < 3) {
    g = c;
    b = x;
  } else if (hue < 4) {
    g = x;
    b = c;
  } else if (hue < 5) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }

  final m = l - c / 2;
  int to255(double v) => ((v + m) * 255).round().clamp(0, 255);
  return PaletteColor(to255(r), to255(g), to255(b));
}

// ---------------------------------------------------------------- Схемы

// Схема: на сколько градусов сдвигается оттенок каждого из 5 цветов
class HarmonyScheme {
  const HarmonyScheme(this.name, this.offsets);

  final String name;
  final List<double> offsets;
}

const List<HarmonyScheme> kSchemes = [
  HarmonyScheme('Соседние', [-40, -20, 0, 20, 40]),
  HarmonyScheme('Контраст', [0, 15, 180, 195, 30]),
  HarmonyScheme('Триада', [0, 120, 240, 15, 135]),
  HarmonyScheme('Один цвет', [0, 0, 0, 0, 0]),
];

// От тёмного к светлому: палитра выглядит цельной
const List<double> kLightness = [0.28, 0.42, 0.55, 0.68, 0.82];

// -------------------------------------------------------------- Приложение

class PaletteApp extends StatelessWidget {
  const PaletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Палитры',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Random _rng = Random();
  late List<PaletteColor> _colors;
  final List<bool> _locked = List.filled(5, false);
  int _schemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _colors = List.filled(5, const PaletteColor(128, 128, 128));
    _generate();
  }

  void _generate() {
    final baseHue = _rng.nextDouble() * 360;
    final scheme = kSchemes[_schemeIndex];

    setState(() {
      for (var i = 0; i < 5; i++) {
        if (_locked[i]) continue; // закреплённые цвета не меняем

        final saturation = 0.5 + _rng.nextDouble() * 0.35; // 0.50 .. 0.85
        final lightness = kLightness[i] + (_rng.nextDouble() - 0.5) * 0.08;
        _colors[i] = hslToColor(
          baseHue + scheme.offsets[i],
          saturation,
          lightness,
        );
      }
    });
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Палитры'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Копировать все цвета',
            onPressed: () => _copy(
              _colors.map((c) => c.hex).join(', '),
              'Скопированы все 5 цветов',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Пять полос-цветов
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: _ColorStripe(
                        color: _colors[i],
                        locked: _locked[i],
                        onTap: () => _copy(
                          _colors[i].hex,
                          'Скопировано: ${_colors[i].hex}',
                        ),
                        onToggleLock: () =>
                            setState(() => _locked[i] = !_locked[i]),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < kSchemes.length; i++)
                        ChoiceChip(
                          label: Text(kSchemes[i].name),
                          selected: _schemeIndex == i,
                          onSelected: (_) {
                            _schemeIndex = i;
                            _generate();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Новая палитра'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите на цвет, чтобы скопировать код. Замок закрепляет цвет.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorStripe extends StatelessWidget {
  const _ColorStripe({
    required this.color,
    required this.locked,
    required this.onTap,
    required this.onToggleLock,
  });

  final PaletteColor color;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final textColor = color.isLight ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // цвет меняется плавно, а не скачком (урок 11)
        duration: const Duration(milliseconds: 400),
        color: color.color,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                color.hex,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: textColor,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                locked ? Icons.lock : Icons.lock_open,
                color: textColor,
              ),
              tooltip: locked ? 'Открепить' : 'Закрепить',
              onPressed: onToggleLock,
            ),
          ],
        ),
      ),
    );
  }
}
