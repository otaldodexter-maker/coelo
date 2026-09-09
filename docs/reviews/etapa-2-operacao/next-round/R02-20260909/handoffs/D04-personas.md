---
source: "Delegação operacional D04 em 2026-09-09; AGENTS.md; ADR0019; specs018/019/039/046; helpers de personas R01; contratos dos filhos Modelos e Safety"
status: "qualification-plan; no-accounts-created; no-remote-execution"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# R02 D04 — pacote mínimo de qualificação de personas, r1

Preparado por `/root/invites` na worktree D04. É um plano operacional para as
seis telas atribuídas; não aprova papel, capability, conta ou regra de produto.
Aliases abaixo são rótulos de cenário, sem IDs, e-mails, senhas ou dados reais.
Nenhum helper foi executado para criar atores, enviar convites ou mutar remoto.

## Reuso e preflight

Reutilizar o fluxo já existente em `packages/coelo_database/scripts/`:
`e2-r01-auth-personas.ts`, `e2-r01-auth-personas-private.ts`,
`e2-r01-auth-personas-local-sql.ts`, `e2-r01-auth-personas-ban-proof.ts`,
`e2-r01-auth-personas-secrets.ts` e seus testes correspondentes. O manifesto
`docs/reviews/etapa-2-operacao/reports/personas-cenarios.json` é histórico e
declara explicitamente que atores não foram provisionados.

O helper R01 fixa namespace/pacote R01, cria apenas cinco personas não Owner e
nega papéis Owner. Sua negativa `no-cap` é específica a `institution.update`;
ela não prova ausência de `platform.invites.manage`, permissões de Modelos ou
Usuários internos. Não chamar esse helper como se já produzisse a matriz R02.
Primeiro D04/D01/D00 reconciliam o snapshot real ou local e a matriz efetiva por
capability, incluindo grants ativos, deny, revogação e escopo. Se não houver
ator apto, registrar qual alias falta, sem criar role/grant ou vincular People.

Antes de qualquer prova integrada: sessão Auth válida de D01, identidade/link e
membership internos correspondentes, AAL1 vigente, role/capability ativa e
escopo persistido. Sessão criada no SQL fixture não prova login real. Não usar
metadados mutáveis como autoridade e não associar a identidade interna a People
para fazer o legado funcionar. Remote continua produção e exige pacote nominal
autorizado, execução serial e cleanup; este documento não fornece autorização.

## Aliases internos e contextuais

| Alias | Qualificação necessária | Uso |
| --- | --- | --- |
| R02-D04-OWNER | Interno ativo, Owner, platform/null, sessão AAL1 válida; ator já qualificado, nunca criado pelo helper R01 | Positivo Convites/Modelos/detalhe Pessoa v2; demais conforme contrato |
| R02-D04-OP-A / OP-B | Internos não Owner com membership de instituição A/B e catálogo efetivo registrado | Acesso de escopo permitido onde o wrapper admite; negativos obrigatórios em Convites e Modelos Owner-only |
| R02-D04-NO-CAP | Interno ativo com ausência/deny comprovado da capability exata do caso | Negativa por capability, sem confundir com o no-cap R01 de institution.update |
| R02-D04-REVOKED | Alias isolado para variantes sessão, auth-link e membership revogadas/suspensas; uma causa por caso | Comando, releitura e limpeza da UI após revogação |
| R02-D04-GLOBAL | Pessoa global sem identidade/link/membership internos | Negar wrappers internos; não converter em interno para passar |
| R02-D04-ANON | Sem sessão autenticada | Negar sem payload sensível ou oracle de recurso |
| SQL-SAFETY-READ / SQL-SAFETY-MANAGE | Fixtures de Pessoa/plataforma do teste SQL legado, separadas de OWNER interno | Leitura e criação/administração conforme child_safety.*; não provam composição Superadmin interno |
| SQL-SAFETY-UNIT-A / UNIT-B | Fixtures contextuais com authorized_people.manage na unidade exata | Decisão/suspensão permitida no próprio escopo; negar cruzamento |
| SQL-SAFETY-GUARDIAN / OTHER | Fixtures de guardião com manage_authorized_people no contexto da criança | Pedido e edição de própria pendente; negar pedido alheio e decisão/suspensão indevidas |

OP-A/B não são automaticamente positivos em toda tela. OWNER pode alcançar A e
B quando o contrato é platform-only; nesse caso A→B não é uma negativa válida.
Testar cruzamento não autorizado com ator restrito ou adulteração da hierarquia
do recurso, sem inventar uma regra de tenant para Owner global.

## Matriz concreta por tela

