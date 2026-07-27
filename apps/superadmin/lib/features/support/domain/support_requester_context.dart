final class SupportRequesterContext {
  const SupportRequesterContext({this.institution, this.unit, this.group, this.activity});

  final String? institution;
  final String? unit;
  final String? group;
  final String? activity;

  List<String> get labels => List.unmodifiable([
    if (institution case final value?) value,
    if (unit case final value?) value,
    if (group case final value?) value,
    if (activity case final value?) value,
  ]);

  String get breadcrumb => labels.join(' > ');
}
