---
title: "E2E5 — A01 corretiva nominal de auditoria de leitura"
source: "RED55 Eng1 a01-directory-audit-red-2026-09-07.md; spec039; review activities_sql_review"
status: "candidato local audit-v2; GREEN serial pendente"
generated_at: "2026-09-07"
---

# RED comprovado e autorização

Eng1 executou em 2026-09-08T02:18:38Z o perfil A01DirectoryAuditRed, base54 +
corretiva v1 2fd8227 =55 arquivos, alvo20260907222911. **97 TAP emitidos,
91 PASS/6 FAIL**, sem erro ACL/aborto. Os89 originais e90/95 authenticated
passaram; falharam91–94 auditoria/correlação/counts e96–97 propagação de falha.
Os readers v1 não chamavam append; por isso o trigger de falha não era acionado,
e não porque algum append executado tivesse sido engolido. Cleanup independente
às02:22:12Z zerou containers/volumes/redes/staging próprios.

Coordenador autorizou audit-v2 após esse RED, sem nova autorização administrativa
para autoria local. Somente Eng1 executa replay serial. Root não acessa Docker
nem banco remoto.

## Delta nominal

Mesmo arquivo `20260907222911_superadmin_activity_directory_v2_client_contract.sql`,
ainda não implantado:28 inserções/6 remoções contra v1, somente saídas dos readers.
Leitura/validação ficam no bloco interno com catch; negativa agora condicionada
a erro. Sucesso chama overload14args de `audit_append_superadmin_internal` **fora
do catch**, com ator interno real, sessão, capability, AAL e escopo do contexto.
Nenhum helper compartilhado foi alterado.

- `activity.directory`: after_json exatamente `{row_count: tamanho da página}`.
- `activity.filter_options`: soma das três coleções de opções; sem payload/filtro.
- Object ID/type nulos para coleção; instituição derivada exclusivamente do
  contexto institucional autorizado, nunca de filtro/primeira linha.
- Mesmo UUID do append em `data.correlation_id`; return somente após append.
- Falha de auditoria propaga e aborta a chamada sem envelope nem dados.
- Predicados, projeção, deny-helper, owner, grants e fixture97 preservados.

## Snapshots fechados para novo replay

| Artefato | Bytes LF | SHA-256 LF | SHA-256 CRLF |
| --- | --- | --- | --- |
| Corretiva audit-v2 | 13376 | `e4b02a2100030c36a0895d04036685cafae623326872f3141902d00043fe66f2` | `e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f` |
| Fixture97 inalterada | 38905 | `fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1` | `f028b86a065f7ea50c1447a62a2b0131ec8cc9119f117c5947355979b1c9648f` |

Review independente estático: sem blocker para handoff; conferiu assinatura,
escopo, contagem, correlação e ausência de catch externo. AdapterFlutter:
**37/37 PASS** reexecutados. Diff check limpo. Não houve execução SQL pelo root;
97/97 GREEN não foi comprovado neste documento. Próximo gate: replay nominal
Eng1 com mesma fixture97 e snapshot novo. Sem deploy ou promoção E2E de Atividades.

Gate de memória no-op: implementação de auditoria já exigida pela spec039, sem
nova regra de produto. Rastreadores centrais sob writer Coordenador.
