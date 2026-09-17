---
source: "Sessão A da R15 (Fable 5.1), 17/09/2026; R15-pendencias.md (ordem 1); ADR 0041 C2/C4; ADR 0042; owner.r12-20/21/22/24/25/26/27"
status: evidence
generated_at: 2026-09-17
---

# Perfis de acesso (`access-profiles.edit`, `access-profiles.assign`; owner.r12-20, 21, 22, 24, 25, 26, 27) — rota real, 17/09/2026

Ambiente: Supabase de produção (`evvbomzejfijozbtgvpt`); build `flutter build web --release -t
test_driver/qa_main.dart --dart-define-from-file=.env.local --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`
da worktree `r15/bloco-a` (código `57162cee4` para a edição; build com a correção de atribuição para
`access-profiles.assign`, `900608be9`), servido por `serve.py` em `127.0.0.1:3014`; Chrome CDP
`9414` (SwiftShader, perfil `%TEMP%\coelo-r15-a-chrome`, **tema claro**, viewport 1424×1125); sessão
`qa-r06-acessos@coelo.me` (Owner, escopo plataforma). Negativas e readback por
`packages/coelo_database/scripts/r13-rpc-proof.mjs` (PostgREST, mesma identidade, sem chave de serviço).
Capturas em `capturas/access-profiles-*.png`.

## Prova por action_id

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| access-profiles.edit | `/profiles` (00: 8 cards após carga completa) → card "R14 S5 Perfil QA" → detalhe `/profiles/platform/281699f2…` (01: Código, Status, Escopo, **Versão 1**, "Acessos › Modelos de perfil › Ver · Consultar modelos Admin.") → "Editar perfil" → passo "Perfil e escopo" (02) → nome renomeado para "R15 A Perfil QA renomeado" (03) → Continuar → "Permissões" (04: matriz do catálogo real, módulo Acessos, "Modelos de perfil · Admin/Superadmin", 2 de 18 após marcar "Excluir") → Continuar → "Pessoas vinculadas" (07: 0 vínculos) → Continuar → "Revisão" (08: "Permissões adicionadas: Acessos › Modelos de perfil › Inativar modelos Admin.", "Nome: de R14 S5 Perfil QA para R15 A Perfil QA renomeado", painel "Alteração sensível", Motivo obrigatório) → motivo → "Salvar alterações" → volta a `/profiles` com o card renomeado (09). | `superadmin_access_profile_save` (update, `p_expected_version 1`) → `platform_roles 281699f2…` **version 2**, `name "R15 A Perfil QA renomeado"`, 2 capacidades (`institution.role_models.read` + `institution.role_models.delete`), `audit[0].action permission_changed` 17/09 12:23 UTC, relido por `superadmin_access_profile_detail`. | Carga completa de `/profiles/platform/281699f2…` (10): título novo, **Versão 2**, "2 permissões" (Inativar modelos Admin · Modelos de perfil › Excluir; Consultar modelos Admin · › Ver), auditoria com duas entradas. | (a) versão defasada: `superadmin_access_profile_save` com `p_expected_version 1` sobre a v2 → **`409 PT409` `ACCESS_PROFILE_STALE_VERSION` "stale profile version"**, sem mutação (detalhe segue v2) — provado após o lote 75 (OQ-047) do Bloco B; antes do lote a mesma chamada respondia `504 upstream request timeout` (retry do PostgREST em 40001), também sem mutação. (b) instituição alheia: `p_draft.domain institution` com `institution_id …0099` → `400 22023 unknown or invalid capability` (sem criação). (c) `id` inexistente → `500 P0002` (S5 16/09, resíduo de mapeamento). |
| access-profiles.assign | ver seção "Atribuição" abaixo. | | | `superadmin_internal_user_update` com `p_internal_identity_id` inexistente → `403 SAI_PERMISSION_DENIED` (S5 16/09). |

## Owner items provados nesta fatia

