import 'package:flutter/material.dart';

class ParentHomepage extends StatefulWidget {
  const ParentHomepage({super.key});

  @override
  State<ParentHomepage> createState() => _ParentHomepageState();
}

class _ParentHomepageState extends State<ParentHomepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Parent HomeScreen"),
        backgroundColor: Colors.amberAccent,
      ),
      
    );
  }
}