---
name: coelo-frontend-backend
description: Use when a Coelo review, audit, correction, implementation, estimate, or completion claim crosses Front-end and Back-end, including Flutter/Dart or Astro with Supabase/Postgres, Auth, Edge Functions, Cloudflare R2, Stream, Workers, Media Gateway, remote persistence, or end-to-end behavior.
---

# Coelo Front-end + Back-end

> O caminho `coelo-flutter-supabase-review/` foi mantido para compatibilidade.
> O nome e o contrato canônicos são **Coelo Front-end + Back-end**
> (`coelo-frontend-backend`).

## Princípio

Controlar conclusão ponta a ponta sem substituir as autoridades de cada camada.
E2E significa executar o fluxo real por todos os provedores que a ação usa; não
significa somente Flutter → Supabase.

## Dependências obrigatórias

Sempre:

1. ler `AGENTS.md`;
2. usar `coelo-frontend`, `coelo-backend`, `coelo-ui`, `coelo-knowledge`,
   `rtk`, `ponytail`, `test-driven-development` e
   `verification-before-completion`;
3. para Flutter, usar `flutter-dart-code-review` e
   `flutter-build-responsive-layout`; para Astro, usar `astro`;
4. para Supabase, usar o plugin oficial, `supabase` e
   `supabase-postgres-best-practices`;
5. para Cloudflare, usar `cloudflare`; quando houver Worker/config/deploy,
   também `wrangler` e `cloudflare:workers-best-practices`;
   para fluxo cruzado de Workers+R2+DNS+Pages no mesmo passo, usar
   `cloudflare-manager` como fallback de orquestração.
6. ler integralmente, nesta ordem, os rastreadores em `docs/reviews/`:
   `coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` e
   `coelo-flutter-integrado-supabase-pendencias.md`.

Os nomes dos arquivos dos rastreadores foram mantidos por compatibilidade;
Front-end abrange Flutter/Dart e Astro, Back-end abrange Supabase e Cloudflare.

## Recorte por app

Nomear explicitamente `superadmin`, `admin`, `principal` e/ou `site`. Na Etapa
2 atual, somente `apps/superadmin` e packages/backends que ele usa estão
autorizados. “Coelo (Principal)” é um menu do Superadmin, não o app Principal.
Não tocar apps fora do recorte por conveniência ou compartilhamento.

## Três medições independentes

- Front-end `verified`: chegou ao fim do cliente; não exige backend real.
- Back-end `done`: chegou ao fim dos provedores backend aplicáveis; não exige
  Front-end.
- Integração `verified-e2e`: cliente real atravessou gateway, autorização,
  provedores, persistência e voltou à UI, incluindo reload e negativas.

Não somar os três denominadores. Preservar progresso de camada quando a cadeia
integrada ainda estiver aberta. `ready-for-e2e` exige Front-end `verified` e
Back-end `done` para a mesma ação.

Sempre publicar progresso geral e do recorte, tempo usado medido, ETA e base de
cálculo. Se faltarem evidências/horários, usar `não calculável ainda`, sem falsa
precisão.

## Gate `verified-e2e`

Para cada `action_id`, provar:

1. UI/rota normal → estado → repository/gateway produtivo;
2. sessão, ator, capability, tenant, ownership e hierarquia no servidor;
3. RPC/query/Edge/Worker, RLS e grants mínimos;
4. persistência e nova leitura/reload;
5. permitido, negado, revogado, tenant A/B e ID adulterado;
6. auditoria, efeitos laterais, retry/idempotência e cleanup;
7. regressão Front-end, Back-end e integrada no ambiente autorizado.

Quando houver mídia/exportação, a cadeia inclui Supabase para metadados e
autorização, Media Gateway e objeto R2 privado real. Quando a política exigir
vídeo HOT, inclui também Stream privado, signed playback, estado de encoding,
fallback R2 e remoção da cópia Stream. Mock, bucket público, URL artificial,
rota `/dev`, golden ou teste isolado não comprovam isso.

### Contratos de produto obrigatórios

- Agora: R2 master primeiro; Stream HOT por até 24 h quando necessário; apagar
  somente Stream na expiração.
- Momentos: R2 padrão; Stream por demanda medida, sem janela fixa inventada.
- Acontece: R2 padrão; Stream somente quando métricas justificarem.
- Chat: R2, sem obrigação de Stream no MVP.
- Formulários: um XLSX com as respostas do formulário no R2 privado; não uma
  exportação por resposta, e sem CSV/ZIP/PDF inventado.
- Outros import/export do Superadmin: botão visível e honestamente indisponível.

## Contrato de abertura

Se o usuário não informou tempo, perguntar. Se o pacote já é `Completa`, todas
as pendências ou execução até terminar, não perguntar novamente. Inventariar
IDs e dependências antes da edição e registrar: apps/telas/ações, objetivo,
incluído/fora, ownership, ordem, critério de parada, evidências, bloqueios e ETA.

Review é leitura. Correção local não autoriza migration, recurso Cloudflare ou
deploy. Produção exige autorização explícita para o pacote. Um bloqueio externo
retém somente a ação dependente; continuar todo trabalho seguro independente.

## Execução, rastreadores e encerramento

Usar TDD por fatias verticais. Um único writer coordena migrations, recursos
Cloudflare compartilhados e cutover remoto. Sincronizar os três rastreadores no
mesmo turno de correção, regressão, bloqueio ou mudança de ETA, por
tela/subtela/action_id e não por nome da conversa.

No checkpoint, separar Front-end, Back-end Supabase, Back-end Cloudflare e
prova integrada. Informar commits, testes com quantidade/resultado, primeiro
gate aberto e ETA. Só declarar conclusão quando worktree estiver limpa, commits
integrados, segredos ausentes, evidências preservadas e todos os gates do
recorte realmente verdes.
