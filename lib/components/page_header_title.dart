import 'package:flutter/material.dart';

class PageHeaderTitle extends StatelessWidget {
  const PageHeaderTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Muli',
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    );
  }
}
