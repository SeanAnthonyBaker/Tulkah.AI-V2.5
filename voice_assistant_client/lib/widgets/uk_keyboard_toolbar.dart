import 'package:flutter/material.dart';

class UKKeyboardToolbar extends StatelessWidget {
  final TextEditingController controller;

  const UKKeyboardToolbar({
    Key? key,
    required this.controller,
  }) : super(key: key);

  static const List<String> ukSymbols = [
    "\"", "@", "£", "€", "%", "&", "#", "£/hr", "VAT", "SLA", "Kaizen", "DPO", "KPI", "ROI"
  ];

  void _insertSymbol(String symbol) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, symbol);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ukSymbols.length,
        itemBuilder: (context, index) {
          final symbol = ukSymbols[index];
          final isSpecialChar = symbol == "\"" || symbol == "@" || symbol == "£" || symbol == "€";
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _insertSymbol(symbol),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSpecialChar
                          ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                          : [const Color(0xFF334155), const Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSpecialChar
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF475569),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSpecialChar
                            ? const Color(0xFF6366F1).withOpacity(0.3)
                            : Colors.black26,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

