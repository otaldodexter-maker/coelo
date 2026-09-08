---
title: "CHILD-READ01 — candidato SQL mínimo preparado"
source: "contrato a9a5974; vetor f84d0631; reserva de implementação da coordenação em 2026-09-08; fontes Auth039/envelope/AAL; revisões Mencius e Nash"
status: "candidate-statically-reviewed-not-sql-executed-not-e2e"
generated_at: "2026-09-08"
---

# Entrega e limite da prova

Candidato `20260908051500_superadmin_child_context_directory_v2.sql` preparado
com um único gateway, sem helpers novos, grants de negócio, auditoria14,
superfície E5 ou alteração046/Locais. EXECUTE nominal do gateway somente para
authenticated; os helpers herdados permanecem privados.

O vetor é Auth45 + dois preflights + envelope20260827235500 (48 entradas antes
do alvo); com candidato, 49 entradas planejadas. Isso é proposta de composição,
não perfil executável novo nem resultado de replay. Harness e execução SQL
continuam exclusivos do Eng1 sob gate da coordenação.

## Preflight físico

Cinco helpers herdados são fixados por assinatura, tipo de retorno/set,
linguagem, volatilidade, SECURITY DEFINER, owner postgres, configuração exata
search_path vazio e ACL privada, incluindo privilégios efetivos dos três roles.
Corpos são fixados por MD5 de prosrc normalizado somente CRLF para LF; o script
local recalcula a partir da função canônica entre delimitadores $$, sem executar
SQL, sem trim e sem depender do pretty-printer de pg_get_functiondef.

| Helper | Fonte canônica | MD5 prosrc LF |
| --- | --- | --- |
| require_superadmin_internal_context | 20260901200206 | 5cdb28081d40e15232ef50912edd8082 |
| superadmin_internal_error_envelope | 20260827235500 | bfce7b85b8d5d43e93e5d3fba3a66dc8 |
| audit_superadmin_internal_denial_if_identified | 20260901124500 | d218f9e256e2dca89ed92cf7b702cc13 |
| audit_append_superadmin_internal (13) | 20260827233000 | 950412c5312aae7361164a95f35dfa43 |
| audit_append_auth_session_denial | 20260827233000 | 072e47ff682be44ca3fce7b0d80ea4a4 |

Esses pins são extração de fonte, ainda não comparação com catálogo vivo.
Nenhum fingerprint de Locais foi alterado. Divergência deve parar o pacote,
com assinatura nominal no detalhe do preflight, nunca atualizar hash por palpite.

Também conferidos no candidato: tipo composto039 de13 campos; colunas/tipos/
nullability das três tabelas de projeção; owner/RLS; PKs; FKs criança/instituição;
unique pessoa/instituição; capability people.read ativa e matriz allow Owner;
ausência de qualquer overload do gateway nos schemas público/privado.
Não impor requires_mfa como AAL2: corpo vigente20260901200206 é a autoridade.

## Comportamento implementado, ainda não provado em runtime

Owner interno, escopo platform/institution, filtro só restritivo; autorizar
antes de validar cursor ou consultar crianças. Locks compartilhados em usuário,
sessão, auth-link, membership, role, capability e grant; contexto039 revalidado
após locks e antes da auditoria. Projeção somente cc.active, people.child sem
exclusão, instituição sem exclusão, sem necessidade de alocação em unidade.

CTE materializada limita a limit+1 linhas bloqueadas de cc/pessoa/instituição;
reordena os valores efetivamente obtidos após esperas, por lower/C/UUID.
Cinco campos exatamente, cursor do último retornado, sem total. Cursor >8192
bytes falha seguro; nome longo existente não recebe limite cadastral novo.
Caracteres seguem DTO existente: C0 e DEL recusados, sem ampliar para C1 nem
sanitizar nomes silenciosamente. UUIDs/cursor nunca conferem autorização.

Audit13 de sucesso fora do capturador de erros: sem payload/nomes/cursor,
people.read/child_context.directory, correlação e instituição autorizada;
objeto child_context_catalog sem object_id infantil fabricado.
Negativa usa instituição NULL e somente sessão válida por relógio real.
Conferência clock_timestamp antes e depois do append cobre expiração durante
espera em recursos ou auditoria; falha após append aborta retorno e auditoria.

Repetir039 sozinho seria insuficiente para expiração natural, pois usa now()
transacional. Esse P1 foi identificado por Nash e corrigido. O teste de audit
failure foi refinado para exigir SQLSTATE P0001 e mensagem sintética exata;
qualquer exceção genérica já não pode fazê-lo passar. Mencius identificou a
divergência C1 com o DTO; candidato e teste foram alinhados ao contrato existente.

## Verificação obtida

- Guard fonte: RED observado `child candidate missing` antes da migration.
- Contraprova estática de sessão: RED `wall clock session guard` antes da correção.
- Guard final: 15 contratos + superfície única/revalidação + cinco pins PASS.
- 35 assertions pgTAP comportamentais **preparadas, não executadas**: paginação,
  empate/cursor, escopo cruzado, parâmetros, Owner/non-Owner, repetição da pessoa,
  ausência de alocação, contexto inativo/pessoa excluída/instituição excluída,
  revogação, auditoria mínima, no-session, wall-clock expiry, orçamento de cursor,
  nome longo sem novo teto e falha exata do trigger de auditoria.
- Catálogo14 original f84 preservado, sem alteração.
- Duas revisões independentes somente leitura; correções acima rechecadas.
- Dois gates de memória PASS; sem novo conhecimento aprovado de produto para
  gerar projeção. Esta é evidência técnica candidata, não documentação de uso.

Não executados: parser PostgreSQL, migrations, TAP, concorrência em duas sessões,
SQL local/remoto, Docker, HTTP, DI/router/UI. Guards de texto não substituem esses
resultados. Não há local-green SQL, E2E ou autorização para deploy.

## Próximo gate

Eng1: reservar perfil nominal e comparar os pins contra o catálogo isolado,
executar o catálogo RED antes do alvo e depois candidato +35 assertions.
Exigir prova adicional de concorrência (revogação/rename/relocação enquanto
bloqueado, expiração durante append, READ COMMITTED/REPEATABLE READ).
EvalPlanQual, identidade/cleanup e ausência de resíduos precisam de prova real.
Só depois reservar transporte/wiring com a coordenação. A entrega desta fatia
não encerra o diretório completo, nem Estruturas/Pessoas/Locais ponta a ponta.
