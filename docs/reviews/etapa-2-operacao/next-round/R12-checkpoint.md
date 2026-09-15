---
source: Owner 2026-09-13 — consolidar R12/R13 como R12, Luna médio, commits e pendências
status: histórico; checkpoint de execução R12; não executar
lifecycle: "historical"
generated_at: 2026-09-13
---

# R12 — Checkpoint inicial consolidado

## Retomada 2026-09-13 21:24 -03:00

Base 967c8a263 = origin/dev após fetch; checkout dev único, stash vazio.
Sessão atual GPT-6 (troca do sistema); bucket normal observado 97%, reserva
Luna 17%; nenhum controle de troca de modelo nesta sessão, sem reset/crédito.
Etapa 2 > apps/superadmin > Cardápios > Modelo/recorrência/publicação:
R12-34–36 corrigidos localmente; calendário Coelo no campo exato do modelo,
cancelar/deduplicar/remover/salvar testados; data/hora enviada como UTC.
Wizard/serialização 58 PASS e analyze limpo. Nome da refeição atualiza título.
Operação > Agenda > Aprovações > agenda.request (R12-42): linha de 64 px,
histórico integral em diálogo; 6 PASS. Estados remotos 22 PASS/1 FAIL,
golden calendário loading dark 375 (194px), ainda sem causa isolada.
Validador visual global: 21 ocorrências, nenhuma nos arquivos alterados.
R12-38: adapter produtivo ainda usa Supabase Storage; migração R2 é trabalho
de implementação pendente, não bloqueio externo presumido. Demais pendências
continuam no catálogo; não foi concluída a R12 nem executado deploy nesta fatia.
Memória: instruções duráveis de subtela/projeção atualizadas nas quatro skills;
sem nova regra de domínio aprovada, sem adicionar documentação de usuário final.

Publicação de código desta retomada: 63f6694e em origin/dev. Preflight novo
21:27 -03: PITR=false, SMTP próprio ausente; R12-47/51 mantêm gates abertos.
Preparação R14 entregue como prompt/plano/catálogo de referência, sem disparo
e sem transferência automática de responsabilidade. R12 continua parcial.
Falha inicial de gate documental (duas fontes unidas em evidenceFiles) corrigida
separando os caminhos na projeção; repetir gate após publicar essa correção.

R12-27 adicional: revisão de perfil usa nomes do catálogo e hierarquia de
módulo/tela/ação, preserva próprias/todas e esclarece acesso efetivo.
17 testes de regressão + 1 teste focal PASS; analyze sem issues. Catálogo
produtivo/traduções e rota real continuam pendentes; nenhum grant alterado.

## R12-24/25 checkpoint de execução (C0)

Em Acessos > Perfis e permissões > Criar/Editar > Permissões, a matriz
compartilhada preserva colunas alinhadas e ações próprias/todas, adaptando-se
para telas estreitas sem recuperar a lista vertical rejeitada. O marcador
repetido Crítico/MFA foi removido; ações sensíveis agora explicam consequência,
MFA e trilha de auditoria por tooltip acessível a semântica, foco, hover e
toque. TDD: teste focal falhou antes e passou depois; 1/1 PASS e analyze limpo.
E2E, catálogo real, rota, reload e negativa cross-tenant continuam pendentes.
Evidência: `docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-permission-sensitivity-r12-24-25.md`.

## R12-20 checkpoint de execução (C0)

Os cards de Perfis/Modelos agora distribuem somente métricas existentes —
Status, Escopo máximo, Vínculos e Tipo — em grade 2×2 responsiva. A quantidade
de registros permanece livre e a composição não inventa uma quarta métrica.
Testes de layout em 375/1440 px com escala 1/2: 4/4 PASS; analyze limpo.
FE local-green, BE inalterado; rota/reload, golden aprovado e negativa
cross-tenant continuam pendentes. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-cards-grid-r12-20.md`.

## R12-21 checkpoint de execução (C0)

No detalhe de Perfis e permissões, o resumo e a lista de permissões configuradas
passaram a usar rótulos de produto para módulo, tela e ação, preservando códigos
técnicos fora do texto principal e mantendo `próprias`/`todas` distintas. A
suíte de páginas de Perfis passou 17/17 e analyze do detalhe ficou limpo; BE
inalterado. Rota normal, reload, golden e negativa cross-tenant seguem como
provas pendentes. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/access-profile-detail-labels-r12-21.md`.

## Retomada final da continuidade — 2026-09-14

Checkout consolidado confirmado em `dev`, sem WIP, stash ou worktree extra;
`dev = origin/dev` em `a019736fbe1cfead7fd1548bd173095e3ddc0886`. A execução
percorreu os 53 registros do catálogo R12: aceites locais implementáveis foram
corrigidos e publicados com evidência; os demais ficaram em seus MDs com
próximo gate, sem simular rota, RLS, SMTP, R2 ou aprovação visual.

Validações de fechamento: `docs/reviews/validate-trackers.cjs` PASS
(`231 actions`, `39 families`, `151 FE`, `159 BE`, `125 E2E`, `199 active E2E`)
e `docs/reviews/delivery_gate.py` PASS DOCUMENTED_PARTIAL. Esses resultados
são reconciliação estrutural/documental, não certificação de runtime.

