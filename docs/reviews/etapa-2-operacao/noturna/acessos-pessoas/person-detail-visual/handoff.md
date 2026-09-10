---
source: "NOTURNA-catalogo-falhas.md; d019c109a; person_detail_golden_test.dart"
status: "local-green; sem certificacao produtiva"
generated_at: "2026-09-09"
---

# Detalhe de Pessoa: referencia nominal do menu

Base conjunta materializada: 6aa352c6a434086905444aaa5f128034ad8352e6. Recorte: apps/superadmin -> Acessos -> Pessoas -> detalhe/contexto/recarregar -> people.links e people.reload. O arquivo monta PersonDetailPage com leitor sintetico, nao o router produtivo.

RED: 1P/1F. Os seis estados em 375 claro passaram; nao foram repetidos. Os seis estados em 1440 escuro apresentaram exatamente 4801 pixels (0,37%) de diferenca cada. Causa nominal: d019c109aeb7c85688cbee64eadf32079507a516 removeu developmentOnly de Usuarios internos no menu; e ancestral da base conjunta. A nova entrada desloca os itens inferiores na navegacao. Conteudo do detalhe, contexto, foco, loading, negacao e indisponibilidade permanecem visualmente iguais. Nao e deriva de fonte ou atualizacao generica do SDK.

Os seis pares foram inspecionados individualmente ANTES da substituicao, preservados em before/ e after/. manifest.json lista cada caminho e SHA256. Somente goldens/person_detail_dark_1440_{identity,context,focus,loading,denied,unavailable}.png foram substituidos pelos renders inspecionados. Nenhum Dart alterado.

GREEN focal: somente teste 1440, 1P/0F, exit0. Resultado unico do arquivo: **2P/0F**, aproveitando o 375 verde anterior. Doze comparacoes visuais nao sao doze testes. Permanecem as assercoes de contexto infantil, Enter para recarregar, retirada dos dados durante loading e estados negado/indisponivel. Nenhum dado real ou chamada remota.

O gate visual historico foi resolvido; contratos, persistencia e composicao produtiva continuam no residual. Sem promocao FE/BE/E2E e sem conhecimento de produto novo a registrar. Runner 24299 encerrado. Proximo passo: publicar os seis PNGs e provas e integrar pelo coordenador.
