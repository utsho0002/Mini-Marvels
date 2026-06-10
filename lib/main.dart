import 'package:flutter/material.dart';

import 'package:project_1/user_authentication/role_screen.dart';
import 'package:project_1/user_authentication/splash_screen_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ptrhkseofzxeilzlmjmq.supabase.co',
    anonKey: 'sb_publishable_EZCYdcxr11uMr2JmXuoxGw_w-5ksNGt',
  );

  runApp(MaterialApp(
    title: "Mini Marvels",
    debugShowCheckedModeBanner: false,
    home:SplashScreenPage(),
  ));
}

// It's handy to then extract the Supabase client in a variable for later uses
final supabase = Supabase.instance.client;

