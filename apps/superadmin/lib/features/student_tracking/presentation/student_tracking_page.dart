import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/student_tracking.dart';
import 'student_tracking_view_model.dart';

enum StudentTrackingTab { overview, attendance, assessments, competencies, reportCards }

final class StudentTrackingPage extends StatefulWidget {
  const StudentTrackingPage({
    required this.repository,
    required this.logout,
    this.onDestinationSelected,
    super.key,
  });
  final StudentTrackingRepository repository;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<StudentTrackingPage> createState() => _StudentTrackingPageState();
}

final class _StudentTrackingPageState extends State<StudentTrackingPage> {
  late StudentTrackingViewModel _viewModel;
  StudentTrackingTab _tab = StudentTrackingTab.overview;
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel(widget.repository);
    _scheduleLoad(_viewModel);
  }

  @override
  void didUpdateWidget(covariant StudentTrackingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    _viewModel.dispose();
    _viewModel = _createViewModel(widget.repository);
    _tab = StudentTrackingTab.overview;
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selectedDate = now;
    _scheduleLoad(_viewModel);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  StudentTrackingViewModel _createViewModel(StudentTrackingRepository repository) =>
      StudentTrackingViewModel(repository);

  void _scheduleLoad(StudentTrackingViewModel viewModel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_viewModel, viewModel)) return;
      viewModel.load();
    });
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Acompanhamento',
    subtitle: 'Visão da família por aluno, contexto e período.',
    currentDestination: 'students',
    onDestinationSelected: widget.onDestinationSelected,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) => ListView(
            key: const Key('student-tracking-scroll'),
            padding: EdgeInsets.all(inset),
            children: [_body(context, constraints.maxWidth)],
          ),
        );
      },
    ),
  );

  Widget _body(BuildContext context, double width) {
    final state = _viewModel.state;
    if (state is StudentTrackingInitial || state is StudentTrackingLoading) {
      return const _StudentTrackingSkeleton();
    }
    if (state is StudentTrackingNoChildren) {
      return const CoeloStatePanel(
        title: 'Nenhum filho vinculado',
        message: 'Não há crianças disponíveis para este acesso.',
        icon: Icons.family_restroom_outlined,
      );
    }
    if (state is StudentTrackingNoContext) {
      return const CoeloStatePanel(
        title: 'Sem contexto disponível',
        message: 'A criança não possui Escola, Ballet ou outra atividade autorizada.',
        icon: Icons.layers_clear_outlined,
      );
    }
    if (state is StudentTrackingUnavailable) {
      return const CoeloStatePanel(
        key: Key('student-tracking-unavailable'),
        title: 'Acompanhamento indisponível',
        message: 'Os dados de acompanhamento não estão disponíveis neste ambiente.',
        icon: Icons.cloud_off_outlined,
      );
    }
    if (state is StudentTrackingOffline) {
      return CoeloStatePanel(
        title: 'Conexão indisponível',
        message: 'Verifique a internet e tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _viewModel.retry,
      );
    }
    if (state is StudentTrackingDenied) {
      return CoeloStatePanel(
        title: 'Acesso negado',
        message: 'Sua conta não possui a capacidade necessária.',
        icon: Icons.lock_outline,
        actionLabel: 'Tentar novamente',
        onAction: _viewModel.retry,
      );
    }
    if (state is StudentTrackingRevoked) {
      return CoeloStatePanel(
        title: 'Vínculo revogado',
        message: 'O acesso foi encerrado durante esta sessão e os dados locais foram limpos.',
        icon: Icons.person_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _viewModel.retry,
      );
    }
    if (state is StudentTrackingFailure) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar',
        message: 'Tente novamente. Se o erro persistir, contate o suporte.',
        icon: Icons.error_outline,
        actionLabel: 'Tentar novamente',
        onAction: _viewModel.retry,
      );
    }
    final snapshot = _viewModel.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final contextHasData =
        snapshot.assessments.isNotEmpty ||
        snapshot.categoryScores.isNotEmpty ||
        snapshot.development.isNotEmpty ||
        snapshot.attendance.total > 0 ||
        snapshot.agenda.isNotEmpty ||
        snapshot.reportCard != null ||
        snapshot.recommendation != null ||
        snapshot.pendingNotices > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Selectors(viewModel: _viewModel),
        const SizedBox(height: CoeloSpacing.space4),
        SuperadminUnderlineTabs<StudentTrackingTab>(
          key: const Key('student-tracking-tabs'),
          selected: _tab,
          tabs: const [
            SuperadminUnderlineTab(value: StudentTrackingTab.overview, label: 'Visão geral'),
            SuperadminUnderlineTab(value: StudentTrackingTab.attendance, label: 'Assiduidade'),
            SuperadminUnderlineTab(value: StudentTrackingTab.assessments, label: 'Avaliações'),
            SuperadminUnderlineTab(value: StudentTrackingTab.competencies, label: 'Competências'),
            SuperadminUnderlineTab(value: StudentTrackingTab.reportCards, label: 'Boletins'),
          ],
          onSelected: (value) => setState(() => _tab = value),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (!contextHasData)
          const CoeloStatePanel(
            key: Key('student-tracking-no-data'),
            title: 'Nenhum dado publicado',
            message:
                'Este contexto ainda não possui informações visíveis para o período selecionado.',
            icon: Icons.inbox_outlined,
          )
        else
          switch (_tab) {
            StudentTrackingTab.overview => _overview(snapshot, width),
            StudentTrackingTab.attendance => _AttendanceSection(snapshot: snapshot),
            StudentTrackingTab.assessments => _AssessmentsSection(snapshot: snapshot),
            StudentTrackingTab.competencies => _CompetenciesSection(snapshot: snapshot),
            StudentTrackingTab.reportCards => _ReportCardsSection(snapshot: snapshot),
          },
      ],
    );
  }

  Widget _overview(StudentTrackingSnapshot snapshot, double width) {
    final competence = snapshot.categoryScores.isEmpty
        ? 0
        : snapshot.categoryScores.map((e) => e.normalized).reduce((a, b) => a + b) /
              snapshot.categoryScores.length;
    final assessment = snapshot.assessments.isEmpty
        ? 0
        : snapshot.assessments.map((e) => e.normalized).reduce((a, b) => a + b) /
              snapshot.assessments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveCardGrid(
          cards: [
            _MetricCard(
              label: 'Assiduidade',
              value: '${snapshot.attendance.percentage.toStringAsFixed(0)}%',
              icon: Icons.fact_check_outlined,
              onPressed: () => setState(() => _tab = StudentTrackingTab.attendance),
            ),
            _MetricCard(
              label: 'Avaliações',
              value: snapshot.assessments.isEmpty
                  ? 'Sem dados'
                  : '${(assessment * 10).toStringAsFixed(1)}/10',
              icon: Icons.school_outlined,
              onPressed: () => setState(() => _tab = StudentTrackingTab.assessments),
            ),
            _MetricCard(
              label: 'Competências',
              value: snapshot.categoryScores.isEmpty
                  ? 'Sem dados'
                  : '${(competence * 5).toStringAsFixed(1)}/5',
              icon: Icons.psychology_outlined,
              onPressed: () => setState(() => _tab = StudentTrackingTab.competencies),
            ),
            _MetricCard(
              label: 'Agenda',
              value: '${snapshot.agenda.length} itens',
              icon: Icons.calendar_month_outlined,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space6),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final calendar = _Surface(
              title: 'Agenda geral',
              child: snapshot.agenda.isEmpty
                  ? const _InlineEmpty(
                      icon: Icons.event_busy_outlined,
                      text: 'Nenhum compromisso neste período.',
                    )
                  : CoeloCalendarMonth(
                      displayedMonth: _displayedMonth,
                      selectedDate: _selectedDate,
                      events: snapshot.agenda
                          .map(
                            (event) => CoeloCalendarEventMarker(
                              id: event.id,
                              date: event.startsAt,
                              semanticLabel: event.title,
                            ),
                          )
                          .toList(growable: false),
                      onDateSelected: (date) => setState(() => _selectedDate = date),
                      onPreviousMonth: () => setState(
                        () => _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month - 1,
                        ),
                      ),
                      onNextMonth: () => setState(
                        () => _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month + 1,
                        ),
                      ),
                      compact: !wide,
                    ),
            );
            final side = Column(
              children: [
                _DevelopmentCard(
                  snapshot: snapshot,
                  kind: StudentDevelopmentKind.participation,
                  title: 'Participação',
                  icon: Icons.waving_hand_outlined,
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _DevelopmentCard(
                  snapshot: snapshot,
                  kind: StudentDevelopmentKind.behavior,
                  title: 'Comportamento',
                  icon: Icons.sentiment_satisfied_alt_outlined,
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: calendar),
                      const SizedBox(width: CoeloSpacing.space4),
                      Expanded(child: side),
                    ],
                  )
                : Column(
                    children: [
                      calendar,
                      const SizedBox(height: CoeloSpacing.space4),
                      side,
                    ],
                  );
          },
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _Surface(
          title: 'Recomendação da professora',
          child: Text(
            snapshot.recommendation?.text ?? 'Nenhuma recomendação publicada para este período.',
          ),
        ),
      ],
    );
  }
}

