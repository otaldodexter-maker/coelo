import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_form_step_navigation.dart' as shared;
import '../view_models/institution_form_controller.dart';

final class InstitutionFormNavigation extends StatelessWidget {
  const InstitutionFormNavigation({required this.controller, super.key});

  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) => shared.SuperadminFormStepNavigation(
    steps: [
      for (final step in InstitutionFormStep.values)
        shared.SuperadminFormStep(
          label: step.label,
          key: controller.statusOf(step) == InstitutionFormStepStatus.error
              ? Key('institution-step-${step.name}-error')
              : Key('institution-step-${step.name}'),
          status: switch (controller.statusOf(step)) {
            InstitutionFormStepStatus.current => shared.SuperadminFormStepStatus.current,
            InstitutionFormStepStatus.complete => shared.SuperadminFormStepStatus.complete,
            InstitutionFormStepStatus.error => shared.SuperadminFormStepStatus.error,
            InstitutionFormStepStatus.incomplete => shared.SuperadminFormStepStatus.incomplete,
          },
        ),
    ],
    currentIndex: controller.currentStep.index,
    onStepSelected: (index) => controller.selectStep(InstitutionFormStep.values[index]),
  );
}
