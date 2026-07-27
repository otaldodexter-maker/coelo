final class SupportRequesterContext {
  const SupportRequesterContext({this.institution, this.unit, this.group, this.activity});

  final String? institution;
  final String? unit;
  final String? group;
  final String? activity;

  List<String> get labels => List.unmodifiable([?institution, ?unit, ?group, ?activity]);

  String get breadcrumb => labels.join(' > ');
}