final class _Selectors extends StatelessWidget {
  const _Selectors({required this.viewModel});
  final StudentTrackingViewModel viewModel;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final child = viewModel.selectedChild;
      final activity = viewModel.selectedContext;
      final period = viewModel.selectedPeriod;
      final fields = <Widget>[
        if (child != null)
          CoeloAdminSingleSelectField<StudentTrackingChild>(
            key: const Key('student-child-selector'),
            label: 'Aluno',
            value: child,
            options: viewModel.children,
            optionLabel: (item) => item.name,
            onChanged: viewModel.selectChild,
            prefixIcon: Icons.child_care_outlined,
            searchable: true,
          ),
        if (activity != null)
          CoeloAdminSingleSelectField<StudentTrackingContext>(
            key: const Key('student-context-selector'),
            label: 'Contexto',
            value: activity,
            options: viewModel.snapshot?.contexts ?? const [],
            optionLabel: (item) => item.name,
            onChanged: viewModel.selectContext,
            prefixIcon: Icons.layers_outlined,
          ),
        if (period != null)
          CoeloAdminSingleSelectField<StudentTrackingPeriod>(
            key: const Key('student-period-selector'),
            label: 'Período',
            value: period,
            options: viewModel.snapshot?.periods ?? const [],
            optionLabel: (item) => item.label,
            onChanged: viewModel.selectPeriod,
            prefixIcon: Icons.date_range_outlined,
          ),
      ];
      if (constraints.maxWidth < 700) {
        return Column(
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              fields[i],
              if (i < fields.length - 1) const SizedBox(height: CoeloSpacing.space3),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            Expanded(child: fields[i]),
            if (i < fields.length - 1) const SizedBox(width: CoeloSpacing.space3),
          ],
        ],
      );
    },
  );
}