Gates externos continuam explicitamente abertos: R12-38 requer Media Gateway
R2; R12-46 depende de SQL/contrato de mídia; R12-47 depende de SMTP e redirect
real; R12-48–50 dependem de pgTAP, PITR, backup e ordem; R12-51 confirmou
PITR/backup ausentes; R12-52 aguarda runtime atualizado e prova E2E; R12-53
permanece condicional e não foi declarado. R14 está apenas preparada, sem
execução automática.

## Corte do bucket normal — 13/09/2026 21:32 -03

Uso medido: normal 99%, reserva Luna 17%. Código publicado em 4b74dc67f;
dev=origin/dev, sem WIP/stash/worktree extra, gate PASS DOCUMENTED_PARTIAL.
Solicitação de continuidade/modelo gpt-5.6-luna, esforço médio, aceita pelo
controle do app para esta mesma tarefa 01a09ccb-24e2-7820-9208-8338a980f81d.
Não foi criada tarefa/CLI/supervisor. Confirmar o modelo/bucket no próximo
turno; aceitação do comando não prova que a inferência atual já mudou.
R12 permanece incompleta, com implementação local e provas reais pendentes
nos 53 registros. R14 foi somente preparada, não iniciada.

T0 2026-09-13 19:11 -03:00; modelo/bucket: gpt-5.6-luna, bucket reserva,
17% usado; SHA/base integrada: 8202d3bf8 = origin/dev; sem worktrees extras e
sem stash. Disparo36113ccf cancelado; nenhum executor automático autorizado.

Recorte: Etapa 2 → apps/superadmin → Coelo (Principal) → Conversas → thread →
múltiplas mídias visuais → `chat.attach`. Código R12/R13 já conjunto em dev;
R12-07/41/43 preservados. Primeiro aceite: mosaico local por mensagem,
contador de adicionais e single-media preservado; evidência em
`docs/reviews/evidence/etapa-2/r12-coordenacao/chat-attach-mosaic-r12.md`.

## R12-44 checkpoint de execução (C0)

FE local-green: Convites agora renderiza somente a tabela canônica, sem cards
ou toggle, preservando busca, filtros, paginação, Novo convite e ações por
linha. Testes direcionados 24/24 e goldens compartilhados 14/14 PASS. O
contrato backend permaneceu inalterado; por mudança de superfície o E2E foi
reaberto para pending-verification, aguardando rota normal, reload e negativa
cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/invites-list-table-only-r12.md`.

## R12-45 checkpoint de execução (C0)

FE local-green de descoberta: `Reenviar convite` aparece no menu da linha e
no detalhe expirado quando elegível; pending vigente permanece bloqueado. A
ação preserva `requestId`, `managementVersion`, o RPC v2 e o link somente no
diálogo temporário. Detalhe 32 PASS, repositório 13 PASS e diretório 24 PASS.
O integrado segue pending-verification por falta de convite expirado real,
recibo, reload e negativa cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/invites-resend-discovery-r12.md`.

## Triagem do próximo gate R12-01

Os goldens de Rotina diária falharam apenas com diferenças isoladas no
 cabeçalho global (avatar/ícones/texto), fora do recorte de Modelos. Nenhum
 baseline foi regenerado e nenhum código foi alterado. O bloqueio e a próxima
 comparação autorizada estão registrados em
`docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-golden-diagnostic-r12.md`.

## R12-03 checkpoint de execução (C0)

FE local-green: aba `Modelos de atividade` corrigida no diretório de
Atividades; a aba `Atividades` e os controles existentes permanecem. TDD e
suíte da tela 23/23 PASS. Backend inalterado; integrado pending-verification
até rota normal, reload e escopo. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/activities-list-tabs-r12.md`.

## R12-02 checkpoint de execução (C0)

Duplicar modelo existe em Atividades e foi exercitado pela suíte; Arquivar não
tem callback/contrato no diretório. O status archived lido não autoriza criar
mutação fake. Nenhum código/backend foi alterado; item permanece pendente até
contrato de archive, confirmação, versão, auditoria e reload. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md`.

## R12-04 checkpoint de execução (C0)

O fluxo D7 ainda depende da aba `Lançamentos`; não existe tela/rota separada
de Histórico de chamadas. A remoção imediata quebraria testes e criação/
publicação de lançamento; uma tela nova excederia o recorte sem decisão.
Nenhum código/backend foi alterado. Diagnóstico:
`docs/reviews/evidence/etapa-2/r12-coordenacao/daily-routine-history-diagnostic-r12.md`.

## R12-05 checkpoint de execução (C0)

Nova chamada mantém a cascata de contexto e guards de elegibilidade já
implementadas; `attendance_pages_test.dart` passou 58/58. Nenhum código ou
backend foi alterado. E2E aguarda contexto real, persistência/reload e
negativa cross-tenant. Evidência:
`docs/reviews/evidence/etapa-2/r12-coordenacao/attendance-create-context-r12.md`.
Não interpretar status de processo como avanço do produto.

Feito: FE local-green na composição; 32+21+4 testes PASS e analyze PASS.
Backend sem mudança; E2E continua pending-verification por falta de rota real,
reload, mídia R2/MP4 e negativa cross-tenant.
Commit/push concluído em `3b7446f6fccbd963d42f89abeb117ea81e6975e6`; próximo
passo: preparar prova normal do próximo gate.