- **owner.r12-20** (cards, quantidade arbitrária, reload): 8 cards após carga completa de `/profiles` em 1424×1125 (00) e após salvar (09); as três linhas cabem no viewport, sem rolagem. Negativa cross-tenant não se aplica (perfis Superadmin são de plataforma); a negativa aceita é a de versão defasada (409 PT409) + capacidade/instituição inválida (400 22023). Resíduo mantido: "Vínculos 0" conta `platform_memberships`.
- **owner.r12-21** (detalhe traduzido): detalhe real com módulo › tela › ação em português ("Acessos › Modelos de perfil › Ver", "Consultar modelos Admin.") antes (01) e após reload com 2 permissões (10). Resíduo: o rótulo de ação da matriz é "Excluir" enquanto o nome do catálogo é "Inativar modelos Admin." (catálogo BE); a auditoria mostra o motivo como `[redacted]` (o servidor mascara o campo `reason` no detalhe).
- **owner.r12-22** (sem campo Código; identificador do servidor): passo 1 da edição sem Código (02); código `r14-s5-perfil-qa-46749519` preservado após renomear (10). Edição pela rota normal com persistência e reload: fechado.
- **owner.r12-24** (tooltip por foco/toque): navegando por teclado (Tab a partir de "Buscar permissão"), a célula "Excluir" focada mostra "Ação sensível: altera ou remove dados e deixa trilha de auditoria no servidor." e "Criar"/"Importar" mostram "Ação de risco elevado: fica registrada na trilha de auditoria do servidor." (05). Resíduo visual novo: o tooltip aberto por foco **não fecha quando o foco avança** (em 05/06 ficam três tooltips empilhados; em 600 px eles cobrem o rodapé do passo) — corrigir em `_PermissionActionCell` (fechar no `onShowFocusHighlight(false)`).
- **owner.r12-25** (1440 e ~600 px): em 1424 de largura a matriz fica empilhada por tela (Modelos de perfil · Admin / · Superadmin), cabeçalho do módulo com "Selecionar módulo · 2 de 18" sem estouro (04); em 600×900 (`Emulation.setDeviceMetricsOverride`) o stepper vai para a esquerda, a matriz encolhe sem estouro horizontal e o rodapé empilha Continuar/Anterior (06). Persistência/reload em 09/10.
- **owner.r12-26** (Continuar laranja preenchido, tema claro, edição): passo 1 da edição com "Continuar" `FilledButton` laranja no tema claro (02); "Salvar alterações" fica desabilitado até o motivo ser preenchido e então preenche (08 → salvo).
- **owner.r12-27** (revisão módulo › tela › nome, motivo, configuração × acesso efetivo): revisão com "Acessos › Modelos de perfil › Inativar modelos Admin.", texto "Estas são as permissões configuradas no perfil. O acesso efetivo depende do vínculo, do contexto e da autorização do servidor em cada ação.", "0 vínculos impactados", "Nenhuma permissão selecionada tem indicação de MFA." e Motivo obrigatório (08); salvo sem perder a permissão anterior (10).

## Atribuição (`access-profiles.assign`)

