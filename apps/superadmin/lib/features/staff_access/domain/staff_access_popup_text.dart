import 'staff_access.dart';

/// Texto do popup (também usado pelo Principal ao entrar num contexto bloqueado).
String staffAccessPopupPreview({
  required List<StaffAccessWindow> windows,
  DateTime? validFrom,
  DateTime? validUntil,
  required bool enabled,
}) {
  if (!enabled) return 'Este contexto não está disponível agora.';
  final parts = <String>[];
  if (windows.isNotEmpty) {
    final byDay = <int, List<StaffAccessWindow>>{};
    for (final w in windows) {
      byDay.putIfAbsent(w.weekday, () => []).add(w);
    }
    final days = byDay.keys.toList()..sort();
    parts.add(
      'Horário permitido: ${days.map((d) => '${StaffAccessWindow.weekdayShortLabels[d]} ${byDay[d]!.map((w) => '${w.start}–${w.end}').join(', ')}').join('; ')}.',
    );
  }
  if (validFrom != null || validUntil != null) {
    parts.add(
      'Vigência: ${validFrom == null ? 'até' : 'de ${staffAccessDateLabel(validFrom)}'}${validUntil == null ? '' : validFrom == null ? ' ${staffAccessDateLabel(validUntil)}' : ' até ${staffAccessDateLabel(validUntil)}'}.',
    );
  }
  if (parts.isEmpty) return 'Este contexto não está disponível agora.';
  return parts.join(' ');
}


/// Mensagem mostrada ao funcionário que tenta entrar num contexto bloqueado,
/// a partir do `access_popup` do servidor (null = popup desligado).
String staffAccessBlockedMessage(Map<String, dynamic>? popup) {
  if (popup == null) return 'Este contexto não está disponível agora.';
  DateTime? date(String key) {
    final value = popup[key];
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  if (popup['kind'] == 'leave') {
    final from = date('leave_from');
    final until = date('leave_until');
    if (from == null || until == null) return 'Você está afastado do app neste contexto.';
    return 'Você está afastado do app entre ${staffAccessDateLabel(from)} e ${staffAccessDateLabel(until)}.';
  }
  final windows = (popup['windows'] as List<dynamic>? ?? const [])
      .map((item) => StaffAccessWindow.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList(growable: false);
  return staffAccessPopupPreview(
    windows: windows,
    validFrom: date('valid_from'),
    validUntil: date('valid_until'),
    enabled: true,
  );
}
