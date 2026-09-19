# Prompt — Sessão ETAPA-3 (consolidação + pendências livres)

> Para abrir: numa conversa nova em `C:\Users\adrie\Documents\Coelo`, cole:
> **"Você é a SESSÃO ETAPA-3 do Coelo. Leia e execute
> `docs/agent/prompt-etapa3-consolidacao-20260919.md` do início ao fim, sem parar
> para perguntar."**

---

Você é a SESSÃO ETAPA-3 do Coelo. Trabalha na pasta principal
`C:\Users\adrie\Documents\Coelo`, branch `dev`, com **liberdade e acesso total**:
navegador para teste real (Chrome com CDP), usuários sintéticos, Supabase
(produção `evvbomzejfijozbtgvpt` é o único remoto) e Cloudflare. O Owner não
acompanha em tempo real: **não pare para perguntar**; decida pelo padrão do
código, dos PRDs e das specs, anote a decisão em uma linha e siga.

Leia antes de começar: `CLAUDE.md` (Modo de construção), `AGENTS.md`,
`docs/agent/pendentes.md`, `decisions/0045-mvp-definition-etapa3-etapa4-20260918.md`.
Skills: `/rtk` no início; `coelo-fullstack`, `coelo-backend`, `coelo-frontend`,
`coelo-ui` conforme o que tocar; `coelo-knowledge` só para regra de produto nova.

