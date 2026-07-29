import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'superadmin_chat_avatar.dart';
import 'superadmin_chat_surface_primitives.dart';

final class SuperadminChatContextPanel extends StatefulWidget {
  const SuperadminChatContextPanel({
    required this.conversation,
    required this.onClose,
    this.compact = false,
    super.key,
  });

  final SuperadminChatConversation conversation;
  final VoidCallback onClose;
  final bool compact;

  @override
  State<SuperadminChatContextPanel> createState() => _SuperadminChatContextPanelState();
}

final class _SuperadminChatContextPanelState extends State<SuperadminChatContextPanel> {
  var _roleIndex = 0;

  @override
  void didUpdateWidget(covariant SuperadminChatContextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) _roleIndex = 0;
  }

  SuperadminChatConversation get conversation => widget.conversation;

  SuperadminChatRoleView? get _roleView =>
      conversation.roleViews.isEmpty ? null : conversation.roleViews[_roleIndex];

  List<SuperadminChatMetric> get _metrics => _roleView?.metrics ?? conversation.metrics;

  List<String> get _children => _roleView?.children ?? conversation.children;

  String get _context => _roleView?.context ?? conversation.context;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Material(
      key: const Key('superadmin-chat-context-panel'),
      color: colors.surface,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _panelTitle(conversation.kind),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SuperadminChatCloseButton(tooltip: 'Fechar contexto', onPressed: widget.onClose),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Center(
              child: SuperadminChatAvatar(
                label: conversation.title,
                initials: conversation.initials,
                size: CoeloSize.touchMin + CoeloSpacing.space4,
                online: conversation.kind == ChatContextKind.person,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              conversation.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            if (_context.isNotEmpty && _context != conversation.location)
              Text(
                _context,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            if (conversation.location != null && conversation.location!.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                conversation.location!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            if (conversation.typeLabel != null || conversation.planLabel != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: CoeloSpacing.space3,
                runSpacing: CoeloSpacing.space1,
                children: [
                  if (conversation.typeLabel != null)
                    _ContextMetadata(
                      key: const Key('superadmin-chat-context-type'),
                      label: 'Tipo',
                      value: conversation.typeLabel!,
                    ),
                  if (conversation.planLabel != null)
                    _ContextMetadata(
                      key: const Key('superadmin-chat-context-plan'),
                      label: 'Plano',
                      value: conversation.planLabel!,
                    ),
                ],
              ),
            ],
            if (conversation.roleViews.length > 1) ...[
              const SizedBox(height: CoeloSpacing.space3),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var index = 0; index < conversation.roleViews.length; index++)
                    ButtonSegment(value: index, label: Text(conversation.roleViews[index].label)),
                ],
                selected: {_roleIndex},
                onSelectionChanged: (value) => setState(() => _roleIndex = value.first),
              ),
            ],
            if (_children.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text('Crianças', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Wrap(
                spacing: CoeloSpacing.space2,
                children: [
                  for (final child in _children)
                    Chip(
                      avatar: const Icon(Icons.child_care_outlined, size: 16),
                      label: Text(child),
                    ),
                ],
              ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: textScale > 1.5 ? 1 : 2,
                mainAxisSpacing: CoeloSpacing.space2,
                crossAxisSpacing: CoeloSpacing.space2,
                mainAxisExtent: textScale > 1.5
                    ? CoeloSize.touchMin * 4
                    : CoeloSize.touchMin * 2 + CoeloSpacing.space4,
              ),
              itemBuilder: (context, index) => _MetricCard(metric: _metrics[index]),
            ),
            if (conversation.members.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Text('Membros e origens', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space2),
              for (final member in conversation.members)
                ListTile(
                  minTileHeight: CoeloSize.touchMin,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(_initials(member.name))),
                  title: Text(member.name),
                  subtitle: Text('${member.role} · ${member.institution}\n${member.origin}'),
                ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            Text('Compartilhados', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space2),
            const _SharedItem(
              icon: Icons.image_outlined,
              title: 'Fotos',
              subtitle: '8 arquivos simulados',
            ),
            const _SharedItem(
              icon: Icons.description_outlined,
              title: 'Documentos',
              subtitle: '3 arquivos simulados',
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: CoeloSize.iconSm,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: CoeloSpacing.space2),
                const Expanded(child: Text('Demonstração local')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _ContextMetadata extends StatelessWidget {
  const _ContextMetadata({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final SuperadminChatMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('superadmin-chat-context-metric'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _metricIcon(metric.label),
              key: const Key('superadmin-chat-context-metric-icon'),
              size: CoeloSize.iconSm,
              color: colors.primary,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              '${metric.value}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              metric.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

final class _SharedItem extends StatelessWidget {
  const _SharedItem({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: CoeloSize.touchMin,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

String _panelTitle(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'Instituição',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo/Turma',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};

IconData _metricIcon(String label) {
  final normalized = label.toLowerCase();
  if (normalized.startsWith('institui')) return Icons.account_balance_outlined;
  if (normalized.startsWith('unidade')) return Icons.apartment_outlined;
  if (normalized.startsWith('grupo')) return Icons.groups_outlined;
  if (normalized.startsWith('atividade')) return Icons.event_note_outlined;
  if (normalized.startsWith('funcion')) return Icons.badge_outlined;
  if (normalized.startsWith('respons')) return Icons.family_restroom_outlined;
  if (normalized.startsWith('aluno')) return Icons.school_outlined;
  if (normalized.startsWith('particip')) return Icons.people_outline_rounded;
  return Icons.insights_outlined;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