| Passo | Rota normal | Produção | Reload | Negativa |
|---|---|---|---|---|
| Antes da correção | `/internal-users` → busca "R14BlocoC" → card "QA R14BlocoC" (Owner) → detalhe (11) → "Editar" → Continuar ×2 → "Acesso ao Superadmin" mostrava "Catálogo de instituições indisponível · O acesso existente será preservado" com Perfil/Alcance somente leitura (12). | — | — | — |
| Atribuir | Build com a correção (carga completa de `/internal-users/bf6008f0…/edit`) → passo "Acesso ao Superadmin" com dropdown "Perfil Superadmin" (Owner) e permissões derivadas (13) → dropdown lista Auditor, Content, Operations, Owner, R14 Perfil Operacoes QA, R15 A Perfil QA renomeado → "R15 A Perfil QA renomeado" selecionado, permissões derivadas `institution.role_models.delete/read` (14) → Continuar → Revisão "Perfil: R15 A Perfil QA renomeado · Alcance: Global à plataforma" (15) → "Salvar alterações" → detalhe. | `superadmin_internal_user_update` → identidade `bf6008f0…` **version 2**, `history` "Cadastro atualizado" 12:56 UTC; `superadmin_internal_user_detail.memberships[0].profile` = `281699f2…`; `superadmin_access_profile_detail(281699f2…).memberships` = 1 vínculo (`person_name "Operador interno bf6008f0"`, escopo Plataforma). | Carga completa de `/internal-users/bf6008f0…` (16, viewport 1424×2600): "Acesso ao Superadmin · Perfil R15 A Perfil QA renomeado · Alcance Global à plataforma", "Permissões derivadas" com as 2 capacidades "Derivada do perfil", histórico com "Cadastro atualizado 17/09 12:56". | — |
| Restaurar | Mesma rota: "Editar" → Continuar ×2 → dropdown → "Owner" (permissões derivadas completas) → Revisão "Perfil: Owner" (18) → "Salvar alterações". | identidade **version 4** (v3 foi um salvamento sem alteração do perfil quando o menu não fechou), `memberships[0].profile.code owner`; `superadmin_access_profile_detail(281699f2…).memberships` = `[]`. | Detalhe relido. | (a) versão defasada: `superadmin_internal_user_update` com `p_expected_version 3` sobre a v4 → `{ok:false, error:{code SAI_CONCURRENT_CHANGE, http_status 409, "O estado mudou. Recarregue e tente novamente."}}`, sem mutação (v4, Owner). (b) `p_internal_identity_id` inexistente → `{ok:false, error:{code SAI_PERMISSION_DENIED, http_status 403}}` (sem enumeração). (c) `p_draft.identity` incompleto → `SAI_INVALID_INPUT` 422 antes de qualquer checagem de versão. Envelope `ok:false` viaja com HTTP 200 (contrato SAI). |

Resíduos vistos na tela de Usuários internos: o chip flutuante "Mensagens" (chat interno, canto inferior direito) **cobre o botão "Continuar"** do rodapé do assistente em 1424×1125 (17) — a automação teve de clicar na borda visível; o detalhe em produção ainda usa títulos "Estados independentes"/"Histórico demonstrativo" e textos "nesta demonstração"/"convite demonstrativo" (16); a página de edição demora vários segundos em "Carregando o cadastro interno protegido" (duas RPCs sequenciais + catálogo).

## Observações

- Defeito de FE encontrado e corrigido nesta sessão (antes da prova de atribuição): em `/internal-users/:id/edit`
  o formulário só carregava o catálogo de instituições no modo de criação (`_initializeContext` chamava
  `_loadCreationCatalogs` apenas com `!_editing`) e a rota de edição não passava `loadInstitutions`; com o
  catálogo vazio, `_scopeCatalogUnavailable` ficava verdadeiro e o passo "Acesso ao Superadmin" mostrava
  "Catálogo de instituições indisponível · O acesso existente será preservado" (12), impedindo trocar perfil
  e escopos pela tela. Correção: `_loadRemote` carrega o catálogo (falha do catálogo preserva o acesso
  existente, sem derrubar a carga) e o router passa `loadInternalUserInstitutions` também na edição. Testes:
  `platform_user_form_context_test.dart` +2 casos (vermelho → verde; 23/23), `dart analyze` limpo;
  os 4 goldens do diretório de usuários internos seguem falhando pela deriva do cabeçalho (ADR 0041 C1).
- Método: `Page.navigate` para deep link após carga fria passa por `/login` transitório e volta à rota (sessão
  mantida pela caixa "Manter sessão aberta"); o renderer SwiftShader travou uma vez após navegações
  sucessivas (Chrome reiniciado; sessão preservada). `tap` do driver não responde; cliques por
  `Input.dispatchMouseEvent`, texto por `enter_text`, foco por `Input.dispatchKeyEvent Tab`.
- Nenhum teste existente alterado; nenhuma escrita SQL em produção. Massa: o perfil `281699f2…` fica em
  produção renomeado como "R15 A Perfil QA renomeado" (v2/v3), identificado por prefixo.
