---
name: coelo-frontend-backend
description: Use when a Coelo review, audit, correction, implementation, estimate, or completion claim crosses Front-end and Back-end, including Flutter/Dart or Astro with Supabase/Postgres, Auth, Edge Functions, Cloudflare R2, Stream, Workers, Media Gateway, remote persistence, or end-to-end behavior.
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
  status: "active"
  generated_at: "2026-09-08"
---

# Coelo Front-end + Back-end

> O caminho `coelo-flutter-supabase-review/` foi mantido para compatibilidade.
> O nome e o contrato canônicos são **Coelo Front-end + Back-end**
> (`coelo-frontend-backend`).

## Princípio

Controlar conclusão ponta a ponta sem substituir as autoridades de cada camada.
E2E significa executar o fluxo real por todos os provedores que a ação usa; não
significa somente Flutter → Supabase.

## Coordenação sem recursão

Ler `AGENTS.md` e o [contrato de recorte](references/review-scope.md).
Coordenar `coelo-frontend` e `coelo-backend` nas partes afetadas, sem reiniciar
suas dependências. Reutilizar contexto lido e carregar skills técnicas conforme
a operação/provedor; `coelo-ui` decide a família visual e `coelo-knowledge`
cuida da memória durável. Uma tarefa de uma camada não usa esta skill apenas
por mencionar o nome de um provedor.

Para conclusão ampla integrada, ler integralmente, nesta ordem, os rastreadores
`coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` e
`coelo-flutter-integrado-supabase-pendencias.md` em `docs/reviews/`.
Para ação específica, cruzar seus IDs, dependências, estados e evidências nos
três, com os cabeçalhos de medição. Os nomes históricos não limitam Back-end
somente a Supabase nem Front-end somente a Flutter.

## Recorte por app

Nomear explicitamente `superadmin`, `admin`, `principal` e/ou `site`. Na Etapa
2 atual, somente `apps/superadmin` e packages/backends que ele usa estão
autorizados. “Coelo (Principal)” é um menu do Superadmin, não o app Principal.
Não tocar apps fora do recorte por conveniência ou compartilhamento.
Plataformas compartilhadas de mídia/API permanecem neutras de app; nesta Etapa
2 somente o composition root do Superadmin é conectado. Admin e Principal
consomem o mesmo contrato em etapas futuras, e o Site não lê mídia privada.

## Três medições independentes

- Front-end `verified`: chegou ao fim do cliente; não exige backend real.
- Back-end `done`: chegou ao fim dos provedores backend aplicáveis; não exige
  Front-end.
- Integração `verified-e2e`: cliente real atravessou gateway, autorização,
  provedores, persistência e voltou à UI, incluindo reload e negativas.

Não somar os três denominadores. Preservar progresso de camada quando a cadeia
integrada ainda estiver aberta. `ready-for-e2e` exige Front-end `verified` e
Back-end `done` para a mesma ação.

Quando medir progresso, publicar geral e recorte separadamente, tempo usado medido, ETA e base de
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

Preservar recorte e autorizações já dados. Não perguntar tempo por padrão nem
usar faixas fixas por tela como estimativa. Estimar o delta comprovado. Inventariar
IDs e dependências antes da edição e registrar: apps/telas/ações, objetivo,
incluído/fora, ownership, ordem, critério de parada, evidências, bloqueios e ETA.

Review sem pedido de correção é leitura. Correção local não autoriza migration, recurso Cloudflare ou
deploy. Todo remoto Coelo é produção e exige autorização explícita para o
pacote nominal; não presumir DEV/homologação. Testar localmente, aplicar
forward-only de forma serializada e registrar recuperação. Um bloqueio externo
retém somente a ação dependente; continuar todo trabalho seguro independente.

## Execução, rastreadores e encerramento

Usar TDD por fatias verticais. Um único writer coordena migrations, recursos
Cloudflare compartilhados e cutover remoto. Sincronizar os três rastreadores no
mesmo turno de correção, regressão, bloqueio ou mudança de ETA, por
tela/subtela/action_id e não por nome da conversa.

No checkpoint, separar Front-end, Back-end Supabase, Back-end Cloudflare e
prova integrada. Informar commits, testes com quantidade/resultado, primeiro
gate aberto e ETA. Declarar conclusão do recorte quando seus gates estiverem comprovados, com
segredos ausentes e evidências preservadas. Commit, merge e deploy são etapas
separadas quando solicitadas; mudanças alheias não bloqueiam relatar uma
correção local verificada. Não confundir isso com integração ou publicação.
