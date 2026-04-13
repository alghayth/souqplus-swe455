import 'package:flutter/material.dart';

// Holds the shared search state accessible from anywhere in the widget tree
class SearchState extends InheritedWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const SearchState({
    super.key,
    required this.controller,
    required this.onChanged,
    required super.child,
  });

  static SearchState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SearchState>();
  }

  @override
  bool updateShouldNotify(SearchState oldWidget) =>
      controller != oldWidget.controller;
}
