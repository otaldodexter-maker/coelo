---
title: "Cardápios — contrato local de seleção institucional na rota"
source: "b0c250fc; meal_plan_wizard_page.dart; migrations 20260820150500 e 20260820160000; autorização nominal do Coordenador em 2026-09-08"
status: "cliente local-green; backend interno e E2E abertos"
generated_at: "2026-09-08"
---

O teste antigo exigia a tela `meal-plan-authorized-tenant-unavailable` quando
nenhum tenant vinha do router. Esse guard foi removido explicitamente em
`b0c250fc`, junto ao fluxo de seleção por opções do repository. A falha anterior
está registrada em `2026-09-08-operational-route-harness.md`: quatro falhas em
57 testes, três corrigidas em `6e380e3`, esta preservada até diagnóstico e
aprovação nominal. Não foi restaurado guard nem alterado código produtivo.

O wizard carrega opções de audiência e modelos. Para modelos, `_persist` exige
instituição selecionada antes de chamar `saveTemplate`; o passo inicial permite
avançar sem essa escolha, mas o salvamento é bloqueado. A instituição escolhida
é enviada como `institutionId` e `tenantId`, sem depender do parâmetro global
opcional do router.

O SQL legado de `meal_plan_audience_options` exige `meal_plans.read` e filtra
instituições por `meal_plan_scope_allowed`. `meal_plan_template_save` exige
`auth.uid()`, `current_person_id()`, `meal_plans.manage`, escopo solicitado e,
na edição, escopo do recurso existente, versão e tenant imutável. O helper de
escopo consulta `platform_memberships` People com status/revogação, role ativa
e escopo plataforma/instituição. Isso é leitura estática de código legado,
**não prova de autorização do ator interno039**, aplicação ou segurança remota.

## Verificação

O teste obsoleto agora verifica a composição sem tenant pré-selecionado. Quatro
testes adicionais usam rota normal, sessão de teste, adapter Supabase real e
HTTP totalmente simulado em `meal-plans.invalid`:

- Sem selecionar instituição: tentativa de salvar mostra validação e zero RPC
  de save.
- Seleção A pelo widget: o adapter envia A como tenant/instituição; resposta
  simulada403 mostra negação, mantém a rota e não indica sucesso.
- Opções negadas: erro de acesso visível e zero save após tentativa.
- Opções indisponíveis: erro de transporte visível e zero save após tentativa.

O mock só fornece A. A ausência de B na UI **não comprova isolamento A/B**.
Não há servidor, persistência, login real, R2 ou E2E nesta evidência.

Na preparação do harness, faltavam metadata HTTP da resposta e a criação do
cliente em `tester.runAsync`; isso causou erro de fixture e espera de isolate.
Foram corrigidos apenas os testes, com auto-refresh desabilitado e disposição
também em `runAsync`. Esses erros não são REDs de produto.

Regressão: o conjunto anterior de 12 arquivos mais o novo arquivo, **13 arquivos,
61 testes PASS, exit0**, sem atualização de golden. Seleção reproduzível em
`apps/superadmin`:

```powershell
$taskTests = @(rg --files test/app -g '*test.dart' | Where-Object { $_ -match 'activity_routes|attendance|daily_routine|assessment|plans|meal_plan|support|audit|catalog_routes|error_routes' })
rtk proxy flutter test --no-pub @taskTests
```

Analyzer dos dois arquivos: PASS após explicitar o tipo da lista vazia no mock;
rerun final dos quatro controles: 4 PASS. A contagem é sobreposta aos 61, não
deve ser somada como casos adicionais.

Review independente `agenda_ui_contract`: sem blocker; ressalva de que o mock
não comprova isolamento. Nenhum arquivo de produção, router, SQL ou tracker
central alterado. O Coordenador recebe este pacote para atualizar a pendência;
o backend People legado e a integração039 permanecem abertos. Nenhum novo
conhecimento de produto aprovado foi criado; não há projeção de memória nova.
