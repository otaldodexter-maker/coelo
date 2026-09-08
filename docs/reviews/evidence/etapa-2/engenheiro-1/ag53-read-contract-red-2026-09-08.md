---
source:
  - "Gate central do snapshot 6cd030f4f99df502a9771338cf082a52c773cbcd"
  - "Execução local serializada de AgendaReadContractRed em 2026-09-08"
  - "Fixture de contrato a3b76f5b26fc2f787311e87f1b38132516c31c5d"
status: red_funcional_com_base_e_catalogo_validados
generated_at: "2026-09-08"
---

O replay **AgendaReadContractRed/53** aplicou integralmente a base nominal até **20260901200206**. O catálogo Auth/audit passou **10/10** verificações. A fixture de contrato íntegra executou **114 TAP: 21 PASS e 93 FAIL**, sem aborto. Total dos dois arquivos: **124 TAP, 31 PASS e 93 FAIL**, exit 1.

Os primeiros três testes falham porque os leitores públicos `superadmin_agenda_list_v2`, `superadmin_agenda_get_v2` e `superadmin_agenda_contexts_v2` estão ausentes nessa base. As falhas seguintes abrangem envelopes, paginação, escopo, DTO, capabilities, ACL e auditoria dependentes desses leitores. Os 93 testes reprovados não representam 93 defeitos independentes. A fixture capturou as chamadas sem abortar; o transcript não expôs o SQLSTATE interno dessas capturas, portanto esta evidência não atribui a elas um código observado que não foi impresso.

Índices reprovados no contrato: **1–3, 18–25, 27–45, 47–59, 61–110**. Índices aprovados: **4–17, 26, 46, 60, 111–114**. O relatório pg_prove registrou Wstat 0, 114 testes e 93 falhas; o runner global retornou 1 pelo resultado TAP.

O catálogo real confirmou PostgreSQL **170006**, usuário postgres, enum `auth.aal_level` com aal1/aal2/aal3 e coluna de sessão desse tipo. A função interna de auditoria possui 14 argumentos, retorno uuid, owner postgres, SECURITY DEFINER, VOLATILE e search_path vazio. Os papéis anon, authenticated e service_role não têm EXECUTE; a verificação independente de PUBLIC também passou. A captura estruturada está em [ag53-auth-audit-catalog-2026-09-08.json](ag53-auth-audit-catalog-2026-09-08.json).

Assinatura verificada:

~~~text
app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)
~~~

| Evidência operacional | Valor |
|---|---|
| Início UTC | 2026-09-08T04:45:35.4483244Z |
| Identidade | coelo_safe_197315fecd564407b970281638db7 |
| Criação UTC | 2026-09-08T04:45:36.5578520Z |
| Marker | .coelo-safe-replay lido; corresponde à identidade |
| Base preparada | 51 canônicas + 2 preflights = 53 |
| Aplicação | CLI percorreu as 53 entradas e concluiu db reset |
| Testes | Catálogo 10 PASS; contrato 21 PASS / 93 FAIL |
| Saída | pg_prove/CLI/wrapper 1; sessão 77225 encerrada |
| Cleanup independente UTC | 2026-09-08T04:48:47.4374645Z |
| Recursos próprios restantes | 0 containers, 0 volumes, 0 redes; staging ausente |
| Staging histórico alheio | coelo_safe_af5bdf571cff41309f5b6845b713a preservado |

A aplicação integral é sustentada pelo transcript do CLI. Não houve consulta independente do ledger antes da limpeza; não se apresenta essa captura como realizada.

Foram executados somente os dois TestPaths autorizados:

- `agenda_read_auth_audit_catalog_test.sql`: SHA UTF-8/CRLF **256208ee4cba4af4425fa4f57fd8725c5d9e2b6db05923f842ce495812b9ddec**, plan 10.
- `superadmin_agenda_read_v2_contract_test.sql`: blob **e8ea4a9322dfa94c6a75e0e65756639fc79f9569**, SHA UTF-8/CRLF **b7f7eb396b62d84998cef75e000475f82e4d766cb1ffe9e15c6e6b12b463bcad**, plan 114.

Descriptor **ba5e2b94e3f245bdeb634d86c7f4db2f39b23a6831e0bfbd7a7511031b8c0385**, resolver **dd2d76099fffb393df040ea910981908e0a65e149964a311df7af1a36864bf15**. Os arquivos pertencem ao pacote revisado 6cd030f4, com preparação Pester 488/488 PASS; nenhum helper alternativo, grant adicional ou reparo foi introduzido durante o replay.

A frente E2E5 recebeu a evidência para preparar os leitores e sua corretiva nominal. O recorte é SQL local de contrato e catálogo; não representa E2E Flutter, comandos de Agenda, implantação remota ou conclusão da tela. Não houve mudança de regra de produto nem conhecimento durável novo a projetar: o resultado permanece nesta fonte canônica de evidência.
