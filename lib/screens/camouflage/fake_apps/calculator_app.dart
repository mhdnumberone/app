// lib/screens/camouflage/fake_apps/calculator_app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/managers/settings_manager.dart';
import '../../auth/login_screen.dart';

class CalculatorApp extends StatefulWidget {
  const CalculatorApp({super.key});

  @override
  State<CalculatorApp> createState() => _CalculatorAppState();
}

class _CalculatorAppState extends State<CalculatorApp> {
  String _display = '0';
  String _operation = '';
  double _num1 = 0;
  double _num2 = 0;
  bool _shouldResetDisplay = false;
  List<String> _secretSequence = [];
  
  // Secret sequence to access real app
  final List<String> _correctSequence = ['=', '=', '=', '7', '5', '5', '2', '1', '='];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'الآلة الحاسبة',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _showCalculatorMenu(),
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Display
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_operation.isNotEmpty)
                    Text(
                      _operation,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _display,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ),
          
          // Buttons
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildButtonRow(['C', '±', '%', '÷']),
                  _buildButtonRow(['7', '8', '9', '×']),
                  _buildButtonRow(['4', '5', '6', '-']),
                  _buildButtonRow(['1', '2', '3', '+']),
                  _buildButtonRow(['0', '.', '='], lastRow: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonRow(List<String> buttons, {bool lastRow = false}) {
    return Expanded(
      child: Row(
        children: buttons.map((button) {
          if (lastRow && button == '0') {
            return Expanded(
              flex: 2,
              child: _buildButton(button),
            );
          }
          return Expanded(
            child: _buildButton(button),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String text) {
    Color buttonColor = Colors.grey[900]!;
    Color textColor = Colors.white;

    // Operator buttons
    if (['+', '-', '×', '÷', '='].contains(text)) {
      buttonColor = Colors.orange;
    }
    // Function buttons
    else if (['C', '±', '%'].contains(text)) {
      buttonColor = Colors.grey[600]!;
      textColor = Colors.black;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      child: Material(
        color: buttonColor,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          onLongPress: text == '=' ? () => _accessRealApp() : null,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            height: double.infinity,
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onButtonPressed(String button) {
    HapticFeedback.lightImpact();
    
    // Check secret sequence
    _secretSequence.add(button);
    if (_secretSequence.length > _correctSequence.length) {
      _secretSequence.removeAt(0);
    }
    
    if (_secretSequence.length == _correctSequence.length &&
        _secretSequence.toString() == _correctSequence.toString()) {
      _accessRealApp();
      return;
    }

    setState(() {
      switch (button) {
        case 'C':
          _clear();
          break;
        case '±':
          _toggleSign();
          break;
        case '%':
          _percentage();
          break;
        case '+':
        case '-':
        case '×':
        case '÷':
          _setOperation(button);
          break;
        case '=':
          _calculate();
          break;
        case '.':
          _addDecimal();
          break;
        default:
          _addDigit(button);
      }
    });
  }

  void _clear() {
    _display = '0';
    _operation = '';
    _num1 = 0;
    _num2 = 0;
    _shouldResetDisplay = false;
    _secretSequence.clear();
  }

  void _toggleSign() {
    if (_display != '0') {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
    }
  }

  void _percentage() {
    double value = double.tryParse(_display) ?? 0;
    _display = (value / 100).toString();
    _shouldResetDisplay = true;
  }

  void _setOperation(String op) {
    _num1 = double.tryParse(_display) ?? 0;
    _operation = '$_display $op';
    _shouldResetDisplay = true;
  }

  void _calculate() {
    if (_operation.isEmpty) return;
    
    _num2 = double.tryParse(_display) ?? 0;
    double result = 0;
    
    String operator = _operation.split(' ').last;
    
    switch (operator) {
      case '+':
        result = _num1 + _num2;
        break;
      case '-':
        result = _num1 - _num2;
        break;
      case '×':
        result = _num1 * _num2;
        break;
      case '÷':
        if (_num2 != 0) {
          result = _num1 / _num2;
        } else {
          _display = 'خطأ';
          _operation = '';
          return;
        }
        break;
    }
    
    _display = result % 1 == 0 ? result.toInt().toString() : result.toString();
    _operation = '';
    _shouldResetDisplay = true;
  }

  void _addDecimal() {
    if (_shouldResetDisplay) {
      _display = '0.';
      _shouldResetDisplay = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
  }

  void _addDigit(String digit) {
    if (_shouldResetDisplay || _display == '0') {
      _display = digit;
      _shouldResetDisplay = false;
    } else {
      _display += digit;
    }
  }

  void _showCalculatorMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text(
                'السجل',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showHistory();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.science, color: Colors.orange),
              title: const Text(
                'الوضع العلمي',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showScientificMode();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.orange),
              title: const Text(
                'حول',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAbout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'سجل العمليات',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'لا توجد عمليات سابقة',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'موافق',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showScientificMode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'الوضع العلمي',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'سيتم إضافة الوضع العلمي في التحديث القادم',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'موافق',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'حول الآلة الحاسبة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار: 2.1.0',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'آلة حاسبة بسيطة وسريعة للعمليات الأساسية',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'موافق',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _accessRealApp() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}