Regras que valem sempre: invariantes de segurança do AGENTS.md; `PT409` nunca
`40001`; credenciais QA em `C:\Users\adrie\Documents\Coelo-backups\` e nunca
impressas; migration com pgTAP verde aplica direto
(`supabase db query --linked --workdir packages/coelo_database -f migrations/<arquivo>`,
depois `supabase migration repair --status applied <carimbo> --linked`, cópia em
`supabase/migrations/`, linha no fim de `ordem-de-aplicacao-producao.txt`);
commit pequeno, push em `dev`; nada de spec, ADR, evidência ou rodada nova.

## Papel 1 — consolidação (começa agora, fecha no fim)

Você é a sessão que garante que **nada fica solto** ao final do dia.

1. `ListAgents` e mande a cada sessão ocupada esta mensagem: "Sou a SESSÃO
   ETAPA-3 (consolidação + pendências livres da Etapa 3: specs 065–069,
   Segurança r12-10/r12-18, Conta r12-46, resíduos de acesso contextual e
   imagens). **Ao terminar o seu trabalho**, e só no final, me mande: lista de
   commits, o que ficou pendente, o que não foi atualizado em
   `docs/agent/pendentes.md`, nas skills ou em outro `.md`, e qualquer
   pendência de git/GitHub/worktree/branch. Eu consolido tudo."
   Sessões conhecidas: ACESSO-PERFIL (coelo-3a [e956fa], worktree
   `Coelo.worktrees\e3-acesso-perfil`, branch `e3/acesso-perfil`: staff_access,
   access_profiles, lote 86); MÍDIA-E2E (coelo-06, worktree
   `Coelo.worktrees\e3-midia`: entity_image_*, fotos em diretórios/cards/detalhes,
   principal_* mídia, meal_plans, safety, Edges *-media, lote 87); CODE REVIEW
   (coelo-3b, pasta principal: extração dos DialogRoute em 25 arquivos sem
   commit, máscara de telefone, pickers e CoeloDateField, previews do Principal
   com tokens, quebra do shell).
2. Mande também à MÍDIA-E2E (coelo-06) estes dois itens, que são dela: (a)
   Atividade só aceita foto/capa/ícone depois de criada porque o id nasce no
   servidor via `ActivityFormSubmit` sem retorno — devolver o id na criação e
   permitir a foto no mesmo fluxo; (b) CORS do bucket R2 `coelo-media-prod`:
   Momentos, Agora, Circulares, Chat e Cardápios ainda fazem PUT/GET direto ao
   R2 e falham fora de 3014/3016; o token do wrangler não tem R2 (erro 10000) —
   passar os bytes pela Edge como já foi feito em `entity-media`, ou ajustar o
   CORS do bucket com token novo com permissão R2.
3. **Antes de qualquer edição sua**, verifique a pasta principal: há 25 arquivos
   modificados sem commit (extração de `superadminDialogRoute` em
   `apps/superadmin/lib/shared/presentation/widgets/superadmin_owned_dialogs.dart`),
   que pertencem à CODE REVIEW. Não commite nem reverta o que é dela. Confira
   com `git log origin/dev..dev`, `git worktree list` e `git branch -a` se há
   commits ou branches que não sejam das três sessões acima; se houver algo
   órfão, integre em `dev` (cherry-pick) ou registre em `pendentes.md`.
4. **No fim do dia**, quando as três sessões tiverem reportado: integre em
   `dev` os commits das worktrees que não estiverem lá (cherry-pick na ordem
   enviada), rode `flutter analyze` e `flutter test` em `apps/superadmin`,
   corrija o que quebrou, remova as worktrees e branches integradas
   (`git worktree remove`, `git branch -D`, `git push origin --delete`),
   deixando **só `dev`** local e no GitHub; atualize `docs/agent/pendentes.md`
   (apague o entregue, acrescente o que sobrou, uma linha por item); se alguma
   regra durável nova surgiu, uma linha na skill certa (`coelo-fullstack`,
   `coelo-backend`, `coelo-frontend`, `coelo-knowledge`); commit único de
   consolidação e push em `dev`. Nenhum commit solto, nenhum `.md` desatualizado.

## Papel 2 — pendências livres da Etapa 3 (execute nesta ordem, ponta a ponta)

Cada item: contrato no servidor (migration + pgTAP) quando precisar → aplicar em
produção → tela → `flutter test` → abrir no navegador na rota real com a
identidade QA da área (`qa-r06-<area>`) e ver funcionar → commit + push → apagar
a linha de `pendentes.md`. Módulos reservados por outras sessões: **não edite**
`staff_access`, `access_profiles`, `entity_image_*`, Edges `*-media`,
`superadmin_shell.dart`, e os arquivos que a CODE REVIEW listar; em `safety` e
`principal_*` **avise a MÍDIA-E2E antes** e toque só no que não é mídia.

1. **Avisos — spec 069** (`specs/069-superadmin-notices-duplicate-cta-refresh.md`,
   `features/notices`): RPC `superadmin_notice_duplicate_v1` que clona o aviso
   como rascunho (título "Cópia de …", mesma audiência, sem publicação) + pgTAP;
   ação "Duplicar" no flyout do diretório; CTA de item relacionado abre o
   destino real; atualização/publicação sem esvaziar a lista (mantém filtros e
   posição). Provar com `qa-r06-comunicacao` (ou a identidade de Avisos que
   existir em `Coelo-backups`).
2. **Perfis de cuidado — spec 065**
   (`specs/065-superadmin-care-profile-collections-redesign.md`,
   `features/health_care`): wizard Alimentos × Restrições, lista categorizada
   com nome, reordenar (botões, não só arrasto), campo "O que fazer se
   consumido?"; coleção e limite 100 já estão em produção (lote 63/74).
   Migration só se o contrato exigir campo novo.
3. **Instituições — spec 066**
   (`specs/066-entity-lifecycle-activate-inactivate-delete.md`,
   `features/institutions`, `units`, `groups`): ciclo de vida ativar /
   inativar / excluir (opção B: exclusão só sem dependentes, senão inativar),
   `institutions.status` na tela e no leitor, motivo obrigatório, auditoria,
   `PT409` em versão defasada. Ação `institutions.status` volta ao MVP por esta
   spec.
4. **Locais — spec 067** (`specs/067-superadmin-locations-map-image.md`,
   `features/locations`): mapa por imagem (planta) com pontos/áreas, hierarquia
   instituição › unidade › local, visibilidade por perfil; mídia da planta pelo
   Media Gateway já existente (`locations` é o prefixo R2, OQ-045). Combine com
   a MÍDIA-E2E só se precisar de Edge nova.
5. **Principal — spec 068**
   (`specs/068-principal-official-profiles-auto-follow.md`,
   `features/principal_for_you`, `principal_happens`): perfis oficiais do Coelo
   seguidos automaticamente por toda família, conteúdo deles no "Para você" e no
   Acontece; Superadmin publica como perfil oficial. Avise a MÍDIA-E2E antes de
   tocar em `principal_*`.
6. **Segurança da criança — r12-18**: envio final do wizard "pessoa sem conta"
   pela tela (backend em produção desde o lote 78); o upload do documento
   passa pela Edge `child-safety-media` (se ainda for PUT direto ao R2 e falhar
   por CORS, passe os bytes pela Edge como em `entity-media`). Avise a MÍDIA-E2E
   antes (`safety`).
7. **Segurança da criança — r12-10**: diretório alinhado à Table canônica
   (`coelo_ui_admin` Table): colunas, densidade, ações da linha, hover, teclado.
   Mesma observação sobre `safety`.
8. **Conta — r12-46**: layout A+ do card "Meu acesso" (perfil, vínculos e
   permissões na mesma linha, rolagem interna em viewport baixo), sem tocar na
   máscara do Celular (já feita).
9. **Acesso contextual — resíduos** (só backend/dados; a tela é da
   ACESSO-PERFIL, avise-a antes se precisar da UI):
   a. criar na Auth Admin uma conta de login para "QA R15 Educadora Turma"
      (senha em `Coelo-backups\qa-r15-educadora.env`, nunca impressa) e provar
      na rota real o popup de bloqueio no Principal e a negação no servidor;
   b. depois da prova, remover pela tela (ou por RPC) a regra seg–sex 08–18 da
      educadora se não servir mais;
   c. varredura dos leitores legados (chat, feeds, listagens) que juntam
      `institution_memberships` sem passar por `has_context_permission`:
      listar, corrigir os que expõem dado a vínculo bloqueado, pgTAP;
   d. decidir e implementar: RPCs contextuais passam a negar com
      `STAFF_ACCESS_DENIED` (detail) em vez de 42501 genérico, e o cliente mostra
      o popup de bloqueio ao receber esse código em sessão já aberta.
10. **Imagens — worker de expiração**: rascunhos de `entity_image_assets` sem
    upload expiram só logicamente; criar limpeza como em `account-media`
    (pg_cron + Edge ou função SQL agendada), com pgTAP. Avise a MÍDIA-E2E
    antes, porque é a tabela dela.

Fora deste prompt (o Owner faz depois): CORS público/R2 definitivo, revisão dos
textos do tour, nomes para "Para você" e instituições fictícias, Etapa 4.

## Entrega

Ao terminar os dois papéis: `dev` local igual a `origin/dev`, só `dev` no
GitHub, sem worktree, `flutter analyze` limpo, `flutter test` sem falha
funcional, `pendentes.md` refletindo o que sobrou, skills com as regras novas em
uma linha cada. Mensagem final ao Owner com: itens entregues (tela + como ver),
itens não entregues com causa, e o que ficou em `pendentes.md`.
