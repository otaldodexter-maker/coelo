---
title: "Prompt de execução — Fundação Supabase cross-app em 4 dias"
source: "AGENTS.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md; decisions/0019-superadmin-internal-identity.md; specs/039-superadmin-internal-auth-session-context.md; contrato aprovado pelo Owner Coelo em 2026-08-31"
status: "approved-execution-prompt"
generated_at: "2026-08-31"
---

# Fundação Supabase cross-app em 4 dias

Copie o texto abaixo para iniciar a tarefa de execução.

```text
Continue o programa de fundação Supabase do Coelo.

Trabalhe no repositório:

C:\Users\adrie\Documents\Coelo

Crie uma worktree isolada conforme a skill `using-git-worktrees`, com branch
prefixada por `codex/`, antes da primeira edição. Existe uma frente visual em
andamento; preserve integralmente qualquer worktree, alteração ou commit dela.

## Skills e ferramentas obrigatórias

Leia integralmente e aplique, antes de alterar qualquer arquivo:

1. `AGENTS.md` e `C:\Users\adrie\.codex\RTK.md`;
2. `.agents/skills/rtk/SKILL.md`;
3. `.agents/skills/coelo-supabase/SKILL.md`;
4. `.agents/skills/coelo-flutter-supabase-review/SKILL.md`, somente para
   preservar limites e estados integrados; não altere UI/UX ou Flutter;
5. `.agents/skills/coelo-knowledge/SKILL.md`;
6. a skill oficial `supabase`;
7. a skill `supabase-postgres-best-practices` e as referências pertinentes a
   RLS, privilégios, índices de FKs, queries, concorrência e diagnóstico;
8. `test-driven-development`, `systematic-debugging`,
   `verification-before-completion`, `writing-plans` e
   `using-git-worktrees` quando seus gatilhos forem alcançados;
9. `ponytail` em modo completo para a menor fundação segura e reutilizável.

Use sempre o plugin oficial `@Supabase` (`supabase@openai-curated-remote`).
Comece por `search_docs`, changelog atual, `list_projects`, `get_project`,
`list_migrations`, `list_tables`, `list_edge_functions` e Advisors de segurança
e desempenho. Use `execute_sql` somente para consultas SELECT de inventário
antes da autorização de mutação. Não use ferramenta genérica quando o plugin
oficial responder à necessidade.

Use `rtk` em todo comando compatível: buscas, leituras, Git, diff, status,
testes e lint. Confirme no início `rtk gain` e `rtk git status`. Cmdlet nativo
do PowerShell sem wrapper RTK pode ser usado, registrando a exceção.

## Orçamento e nível

Orçamento total autorizado: 4 dias de trabalho focado.

Nível contratado: `Avançada` para a fundação local. A prova remota só pertence
ao pacote quando houver autorização explícita para a operação remota exata.

Modalidade: `macrotema` — fundação Supabase cross-app, sem telas.

O orçamento não autoriza retirar RLS, isolamento entre tenants, testes
negativos, validação de inputs, grants mínimos ou rastreabilidade. Se um gate
não couber, reduza o próximo subpacote e registre o restante; não declare
conclusão artificial.

## Progresso inicial conhecido

Recalcule os números no HEAD e no remoto antes de responder. O último baseline
conhecido, que não substitui o inventário vivo, é:

- projeto estrito: 0/229 unidades concluídas;
- Flutter local-green: 84/207 ações; Flutter verified: 0/207;
- Supabase local-green: 3/37 famílias; Supabase done: 0/37;
- integração E2E: 0/202 ações;
- backlog Supabase estrito: 0/228 unidades done;
- filesystem: 112 migrations canônicas no último checkpoint;
- remoto `coelo` (`evvbomzejfijozbtgvpt`): 103 migrations, última
  `20260821200000_profile_about_remote_context_compatibility`;
- Security Advisor remoto: 207 achados — 50 informativos de RLS sem policy,
  156 warnings de SECURITY DEFINER executável por `authenticated` e 1 aviso de
  proteção contra senhas vazadas;
- Performance Advisor remoto: 505 achados — 128 FKs sem índice e 377 índices
  não usados.

Na abertura e em cada checkpoint, use o formato percentual obrigatório das
skills. Explique em linguagem cotidiana Auth, RLS, RPC, migration, ledger,
Advisor, `local-green`, `remote-green` e `done` na primeira ocorrência.

## Objetivo dos quatro dias

Produzir uma fundação backend reutilizável pelo Superadmin atual e preparada,
sem endpoints especulativos, para o futuro Admin e Principal:

- Superadmin: identidade interna e Owner com escopo global explicitamente
  autorizado, nunca bypass por nome de papel;
- Admin futuro: escopo institucional preparado pelo modelo de membership;
- Principal futuro: pessoa global, contexto infantil e vínculo familiar
  preparados pelas entidades canônicas;
- nenhum aplicativo futuro recebe tela, gateway público ou permissão nova neste
  pacote.

O resultado esperado ao fim do quarto dia é uma fundação `local-green`
reproduzível. Se a reconciliação e a autorização permitirem, preparar e executar
uma validação remota controlada; não prometer `remote-green` antecipadamente.

## Incluído

1. Inventário e reconciliação de migrations canônicas, mirrors, ledger local e
   ledger remoto dentro das dependências da fundação.
2. Auth por e-mail/senha, sessão, logout e revogação básica já previstas nos
   contratos canônicos, sem MFA.
3. Pessoa global e identidade interna do Superadmin conforme ADR 0019/spec 039.
4. Hierarquia estável de tenant/instituição/unidade/turma e FKs compostas.
5. Memberships e vínculos contextuais já aprovados, sem inventar campos de UI.
6. Catálogo mínimo de papéis/capacidades necessário à fundação.
7. RLS deny-by-default, FORCE RLS quando aplicável, grants mínimos e default
   privileges seguros.
8. Helpers privados e gateways nominais somente quando já exigidos pelo recorte;
   SECURITY DEFINER precisa de justificativa, `search_path = ''`, owner correto
   e EXECUTE explicitamente revogado/concedido.
9. Envelopes de erro estáveis e auditoria mínima sem PII, JWT, segredo ou payload
   sensível.
10. Índices de FKs e filtros de autorização do delta.
11. pgTAP e testes estruturais/comportamentais com dados exclusivamente
   sintéticos e rollback/cleanup.
12. Provas de ator permitido, sem sessão, papel/capacidade inativa ou negada,
   membership suspensa/revogada, tenant A/B, sibling unit, cross-app e UUID
   adulterado.
13. Atualização de fontes canônicas, specs e rastreadores afetados.

## Explicitamente fora de escopo

- qualquer arquivo em `apps/**`;
- qualquer tela, widget, controller, formulário, input, rota, golden, catálogo
  visual, componente, navegação ou comportamento de UI/UX;
- qualquer alteração em `packages/coelo_ui_*`;
- implementação de telas ou repositories Flutter para Superadmin, Admin ou
  Principal;
- MFA/AAL2 como requisito deste pacote;
- importação, exportação, download, upload, arquivos, mídia, Supabase Storage,
  Cloudflare R2 e respectivos workers;
- Edge Functions novas, salvo decisão posterior explícita;
- campos de domínio que ainda estejam sendo discutidos nas telas;
- Admin, Principal ou site como produtos executáveis;
- dados reais, PII real ou dados reais de crianças;
- limpeza global dos 207/505 Advisors históricos;
- deploy, migration remota, DDL/DML remota ou configuração Auth remota sem
  autorização nominal e específica do Owner;
- `service_role` em cliente, Git, logs, evidências ou URLs.

Não altere uma tela apenas para provar o backend. A skill
`coelo-flutter-supabase-review` serve neste pacote para registrar que Flutter e
E2E continuam pendentes, não para autorizar trabalho visual.

## Ownership de paths

Antes de editar, confirme o status vivo e reserve somente:

- `packages/coelo_database/migrations/**`;
- mirror canônico realmente usado pelo projeto, após inventário;
- `packages/coelo_database/supabase/tests/**`;
- testes/validações SQL da fundação;
- specs/ADRs/open questions estritamente afetados;
- `docs/reviews/coelo-supabase-pendencias.md`;
- o checkpoint correspondente em
  `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`, sem promover
  Flutter ou E2E;
- plano desta execução em `docs/superpowers/plans/**`.

Não toque em arquivo dirty ou pertencente à frente visual. Se houver sobreposição
documental, faça atualização append-only em seção própria e reconcilie o HEAD
antes do commit; nunca sobrescreva o checkpoint da outra frente.

## Ordem dos quatro dias

### Dia 1 — congelamento, inventário e plano reproduzível

1. Registrar HEAD, branch, worktrees, status, processos, containers e portas.
2. Ler integralmente os três rastreadores na ordem Flutter → Supabase → integrado.
3. Consultar `docs/knowledge` e as fontes canônicas relevantes.
4. Classificar o remoto `coelo` como desenvolvimento, homologação ou produção;
   se não houver evidência, registrar `blocked-environment` e não inferir.
5. Inventariar pelo plugin oficial migrations, tabelas, funções, policies,
   grants, Auth, Edge e Advisors sem mutação.
6. Comparar nomes e SHA-256 de migrations canônicas/mirrors e os 103 registros
   remotos; produzir manifesto de drift por objeto e dependência.
7. Escrever um plano TDD detalhado e executar apenas após auto-revisão.
8. Atualizar o checkpoint com tempo medido e primeiro RED executável.

Gate do Dia 1: inventário datado, ambiente classificado ou bloqueado, paths
reservados, drift explicado e sequência segura definida. Nenhuma mutação remota.

### Dia 2 — identidade, Auth e hierarquia estável

1. Executar REDs antes de cada alteração.
2. Reconciliar a fundação Auth/identidade interna forward-only, sem restaurar
   migration histórica apenas pelo nome.
3. Validar pessoa global e separação do realm interno.
4. Validar hierarquia instituição/unidade/turma, FKs e índices.
5. Tratar IDs, claims, filtros e parâmetros como não confiáveis.
6. Provar que Owner global decorre de relações/grants ativos, nunca do texto
   `owner`, `service_role` ou metadado mutável.
7. Rodar testes focados e regressões das dependências.

Gate do Dia 2: Auth/identidade/hierarquia instaláveis em stack descartável,
testes focados verdes e zero alteração em UI/UX.

### Dia 3 — memberships, capacidades e RLS

1. Implementar ou reconciliar somente memberships/vínculos já aprovados.
2. Preparar os limites de Superadmin global, Admin institucional e Principal
   familiar sem criar gateways públicos futuros.
3. Aplicar RLS/grants mínimos e default ACL segura.
4. Provar tenant A/B, cross-app, sibling unit, membership suspensa/revogada,
   capability ausente/deny e IDs adulterados.
5. Provar que filtros do cliente apenas estreitam o conjunto autorizado.
6. Executar Advisor/lint local sobre o delta e classificar todo novo achado.

Gate do Dia 3: matriz de autorização local reproduzível e negativa, sem bypass
implícito e sem ampliar apps futuros.

### Dia 4 — contratos backend, regressão e fechamento retomável

1. Fechar envelopes de erro, auditoria mínima, versionamento e concorrência
   aplicáveis à fundação.
2. Executar replay limpo somente pelo ledger em stack descartável.
3. Rodar pgTAP, lint, diff canônico/mirror, secret scan e regressões.
4. Confirmar cleanup: zero fixture persistente, container/volume/rede temporária
   residual, segredo ou PII em evidência.
5. Reconsultar migrations e Advisors remotos via plugin oficial.
6. Se e somente se houver autorização remota explícita, apresentar antes:
   ambiente, migrations exatas, hashes, SQL/objetos afetados, rollback ou plano
   forward-only, testes verdes e risco. Executar apenas o pacote autorizado.
7. Atualizar fontes canônicas primeiro e depois rastreadores/memória.
8. Registrar o primeiro gate incompleto e o próximo comando seguro.

Gate do Dia 4: fundação `local-green` documentada e reproduzível. Só usar
`remote-green` se o remoto autorizado e todas as negativas do recorte forem
comprovados. Nunca chamar Flutter ou E2E de concluídos.

## Atualizações documentais obrigatórias

Após cada correção, regressão, bloqueio ou mudança de ETA:

1. Atualizar a fonte canônica aplicável antes do rastreador.
2. Atualizar `docs/reviews/coelo-supabase-pendencias.md` no mesmo turno.
3. Atualizar o rastreador integrado apenas para registrar dependência/estado;
   manter Flutter e `verified_e2e` inalterados.
4. Não alterar o estado de nenhuma tela porque o backend ficou verde.
5. Registrar conflitos em `docs/open-questions.md`; não resolvê-los
   silenciosamente.
6. Executar o gate `coelo-knowledge`: projetar somente conhecimento durável,
   aprovado e sem PII; usar `no-op` quando nada reutilizável mudar.
7. Registrar por checkpoint: objetivo, paths, migration/teste, hashes, RED,
   GREEN, regressões, ambiente, estado local/remoto, tempo usado, ETA restante,
   bloqueios e próximo passo exato.

## Regras de execução e segurança

- TDD obrigatório: RED comprovado → alteração mínima → GREEN → regressão.
- Migration nova somente pelo comando atual descoberto em `supabase --help`;
  não inventar timestamp/filename manualmente.
- Nunca editar migration já aplicada remotamente; usar forward-only.
- Nunca restaurar recovery histórica por semelhança de nome.
- Não usar Dashboard para mudança de schema.
- Não usar `user_metadata` como autorização.
- `TO authenticated` sozinho não é autorização.
- UPDATE exige SELECT policy e `USING` + `WITH CHECK` quando aplicável.
- Views expostas usam `security_invoker = true` ou ficam inacessíveis aos papéis
  clientes.
- SECURITY DEFINER é exceção justificada, não correção de permission denied.
- Revogar EXECUTE de PUBLIC por padrão e conceder somente gateways nominais.
- Indexar FKs e predicados críticos do delta; não remover índice apenas por
  aparecer como `unused` em ambiente jovem.
- Depois de duas ou três tentativas equivalentes sem avanço, pare, diagnostique
  e mude a abordagem; não faça loop.
- Commits locais pequenos e focados após gates verdes são permitidos. Não faça
  push, merge, deploy ou alteração remota sem autorização explícita.

## Critérios de parada

Pare em checkpoint seguro quando ocorrer o primeiro destes casos:

- quatro dias de trabalho focado consumidos;
- conflito canônico que muda autoridade, hierarquia ou schema;
- ambiente remoto não classificado antes de mutação;
- drift impede replay limpo e não pode ser corrigido forward-only no recorte;
- arquivo da frente visual seria necessário;
- falta autorização para operação remota;
- dado real/PII seria necessário;
- o Owner pedir pausa.

Ao parar, atualize primeiro os documentos e informe:

- progresso geral e do recorte;
- tempo realmente usado;
- gates concluídos com evidência;
- último RED/GREEN;
- estado local, ledger e remoto;
- o que permaneceu fora de escopo;
- primeiro gate incompleto;
- próximo comando seguro;
- ETA recalculado.

## Definição de sucesso

Sucesso deste pacote não significa produto, tela ou CRUD visual concluído.
Significa:

- fundação backend cross-app reproduzível;
- Auth/identidade/hierarquia/memberships/RLS básicas comprovadas localmente;
- tenant A/B e cross-app negativos verdes;
- migrations/mirrors/ledger do recorte reconciliados;
- zero alteração em UI/UX;
- documentação e retomada persistentes;
- remoto apenas no estado realmente comprovado e autorizado.

Comece apresentando o contrato de abertura completo e o inventário read-only.
Depois prossiga sem pedir novamente escolhas já definidas neste prompt. Peça
confirmação somente quando uma mutação remota específica estiver pronta para
ser executada.
```
