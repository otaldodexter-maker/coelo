import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

void showSuperadminNotice(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
}) {
  final host = _NoticeHostScope.maybeOf(context);
  if (host != null) {
    host.add(message, icon);
    return;
  }

  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      elevation: CoeloElevation.level2,
      backgroundColor: colors.surface,
      margin: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space4,
        vertical: CoeloSpacing.space2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space4,
        vertical: CoeloSpacing.space2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      content: _NoticeContent(message: message, icon: icon),
    ),
  );
}

class SuperadminNoticeHost extends StatefulWidget {
  const SuperadminNoticeHost({required this.child, super.key});

  final Widget child;

  @override
  State<SuperadminNoticeHost> createState() => _SuperadminNoticeHostState();
}

class _SuperadminNoticeHostState extends State<SuperadminNoticeHost> {
  final _notices = <_NoticeEntry>[];
  final _timers = <Timer>[];
  var _nextId = 0;

  void add(String message, IconData icon) {
    setState(() {
      if (_notices.length >= 3) {
        _notices.removeAt(0);
      }
      final entry = _NoticeEntry(id: _nextId++, message: message, icon: icon);
      _notices.add(entry);
      late final Timer timer;
      timer = Timer(const Duration(seconds: 6), () {
        _timers.remove(timer);
        if (mounted) {
          setState(() => _notices.removeWhere((notice) => notice.id == entry.id));
        }
      });
      _timers.add(timer);
    });
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NoticeHostScope(
      state: this,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: CoeloSpacing.space4,
            right: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: IgnorePointer(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final notice in _notices.reversed)
                        Padding(
                          key: ValueKey(notice.id),
                          padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                          child: _AnimatedNotice(entry: notice),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeHostScope extends InheritedWidget {
  const _NoticeHostScope({required this.state, required super.child});

  final _SuperadminNoticeHostState state;

  static _SuperadminNoticeHostState? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_NoticeHostScope>()?.state;
  }

  @override
  bool updateShouldNotify(covariant _NoticeHostScope oldWidget) => false;
}

class _NoticeEntry {
  const _NoticeEntry({required this.id, required this.message, required this.icon});

  final int id;
  final String message;
  final IconData icon;
}

class _AnimatedNotice extends StatelessWidget {
  const _AnimatedNotice({required this.entry});

  final _NoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: Material(
        elevation: CoeloElevation.level2,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: _NoticeContent(message: entry.message, icon: entry.icon),
        ),
      ),
    );
  }
}

class _NoticeContent extends StatelessWidget {
  const _NoticeContent({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      key: const Key('superadmin-transient-notice'),
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: CoeloSize.iconSm, color: colors.primary),
        ),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
