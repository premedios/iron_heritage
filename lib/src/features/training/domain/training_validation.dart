import 'training_models.dart';

abstract final class TrainingValidation {
  static String normalizeName(String value) => value.trim().toLowerCase();

  static Map<String, String> template(WorkoutTemplateDraft draft) {
    final errors = <String, String>{};
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Enter a Template name';
    }
    if (draft.prescriptions.isEmpty) {
      errors['prescriptions'] = 'Add at least one exercise';
    }
    for (var index = 0; index < draft.prescriptions.length; index++) {
      if (draft.prescriptions[index].plannedSets.isEmpty) {
        errors['prescriptions.$index.plannedSets'] = 'Add at least one set';
      }
    }
    return errors;
  }

  static Map<String, String> routine(RoutineDraft draft) {
    final errors = <String, String>{};
    if (draft.name.trim().isEmpty) {
      errors['name'] = 'Enter a Routine name';
    }
    if (draft.templates.isEmpty) {
      errors['templates'] = 'Add at least one Template';
    }
    final names = <String>{};
    for (var index = 0; index < draft.templates.length; index++) {
      final normalized = normalizeName(draft.templates[index].name);
      if (!names.add(normalized)) {
        errors['templates.$index.name'] =
            'Template names must be unique inside this Routine';
      }
    }
    return errors;
  }
}