| Tela / IDs | Capability e caminho | Casos locais/integrados a qualificar | Gate atual |
| --- | --- | --- | --- |
| Pessoas / people.list, create, edit, links | Detalhe superadmin_person_detail_v2 usa people.read e Owner interno platform; diretório, opções e writes conservam contratos legados conforme spec046 | OWNER lê detalhe mínimo e recarrega; GLOBAL/OP-A/B/NO-CAP/REVOKED negados no v2; ID existente/desconhecido sem oracle; lista/filtros e writes só após cutover próprio | P0 do diretório/write legado; não habilitar com vínculo People nem promover detalhe à listagem |
| Perfis e permissões / access-profiles.* | Spec018: leitura platform.read; writes platform.roles.manage ou institution.roles.manage conforme domínio | Catálogo por domínio/escopo, perfil sem uso global, tentativa de definição/atribuição em instituição alheia; deny antes de lookup; alteração/revogação seguida de reload | ACL invoker→helper 42501 e decisão de catálogo global para ator institucional; não herdar aceite de Modelos |
| Modelos / access-models.* | access_profile_require_model_action exige interno Owner platform + `<domain>.role_models.<read/create/update/delete>`; AAL1 | OWNER em platform/institution/principal; filtros scalar/CSV; principal child_context; NO-CAP/OP-A/B/GLOBAL/REVOKED negados; versão/replay; catálogo após reload | Prova SQL/FE D04 e integração do filtro; modelo não é vínculo direto de Pessoa |
| Convites / invites.list/create/detail/resend/revoke | platform.invites.read para lista/detalhe; platform.invites.manage para opções/emissão/reenvio/revogação; wrappers Owner platform/null | OWNER: emissão por pessoa/e-mail, hierarquia perfil/contexto correta, token único; resend após expiração, versão/replay; revoke pending e impedir uso posterior; OP-A/B/GLOBAL/NO-CAP/REVOKED negados; alvo/unit/group adulterados e audit/reload | Sem envio/SMTP real autorizado; detalhe normal omite allowCommands, correção com D00; não tratar fila como entrega |
| Segurança da criança / child-safety.* | child_safety.read/manage no caminho plataforma legado; authorized_people.manage em contexto/unidade; guardião manage_authorized_people em pedido próprio | Fixtures separadas: ler minimizado; pedir, editar própria pendente; gestor unidade decide; trocar child/context/unit/person ou version falha; responsável não suspende; replay consistente e reload | Gate de cutover interno confirmado por leitura local: assert_child_safety_platform chama current_person_id de person_auth_links, e has_platform_permission usa platform_memberships.person_id. Create pede UUID manual e falta lookup adulto minimizado. AAL2 histórico não é requisito novo aprovado |
| Usuários internos / internal-users.* | platform.member.read/update/suspend; require_superadmin_internal_context e target_allowed | OWNER/ator efetivamente autorizado lê mínimo; escopo A não acessa alvo B; e-mail/data/IDs sensíveis minimizados; status desconhecido nega parsing; update/version/replay; suspend/revoke e último Owner protegido; reload | Descoberta normal pendente; rota edit abre read-only atualmente. Criar/envio não é autorizado por existir repository de update |

No envio/reenvio de Convites, separar persistência, outbox, confirmação do
provedor e token. Teste com double pode verificar UI; só envio nominal
autorizado permite provar entrega real. URLs únicas e secrets nunca vão para
este artefato ou log compartilhado.

## Fontes executáveis já existentes

Usar os testes `packages/coelo_database/supabase/tests/` pertinentes, sem criar
projeto ou harness paralelo:

- `superadmin_internal_auth_context_test.sql` e testes `e2-r01-auth-personas*_test.ts`:
  preflight, vínculo privado, recibos, limpeza e limites do helper.
- `superadmin_people_directory_test.sql`; spec046 e repository de Pessoa:
  distinguir legado de detalhe interno antes de escolher positivos.
- `access_profiles_internal_read_contract_test.sql`,
  `profiles_permissions_governance_test.sql`: Perfis/catálogo/autoridade.
- `access_profile_models_read_authorization_test.sql`,
  `access_profile_models_read_prelookup_regression_test.sql`,
  `access_profile_models_aal1_phase_policy_test.sql` e novo
  `d04_access_models_scope_filter_test.sql` do filho de Modelos.
- `superadmin_internal_invites_v2_test.sql` e testes Flutter
  `test/features/invites/{data,invite_form_context_test.dart,invite_detail_page_test.dart}`.
- `child_safety_production_test.sql` e `test/features/safety/**`: fixture global/
  contextual existente não certifica o ator interno na composição normal.
- `superadmin_internal_users_directory_test.sql`,
  `superadmin_internal_users_read_minimization_test.sql` e testes Flutter
  `test/features/platform_users/**`.

Os nomes de arquivo acima são fontes, não resultados reexecutados. Histórico
SQL verde, quantidade de asserts e teste com fake não provam personas reais.

## Sequência de execução e recibo

1. D01 entrega sessão/actor qualificados sem revelar segredo; D04 confere
   alias→realm→capability→scope por tela usando snapshot minimizado e datado.
2. D04 fecha os gates de implementação identificados; D00 integra os SHAs e
   materializa a base conjunta antes da prova de composição.
3. No slot local serial, reutilizar replay/testes existentes e preencher por
   cenário alias, action_id, base, ambiente, permitido/negado, reload/audit e
   P/F/B/S/U. Não executar cenário de runtime normal que ainda não existe.
4. Somente pacote remoto nominal autorizado segue a ator real/entrega/cleanup.
   Registrar recibo minimizado sem tokens, dados pessoais ou payload bruto.

Estado deste plano: zero testes de personas executados; cenário completo não
atomizado, cobertura ainda não calculável. Gates impedem certificação E2E;
planejar aliases não qualifica ninguém. Knowledge no-op: nenhuma regra durável
foi criada. Este arquivo é handoff operacional próprio para D04/D00.
