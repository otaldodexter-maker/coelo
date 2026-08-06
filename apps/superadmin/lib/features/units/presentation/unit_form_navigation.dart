import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'unit_form_controller.dart';

final class UnitFormNavigation extends StatelessWidget {
  const UnitFormNavigation({required this.controller, super.key});

  final UnitFormController controller;

  @override
  Widget build(BuildContext context) => SuperadminFormStepNavigation(
    steps: [
      for (final step in UnitFormStep.values)
        SuperadminFormStep(
          label: step.label,
          status: switch (controller.statusOf(step)) {
            UnitFormStepStatus.current => SuperadminFormStepStatus.current,
            UnitFormStepStatus.complete => SuperadminFormStepStatus.complete,
            UnitFormStepStatus.error => SuperadminFormStepStatus.error,
            UnitFormStepStatus.incomplete => SuperadminFormStepStatus.incomplete,
          },
        ),
    ],
    currentIndex: controller.currentStep.index,
    onStepSelected: (index) => controller.selectStep(UnitFormStep.values[index]),
  );
}
