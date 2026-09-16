---
source: "Sessão 5 da R14 (Opus 5), 16/09/2026; briefing comum da coordenadora; ADR 0041 C2/C4; owner.r12-20/21/22/24/25/26/27"
status: evidence
generated_at: 2026-09-16
---

# Perfis de acesso (`access-profiles.create/edit/assign`; owner.r12-20, 21, 22, 24, 25, 26, 27) — rota real, 16/09/2026

Ambiente: Supabase de produção (`evvbomzejfijozbtgvpt`); build `flutter build web --release -t
test_driver/qa_main.dart --dart-define-from-file=.env.local --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`
da worktree `r14/acessos-instituicoes` (código `89be705fa` para criação; `63ec6e973` para edição/atribuição),
servido por `serve.py` em `127.0.0.1:3016`; Chrome CDP `9416` (SwiftShader, perfil
`%TEMP%\coelo-r14-acessos-chrome`, tema claro); sessão `qa-r06-acessos@coelo.me` (Owner, escopo
plataforma). Negativas e readback por `packages/coelo_database/scripts/r13-rpc-proof.mjs` (PostgREST,
mesma identidade, sem chave de serviço). Capturas em `capturas/access-profiles-*.png`.

## Defeito encontrado e corrigido antes da prova (FE, `89be705fa` + `63ec6e973`)

Na primeira abertura de `/profiles/new/platform` com o catálogo real, a matriz mostrava o módulo como
`access` (código cru), a tela como "Access profile models" (humanização local) e três linhas "Criar"
sem distinção; na variante desktop, `firstWhere(actionCode)` por tela deixava **12 das 18 permissões
de `access` invisíveis** (o catálogo real tem `institution.|platform.|principal.role_models.*` na
mesma tela `access_profile_models`). Correção: `AccessPermission` passa a ler `module_label`,
`screen_label` e `action_label` do catálogo; `access_permission_labels.dart` traduz módulo › tela ›
ação (tradução local curada do código real > rótulo do servidor > código humanizado — o servidor ainda
devolve "Directory"/"Management" em inglês e `CardÃ¡pios` com codificação errada) e desdobra a tela
por alvo (Admin/Superadmin/Principal) quando as ações se repetem. Revisão e detalhe usam o mesmo
helper. Cabeçalho do módulo sem estouro em tela estreita. Tooltip de sensibilidade também por foco de
teclado e para risco elevado. Teste de widget `access_profile_catalog_labels_test.dart` (6 casos) +
suítes de Perfis existentes (70 PASS). Goldens de Perfis seguem falhando pela deriva do cabeçalho (ADR
0041 C1), sem regravação.

## Prova por action_id (parcial — ver bloqueio)

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| access-profiles.create | `/profiles` (cards, 00: lista sem o novo perfil) → "Criar perfil" → "Como criar o perfil?" → "Do zero" → `/profiles/new/platform`: passo "Perfil e escopo" **sem campo Código** (01), nome "R14 S5 Perfil QA", descrição, Status Ativo, Escopo máximo Plataforma → Continuar (laranja preenchido) → "Permissões" com módulo **Acessos › Modelos de perfil · Admin/Superadmin/Principal** e ações traduzidas (02); "Ver" (Admin) marcada; tooltip de sensibilidade em "Excluir" (crítica) por hover (03) → Continuar → Revisão "Acessos › Modelos de perfil › Consultar modelos Admin.", "0 vínculos impactados", texto configuração × acesso efetivo, motivo obrigatório → "Criar perfil" → volta a `/profiles`. | `superadmin_access_profile_save` (create) → `platform_roles` `281699f2-9399-40b4-a5c7-6d51f37a8a71`, code **gerado** `r14-s5-perfil-qa-46749519`, `version 1`, `capability_count 1`, `linked_people_count 0`, relido por `superadmin_access_profiles_list` (`p_search "R14 S5"`). | Carga completa de `/profiles` (viewport 1440×1300): 8 cards (Criar + 7 perfis) com Status/Escopo máximo/Vínculos/Tipo, "R14 S5 Perfil QA · Personalizado" presente (04). | `superadmin_access_profile_save` com `id` inexistente (`…0099`) → `500 P0002 access profile not found` (sem mutação; resíduo: não mapeado para 404/422); capability inexistente (`r14.s5.nao_existe`, com `institution_id …0099`) → `400 22023 unknown or invalid capability` nos dois domínios; `superadmin_access_profile_detail` de id inexistente → `500 P0002`. |
| access-profiles.edit | **bloqueado (ambiente)** — a abertura de `/profiles/platform/281699f2…` (detalhe, pré-requisito de "Editar") ficou em carregamento e, a partir de 12:28 BRT, toda RPC de produção passou a responder `504 PGRST003 Timed out acquiring connection from connection pool` (>80 min, inclusive `superadmin_access_permission_catalog` anônima e `superadmin_institution_detail_v2`). Projeto `ACTIVE_HEALTHY` no `supabase projects list`. | — | — | — |
| access-profiles.assign | **bloqueado (ambiente)** — idem; prova planejada em `/internal-users/bf6008f0…/edit` (QA R14BlocoC, massa R14 da Sessão 3) com restauração do perfil Owner ao fim. | — | — | `superadmin_internal_user_update` com `p_internal_identity_id` inexistente → `{ok:false, error:{code: SAI_PERMISSION_DENIED, http_status 403}}` (sem enumeração; observado antes do bloqueio). |

## Owner items (estado nesta fatia)

- **owner.r12-22** (sem campo Código; identificador gerado): provado na rota real — passo 1 sem Código (01) e code `r14-s5-perfil-qa-46749519` gerado pelo servidor. Falta só o reload da edição (bloqueio).
- **owner.r12-20** (cards com quantidade arbitrária + reload): 8 cards após reload (04); ADR 0041 C2 aprova a composição. Negativa cross-tenant: perfis Superadmin são de plataforma (sem tenant); a negativa observada é a de id inexistente/capability inválida. Resíduo: em viewport de 905 px de altura a terceira linha de cards não rolou com a roda do mouse dirigida por CDP (a barra de paginação cobre o card) — conferir manualmente antes de fechar.
- **owner.r12-21, r12-24, r12-25, r12-27**: correção de código provada em teste de widget e na rota real de criação (02/03); a captura de ~600 px (r12-25), o tooltip por foco (r12-24) e a revisão com "›" (r12-27) dependem do build `63ec6e973`, que não pôde ser exercitado por causa do bloqueio. Ficam `partial` com a correção registrada.
- **owner.r12-26**: Continuar laranja preenchido visto na criação (01, tema claro); a captura exigida é na **edição** — bloqueada.

## Observações

- `superadmin_access_profiles_list` devolve `{items, next_cursor}` (o cliente lê `total/page`; a paginação mostra "Página 1 de 1" — sem impacto com 7 perfis; conferir com >11).
- "Vínculos 0" no card Owner mesmo com usuários internos Owner ativos: `linked_people_count` conta `platform_memberships`, enquanto usuários internos vivem em `app_private.superadmin_internal_memberships`. Métrica potencialmente enganosa; não alterado (r12-20 pede "sem inventar métrica").
- Método: `tap`/`scrollIntoView`/`get_diagnostics_tree` do driver não respondem; `clickxy`, `enter_text` e `Input.dispatchMouseEvent mouseWheel` funcionam. A seta `→` não existe na fonte do build web (tofu); trocada por `›` em `63ec6e973`.
