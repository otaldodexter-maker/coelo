import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SuperadminBrandMark extends StatelessWidget {
  const SuperadminBrandMark({this.size = CoeloSize.touchMin, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBackground =
        theme.extension<CoeloVisualColors>()?.brandMarkBackground ?? theme.colorScheme.primary;
    final asset = theme.brightness == Brightness.dark
        ? 'assets/brand/logo-coelo-orange.svg'
        : 'assets/brand/logo-coelo-white.svg';

    return Container(
      key: const Key('superadmin-brand-mark'),
      width: size,
      height: size,
      padding: const EdgeInsets.all(CoeloSpacing.space2),
      decoration: BoxDecoration(color: brandBackground, shape: BoxShape.circle),
      child: SvgPicture.asset(
        asset,
        key: const Key('superadmin-brand-logo'),
        semanticsLabel: 'Coelo',
      ),
    );
  }
}
