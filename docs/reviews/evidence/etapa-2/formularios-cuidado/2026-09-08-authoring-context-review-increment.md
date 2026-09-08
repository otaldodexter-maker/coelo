---
title: "F-AUTHOR02 — incremento da revisão central"
source: "Revisão central de 7ec3d476; testes locais; revisão independente estática"
status: "client-local-verified-sql-not-executed-e2e-open"
generated_at: "2026-09-08"
---

# Recorte e resultado

Correção delimitada aos callbacks retidos do catálogo institucional e às
asserções iniciais de ACL da fixture 02. Não altera migration, contrato RPC,
composição produtiva, publicação, distribuição ou recursos remotos.

Callbacks de seleção, busca e próxima página capturam API, geração de contexto,
geração de consulta e página. Só atuam enquanto essas referências continuam
atuais, sem carregamento, comando pendente ou formulário já confirmado.
Seleção também exige que o item pertença à página capturada.

Dois testes RED reproduziram seleção antiga após troca de API ou página.
Após a correção, ambos passam e os controles de seleção atual seguem operantes.
UI nominal: **14/14**. Regressão conjunta de nove suítes Forms: **204/204**, exit 0.
Analyzer dos dois arquivos Dart e validator visual canônico: sem achados.
Revisão independente estática dos callbacks e do header SQL: sem bloqueantes.

# Fixture e pins

As quatro verificações iniciais de ACL usam `to_regprocedure(...)::oid` e
`coalesce(..., false)`. Função ausente faz inclusive as negativas falharem;
não é confundida com ausência correta de privilégio. Evita erro de resolução
textual nessas verificações, mas não garante continuidade dos RPCs posteriores
sem migration. Nenhuma execução RED/GREEN SQL é alegada.

Fixture `superadmin_forms_authoring_institution_context_v2_test.sql`: novo Git
blob `53f37358bd6ffd53fb69755ffd35b787b57c8a9a`, substituindo somente o pin da
fixture da evidência anterior. Migration 02 permanece
`309e2f2dae95a8dcf1eaf6b3a2dcf346c016bf0b`; migration 01 permanece
`3c6fcfe072a38a35f79dad22c482c3ccc22794ad`.

# Limites e memória

SQL/Docker não executados. Total TAP será conhecido no replay do Eng1;
concorrência em duas conexões, integração nominal e E2E permanecem abertos.
Trackers/ledger e integração são do Coordenador. A revisão e TDD orientaram
negativos com callback efetivamente retido, não apenas inspeção de botão atual.
Nenhuma regra durável nova: nenhuma projeção de conhecimento por atividade.
