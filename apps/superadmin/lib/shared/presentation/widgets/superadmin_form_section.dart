import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Cabeçalho de etapa/seção de formulário no padrão administrativo
/// (o de Criar instituição): título `headlineSmall` e descrição `bodyMedium`,
/// sem card em volta. A seção é a página, não um objeto dentro dela.
final class SuperadminFormSectionHeader extends StatelessWidget {
  const SuperadminFormSectionHeader({super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space1),
        Text(description, style: textTheme.bodyMedium),
      ],
    );
  }
}

/// [SuperadminFormSectionHeader] seguido do conteúdo da seção.
final class SuperadminFormSection extends StatelessWidget {
  const SuperadminFormSection({
    super.key,
    required this.title,
    required this.description,
    this.child,
    this.children = const [],
  }) : assert(child == null || children.length == 0, 'Use child ou children, não os dois.');

  final String title;
  final String description;
  final Widget? child;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey(title),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SuperadminFormSectionHeader(title: title, description: description),
      const SizedBox(height: CoeloSpacing.space5),
      ?child,
      ...children,
    ],
  );
}
