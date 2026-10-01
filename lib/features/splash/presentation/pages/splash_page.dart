import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget { const SplashPage({super.key});
@override State<SplashPage> createState()=>_SplashPageState(); }
class _SplashPageState extends State<SplashPage>{
@override void initState(){super.initState(); Future.delayed(const Duration(seconds:1),(){if(mounted) context.go('/login');});}
@override Widget build(BuildContext c)=>const Scaffold(body:Center(child:Text('International Institute of RAD')));
}
