import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

class LoginCard extends StatelessWidget {
  const LoginCard({required this.isCompact, required this.child, super.key});

  final bool isCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: CoeloElevation.level1,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? CoeloSpacing.space6 : CoeloSpacing.space8),
        child: child,
      ),
    );
  }
}
