import 'package:flutter/material.dart';

class ChildHomepage extends StatefulWidget {
  const ChildHomepage({super.key});

  @override
  State<ChildHomepage> createState() => _ChildHomepageState();
}

class _ChildHomepageState extends State<ChildHomepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Child homepage"),),
    );
  }
}