final class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({required this.cards});
  final List<Widget> cards;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 1100
          ? 4
          : c.maxWidth >= 600
          ? 2
          : 1;
      final gap = CoeloSpacing.space4;
      final itemWidth = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards
            .map((card) => SizedBox(width: itemWidth, child: card))
            .toList(growable: false),
      );
    },
  );
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, this.onPressed});
  final String label, value;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    onPressed: onPressed,
    semanticLabel: '$label: $value',
    minHeight: 128,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _Surface extends StatelessWidget {
  const _Surface({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    ),
  );
}

final class _DevelopmentCard extends StatelessWidget {
  const _DevelopmentCard({
    required this.snapshot,
    required this.kind,
    required this.title,
    required this.icon,
  });
  final StudentTrackingSnapshot snapshot;
  final StudentDevelopmentKind kind;
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final values = snapshot.development.where((item) => item.kind == kind).toList();
    final score = values.isEmpty
        ? null
        : values.map((e) => e.normalized).reduce((a, b) => a + b) / values.length;
    return _Surface(
      title: title,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Text(
              score == null ? 'Ainda não publicado' : '${(score * 100).toStringAsFixed(0)}%',
            ),
          ),
        ],
      ),
    );
  }
}

final class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.snapshot});
  final StudentTrackingSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final a = snapshot.attendance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveCardGrid(
          cards: [
            _MetricCard(
              label: 'Presença',
              value: '${a.percentage.toStringAsFixed(1)}%',
              icon: Icons.check_circle_outline,
            ),
            _MetricCard(label: 'Presenças', value: '${a.present}', icon: Icons.done_all_outlined),
            _MetricCard(
              label: 'Faltas justificadas',
              value: '${a.justifiedAbsences}',
              icon: Icons.assignment_turned_in_outlined,
            ),
            _MetricCard(
              label: 'Faltas não justificadas',
              value: '${a.unjustifiedAbsences}',
              icon: Icons.event_busy_outlined,
            ),
            _MetricCard(label: 'Atrasos', value: '${a.late}', icon: Icons.schedule_outlined),
          ],
        ),
      ],
    );
  }
}

