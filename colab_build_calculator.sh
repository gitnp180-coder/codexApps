#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git unzip xz-utils zip libglu1-mesa openjdk-17-jdk wget ca-certificates python3 clang cmake ninja-build pkg-config

FLUTTER_CHANNEL=stable
FLUTTER_HOME=/opt/flutter
if [ ! -d "$FLUTTER_HOME" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
flutter --version

ANDROID_HOME=/opt/android-sdk
CMDLINE_TOOLS_ROOT="$ANDROID_HOME/cmdline-tools"
CMDLINE_TOOLS_LATEST="$CMDLINE_TOOLS_ROOT/latest"
mkdir -p "$CMDLINE_TOOLS_ROOT"

if [ ! -d "$CMDLINE_TOOLS_LATEST" ]; then
  cd /tmp
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -O cmdline-tools.zip
  unzip -q cmdline-tools.zip -d cmdline-tools-unzipped
  mkdir -p "$CMDLINE_TOOLS_LATEST"
  mv cmdline-tools-unzipped/cmdline-tools/* "$CMDLINE_TOOLS_LATEST/"
fi

export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME=/root/.android
mkdir -p "$ANDROID_USER_HOME"
touch "$ANDROID_USER_HOME/repositories.cfg"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null
sdkmanager --sdk_root="$ANDROID_HOME" --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"

flutter config --android-sdk "$ANDROID_HOME"
flutter precache --android
flutter doctor -v

cd /content
rm -rf calculator_app
flutter create calculator_app

cat > /content/calculator_app/lib/main.dart <<'DART'
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculator App',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: CalculatorPage(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const CalculatorPage({super.key, required this.isDark, required this.onToggleTheme});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expression = '';
  String _result = '0';
  bool _scientificMode = false;
  bool _degMode = true;
  double _memory = 0;

  static const List<String> _standardButtons = [
    'AC', 'C', '⌫', '÷',
    '7', '8', '9', '×',
    '4', '5', '6', '-',
    '1', '2', '3', '+',
    'M+', 'M-', 'MR', 'MC',
    '%', '0', '.', '=',
  ];

  static const List<String> _scientificButtons = [
    '(', ')', 'mod', '^',
    'sin', 'cos', 'tan', '!',
    'log', 'ln', '√', '∛',
    'x²', 'xʸ', 'π', 'e',
  ];

  void _onButtonPressed(String text) {
    setState(() {
      switch (text) {
        case 'AC':
          _expression = '';
          _result = '0';
          break;
        case 'C':
          _expression = '';
          break;
        case '⌫':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
          break;
        case '=':
          _evaluateExpression();
          break;
        case 'M+':
          _memory += double.tryParse(_result) ?? 0;
          break;
        case 'M-':
          _memory -= double.tryParse(_result) ?? 0;
          break;
        case 'MR':
          _expression += _formatNumber(_memory);
          break;
        case 'MC':
          _memory = 0;
          break;
        case 'x²':
          _expression += '^2';
          break;
        case 'xʸ':
          _expression += '^';
          break;
        case '√':
          _expression += 'sqrt(';
          break;
        case '∛':
          _expression += 'cbrt(';
          break;
        case '×':
          _expression += '*';
          break;
        case '÷':
          _expression += '/';
          break;
        case 'π':
          _expression += 'pi';
          break;
        default:
          _expression += text;
      }
    });
  }

  void _evaluateExpression() {
    try {
      final value = SafeExpressionEvaluator.evaluate(_expression, degMode: _degMode);
      _result = _formatNumber(value);
    } catch (_) {
      _result = 'Error';
    }
  }

  String _formatNumber(double value) {
    if (!value.isFinite) return 'Error';
    if (value.abs() > 1e15) return value.toStringAsExponential(8);
    if ((value - value.roundToDouble()).abs() < 1e-10) {
      return value.round().toString();
    }
    return value.toStringAsPrecision(12).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allButtons = _scientificMode ? [..._scientificButtons, ..._standardButtons] : _standardButtons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          Switch(
            value: _scientificMode,
            onChanged: (v) => setState(() => _scientificMode = v),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text(_scientificMode ? 'SCI' : 'STD')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.surfaceContainerHighest, cs.surface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _degMode ? 'DEG' : 'RAD',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _expression.isEmpty ? '0' : _expression,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _result,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _degMode = !_degMode),
                        child: const Text('Toggle DEG/RAD'),
                      )
                    ],
                  )
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 8 : 4;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: allButtons.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final label = allButtons[index];
                      final isOp = RegExp(r'^[+\-*/=^%]|÷|×|mod|!$').hasMatch(label) ||
                          {'sin', 'cos', 'tan', 'log', 'ln', '√', '∛', 'x²', 'xʸ'}.contains(label);
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.95, end: 1),
                        duration: const Duration(milliseconds: 180),
                        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                        child: ElevatedButton(
                          onPressed: () => _onButtonPressed(label),
                          style: ElevatedButton.styleFrom(
                            elevation: isOp ? 2 : 0,
                            backgroundColor: isOp ? cs.primaryContainer : cs.surfaceContainer,
                            foregroundColor: isOp ? cs.onPrimaryContainer : cs.onSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: FittedBox(
                            child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SafeExpressionEvaluator {
  static const Set<String> _functions = {
    'sin', 'cos', 'tan', 'log', 'ln', 'sqrt', 'cbrt',
  };

  static const Set<String> _operators = {
    '+', '-', '*', '/', '^', '%', 'mod', 'u-', '!'
  };

  static int _precedence(String op) {
    switch (op) {
      case '!':
        return 5;
      case 'u-':
        return 4;
      case '^':
        return 3;
      case '*':
      case '/':
      case '%':
      case 'mod':
        return 2;
      case '+':
      case '-':
        return 1;
      default:
        return 0;
    }
  }

  static bool _isRightAssociative(String op) => op == '^' || op == 'u-';

  static double evaluate(String input, {bool degMode = true}) {
    final sanitized = _sanitize(input);
    final tokens = _tokenize(sanitized);
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn, degMode: degMode);
  }

  static String _sanitize(String input) {
    if (input.length > 500) throw FormatException('Too long');
    final allowed = RegExp(r'^[0-9+\-*/^%!()., a-zA-Z]*$');
    if (!allowed.hasMatch(input)) {
      throw FormatException('Invalid chars');
    }
    return input.replaceAll(' ', '').replaceAll('mod', '%');
  }

  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    int i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        int j = i;
        while (j < input.length && RegExp(r'[0-9.]').hasMatch(input[j])) j++;
        final num = input.substring(i, j);
        if ('.'.allMatches(num).length > 1) throw FormatException('Bad decimal');
        tokens.add(num);
        i = j;
        continue;
      }
      if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        int j = i;
        while (j < input.length && RegExp(r'[a-zA-Z]').hasMatch(input[j])) j++;
        final word = input.substring(i, j);
        if (word == 'pi' || word == 'e' || _functions.contains(word)) {
          tokens.add(word);
        } else {
          throw FormatException('Unknown identifier: $word');
        }
        i = j;
        continue;
      }
      if ('()+-*/^%!'.contains(ch)) {
        tokens.add(ch);
        i++;
        continue;
      }
      throw FormatException('Invalid token: $ch');
    }
    return tokens;
  }

  static List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final stack = <String>[];

    for (int idx = 0; idx < tokens.length; idx++) {
      var token = tokens[idx];
      final prev = idx > 0 ? tokens[idx - 1] : '';

      if (double.tryParse(token) != null || token == 'pi' || token == 'e') {
        output.add(token);
      } else if (_functions.contains(token)) {
        stack.add(token);
      } else if (token == ',') {
        while (stack.isNotEmpty && stack.last != '(') {
          output.add(stack.removeLast());
        }
      } else if (_operators.contains(token)) {
        if (token == '-' && (idx == 0 || _operators.contains(prev) || prev == '(')) {
          token = 'u-';
        }
        while (stack.isNotEmpty && _operators.contains(stack.last)) {
          final top = stack.last;
          final cond = _isRightAssociative(token)
              ? _precedence(token) < _precedence(top)
              : _precedence(token) <= _precedence(top);
          if (!cond) break;
          output.add(stack.removeLast());
        }
        stack.add(token);
      } else if (token == '(') {
        stack.add(token);
      } else if (token == ')') {
        while (stack.isNotEmpty && stack.last != '(') {
          output.add(stack.removeLast());
        }
        if (stack.isEmpty || stack.last != '(') throw FormatException('Mismatched parentheses');
        stack.removeLast();
        if (stack.isNotEmpty && _functions.contains(stack.last)) {
          output.add(stack.removeLast());
        }
      }
    }

    while (stack.isNotEmpty) {
      if (stack.last == '(' || stack.last == ')') throw FormatException('Mismatched parentheses');
      output.add(stack.removeLast());
    }
    return output;
  }

  static double _evalRpn(List<String> rpn, {required bool degMode}) {
    final stack = <double>[];

    for (final token in rpn) {
      final parsed = double.tryParse(token);
      if (parsed != null) {
        stack.add(parsed);
        continue;
      }
      if (token == 'pi') {
        stack.add(math.pi);
        continue;
      }
      if (token == 'e') {
        stack.add(math.e);
        continue;
      }
      if (_functions.contains(token) || token == 'u-' || token == '!') {
        if (stack.isEmpty) throw FormatException('Missing operand');
        final a = stack.removeLast();
        switch (token) {
          case 'u-':
            stack.add(-a);
            break;
          case 'sin':
            stack.add(math.sin(degMode ? a * math.pi / 180 : a));
            break;
          case 'cos':
            stack.add(math.cos(degMode ? a * math.pi / 180 : a));
            break;
          case 'tan':
            stack.add(math.tan(degMode ? a * math.pi / 180 : a));
            break;
          case 'log':
            if (a <= 0) throw FormatException('log domain');
            stack.add(math.log(a) / math.ln10);
            break;
          case 'ln':
            if (a <= 0) throw FormatException('ln domain');
            stack.add(math.log(a));
            break;
          case 'sqrt':
            if (a < 0) throw FormatException('sqrt domain');
            stack.add(math.sqrt(a));
            break;
          case 'cbrt':
            stack.add(a < 0 ? -math.pow(-a, 1 / 3).toDouble() : math.pow(a, 1 / 3).toDouble());
            break;
          case '!':
            if (a < 0 || a % 1 != 0 || a > 170) throw FormatException('factorial domain');
            double f = 1;
            for (int i = 2; i <= a.toInt(); i++) {
              f *= i;
            }
            stack.add(f);
            break;
        }
        continue;
      }
      if (_operators.contains(token)) {
        if (stack.length < 2) throw FormatException('Missing operands');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            if (b == 0) throw FormatException('Divide by zero');
            stack.add(a / b);
            break;
          case '^':
            final v = math.pow(a, b).toDouble();
            if (!v.isFinite) throw FormatException('Overflow');
            stack.add(v);
            break;
          case '%':
          case 'mod':
            if (b == 0) throw FormatException('Divide by zero');
            stack.add(a % b);
            break;
        }
        continue;
      }
      throw FormatException('Unknown token');
    }

    if (stack.length != 1) throw FormatException('Invalid expression');
    final out = stack.single;
    if (!out.isFinite) throw FormatException('Overflow');
    return out;
  }
}
DART

cd /content/calculator_app
flutter pub get
flutter build apk --release
APK_PATH="/content/calculator_app/build/app/outputs/flutter-apk/app-release.apk"
echo "APK built at: $APK_PATH"

python3 - <<'PY'
from google.colab import files
files.download('/content/calculator_app/build/app/outputs/flutter-apk/app-release.apk')
PY
