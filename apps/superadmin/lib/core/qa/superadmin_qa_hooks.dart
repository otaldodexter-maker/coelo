import '../../features/circulars/presentation/production_circular_hosts.dart';

/// Ganchos de QA da sessao de teste em producao (ADR 0034, Decisao 10).
///
/// Ficam nulos no app real: o ponto de entrada `test_driver/qa_main.dart` e o
/// unico que os preenche, para provar pela rota normal o que o navegador
/// dirigido por CDP nao alcanca (o seletor nativo de arquivos, por exemplo).
/// Nenhum segredo, nenhuma autorizacao: o servidor continua validando tudo.
abstract final class SuperadminQaHooks {
  /// Substitui o `FilePicker` nativo do compositor de Circulares.
  static CircularAttachmentPicker? circularFilePicker;
}