final class _AssessmentsSection extends StatelessWidget {
  const _AssessmentsSection({required this.snapshot});
  final StudentTrackingSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    if (snapshot.assessments.isEmpty) {
      return const _InlineEmpty(
        icon: Icons.school_outlined,
        text: 'Nenhuma avaliação publicada para este período.',
      );
    }
    return _ResponsiveCardGrid(
      cards: snapshot.assessments
          .map(
            (item) => _Surface(
              title: item.title,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (item.observation case final note?) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(note),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

final class _CompetenciesSection extends StatelessWidget {
  const _CompetenciesSection({required this.snapshot});
  final StudentTrackingSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    if (snapshot.categoryScores.isEmpty) {
      return const _InlineEmpty(
        icon: Icons.psychology_outlined,
        text: 'Nenhuma competência publicada para este período.',
      );
    }
    return _Surface(
      title: 'Competências',
      child: LayoutBuilder(
        builder: (context, c) {
          final radar = Semantics(
            label: snapshot.categoryScores
                .map((s) => '${s.name}: ${(s.normalized * 5).toStringAsFixed(1)} de 5')
                .join(', '),
            child: ExcludeSemantics(
              child: SizedBox(
                key: const Key('student-tracking-competency-radar'),
                height: 260,
                child: CustomPaint(
                  painter: _RadarPainter(snapshot.categoryScores, Theme.of(context).colorScheme),
                ),
              ),
            ),
          );
          final list = Column(
            children: [
              for (var index = 0; index < snapshot.competencies.length; index++) ...[
                _CompetencyRow(item: snapshot.competencies[index]),
                if (index < snapshot.competencies.length - 1)
                  Divider(color: Theme.of(context).colorScheme.outlineVariant),
              ],
            ],
          );
          return c.maxWidth >= 720
              ? Row(
                  children: [
                    Expanded(child: radar),
                    const SizedBox(width: CoeloSpacing.space6),
                    Expanded(child: list),
                  ],
                )
              : Column(
                  children: [
                    radar,
                    const SizedBox(height: CoeloSpacing.space4),
                    list,
                  ],
                );
        },
      ),
    );
  }
}

class _CompetencyRow extends StatelessWidget {
  const _CompetencyRow({required this.item});
  final StudentTrackingCompetency item;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${item.name}, ${item.category}, ${(item.normalized * 5).toStringAsFixed(1)} de 5',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(item.category, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Text(
              '${(item.normalized * 5).toStringAsFixed(1)}/5',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

final class _ReportCardsSection extends StatelessWidget {
  const _ReportCardsSection({required this.snapshot});
  final StudentTrackingSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final report = snapshot.reportCard;
    if (report == null) {
      return const _InlineEmpty(
        icon: Icons.description_outlined,
        text: 'O boletim ainda não foi publicado.',
      );
    }
    return _Surface(
      title: report.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.summary ?? 'Boletim publicado.'),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Publicado em ${report.publishedAt.day.toString().padLeft(2, '0')}/${report.publishedAt.month.toString().padLeft(2, '0')}/${report.publishedAt.year}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space6),
    child: Column(
      children: [
        Icon(icon, size: CoeloSize.iconLg, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: CoeloSpacing.space2),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

final class _StudentTrackingSkeleton extends StatelessWidget {
  const _StudentTrackingSkeleton();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: 'Carregando acompanhamento',
      child: Column(
        children: [
          for (final height in [56.0, 48.0, 128.0, 320.0]) ...[
            Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space4),
          ],
        ],
      ),
    );
  }
}

final class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values, this.colors);
  final List<StudentTrackingCategoryScore> values;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .38;
    final grid = Paint()
      ..color = colors.outlineVariant
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = colors.primary.withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final factor in [.33, .66, 1.0]) {
      final path = _path(center, radius * factor, values.length, null);
      canvas.drawPath(path, grid);
    }
    final scorePath = _path(
      center,
      radius,
      values.length,
      values.map((e) => e.normalized).toList(growable: false),
    );
    canvas.drawPath(scorePath, fill);
    canvas.drawPath(scorePath, stroke);
  }

  Path _path(Offset center, double radius, int count, List<double>? factors) {
    final path = Path();
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / count);
      final factor = factors?[i] ?? 1;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius * factor;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
