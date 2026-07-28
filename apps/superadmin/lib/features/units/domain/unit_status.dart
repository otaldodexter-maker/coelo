enum UnitStatus {
  draft('draft', 'Rascunho'),
  active('active', 'Ativa'),
  inactive('inactive', 'Inativa'),
  suspended('suspended', 'Suspensa'),
  archived('archived', 'Arquivada');

  const UnitStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}
