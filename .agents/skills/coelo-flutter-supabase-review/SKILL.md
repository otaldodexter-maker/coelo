---
name: coelo-frontend-backend
description: Use when a Coelo review, audit, correction, implementation, estimate, or completion claim crosses Front-end and Back-end, including Flutter/Dart or Astro with Supabase/Postgres, Auth, Edge Functions, Cloudflare R2, Stream, Workers, Media Gateway, remote persistence, or end-to-end behavior.
metadata:
  source: "AGENTS.md; decisions/0032-mvp-private-media-r2.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Front-end + Back-end

> O caminho `coelo-flutter-supabase-review/` foi mantido para compatibilidade.
> O nome e o contrato canônicos são **Coelo Front-end + Back-end**
> (`coelo-frontend-backend`).

## Chamada padrão: resolver pendências ponta a ponta

Invocar `$coelo-frontend-backend` para trabalhar no projeto significa **executar
a resolução de uma fatia da Etapa 2 até sua prova ponta a ponta**, conforme o
[ciclo de resolução](references/review-scope.md#ciclo-de-resolução-de-pendências).
Preservar o recorte informado; sem recorte novo, retomar a subtela incompleta
do último checkpoint ou selecionar a próxima ação executável do inventário.
Informar a escolha e executar as correções locais necessárias, sem terminar
apenas com auditoria, plano ou atualização de percentuais. Pedido explícito de
explicação, diagnóstico/review somente leitura ou manutenção da skill segue
esse pedido, sem iniciar implementação do produto.

Conectar e provar a mesma ação na UI normal, no backend aplicável e no retorno
após reload. Preparar o pacote remoto revisável antes de pedir autorização que
ainda falte; respeitar autorizações existentes e a ordem serializada. Se um
gate impedir E2E, concluir o trabalho independente do recorte, registrar a
causa e o desbloqueio concreto, sem promover o estado por expectativa.

## Princípio

Controlar conclusão ponta a ponta sem substituir as autoridades de cada camada.
E2E significa executar o fluxo real por todos os provedores que a ação usa; não
significa somente Flutter → Supabase.

## Coordenação sem recursão

Confirmar a base integrada e o handoff antes de reutilizar estado local; seguir
a retomada entre worktrees e o limite de repetição de testes do contrato comum.
Ler `AGENTS.md` e o [contrato de recorte](references/review-scope.md).
Coordenar `coelo-frontend` e `coelo-backend` nas partes afetadas, sem reiniciar
suas dependências. Reutilizar contexto lido e carregar skills técnicas conforme
a operação/provedor; `coelo-ui` decide a família visual e `coelo-knowledge`
cuida da memória durável. Uma tarefa de uma camada não usa esta skill apenas
por mencionar o nome de um provedor.

Se Cloudflare participar da ação, aplicar a descoberta de MCP, skills e
implantação nominal definida em `coelo-backend`/`cloudflare-manager`. Teste
local verde não substitui implantar/verificar o pacote já autorizado. Antes
da validação conjunta, conferir que o checkout de testes contém o SHA integrado.
Priorizar as correções visuais apontadas pelo Owner e ligar seus aceites à
mesma ação no backend, sem refazer composição já aprovada.

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

Todo checkpoint identifica **Etapa 2 → apps/superadmin → menu → tela →
subtela/estado → action_id**. Subtelas têm linhas próprias e não herdam conclusão
do diretório, da família ou de outra ação. Consultar o
[contrato de métricas e testes](../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md)
para denominadores, evidência, testes e formato do painel.

## Três medições independentes

- Front-end `verified`: chegou ao fim do cliente; não exige backend real.
- Back-end `done`: chegou ao fim dos provedores backend aplicáveis; não exige
  Front-end.
- Integração `verified-e2e`: cliente real atravessou gateway, autorização,
  provedores, persistência e voltou à UI, incluindo reload e negativas.

Não somar os três denominadores. Preservar progresso de camada quando a cadeia
integrada ainda estiver aberta. `ready-for-e2e` exige Front-end `verified` e
Back-end `done` para a mesma ação.

Em cada entrega de implementação, publicar por tela/subtela: avanço local
comprovado, Front-end `verified`, Back-end `done`, E2E `verified-e2e`, restante,
testes aprovados/falhos e cobertura do plano. Separar recorte do geral conhecido
da Etapa 2, com data e base. Somar contagens de IDs únicos, nunca médias dos
percentuais de telas. Não usar testes locais aprovados como percentual de E2E.
Falta de inventário, evidência ou horário fica `não calculável ainda`, com
próximo dado necessário; ausência de certificado não é ausência de implementação.

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

Review sem pedido de correção é leitura. Preparar/corrigir migrations e executar
replay local segue o contrato/spec aprovado da ação. Aplicar migrations ou
alterar recursos Cloudflare remotamente e fazer deploy exige autorização
nominal; correção local não concede essa autorização. Todo remoto Coelo é
produção e exige autorização explícita para o
pacote nominal; não presumir DEV/homologação. Testar localmente, aplicar
forward-only de forma serializada e registrar recuperação. Um bloqueio externo
retém somente a ação dependente; continuar todo trabalho seguro independente.

## Execução, rastreadores e encerramento

Usar TDD por fatias verticais. Um único writer coordena migrations, recursos
Cloudflare compartilhados e cutover remoto. Sincronizar os três rastreadores no
mesmo turno de correção, regressão, bloqueio ou mudança de ETA, por
tela/subtela/action_id e não por nome da conversa.

Priorizar o primeiro gate aberto de uma subtela enquanto executável. Diante
de bloqueio demonstrado, registrar a dependência e continuar as ações
independentes autorizadas do recorte. No checkpoint,
registrar o delta: aceites fechados, falhas resolvidas/novas, gate que impede E2E,
próxima ação concreta e responsável. Classificar impedimento como implementação,
verificação, integração de código, ambiente/pacote ou decisão. Um bloqueio não
contamina ações independentes. Retomada reutiliza evidência válida e trata só o
delta; não reinicia auditoria nem reimplementa código por `pending-verification`.

No checkpoint, separar Front-end, Back-end Supabase, Back-end Cloudflare e
prova integrada. Informar commits, testes com quantidade/resultado, primeiro
gate aberto e ETA. Declarar conclusão do recorte quando seus gates estiverem comprovados, com
segredos ausentes e evidências preservadas. Commit, merge e deploy são etapas
separadas quando solicitadas; mudanças alheias não bloqueiam relatar uma
correção local verificada. Não confundir isso com integração ou publicação.
