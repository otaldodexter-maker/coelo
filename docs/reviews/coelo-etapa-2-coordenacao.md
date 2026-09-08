---
title: "Coelo — Coordenação da Etapa 2"
source: "Conversa Coordenar Etapa 2 do Coelo; seis conversas delegadas; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "active"
generated_at: "2026-09-01"
updated_at: "2026-09-08"
---

# Coelo — Coordenação da Etapa 2

## Operação vigente — E2 R01 C00 (2026-09-08)

Este bloco prevalece operacionalmente. Todo conteúdo abaixo de **Histórico preservado — anterior à R01** retrata rodadas antigas, inclusive números, IDs, owners, autorizações e agendas. Não removê-lo nem utilizá-lo como ordem atual.

- Coordenador: **E2 R01 C00 — Coordenador geral**; ID real `01a0818b-2a34-7fa3-a9aa-f191fc91cc8d`; nome aplicado/verificado via ferramenta nativa. Único escritor/integrador confirmado pela ordem do Owner nesta tarefa; nenhuma transferência.
- Worktree C00: `C:/Users/adrie/Documents/Coelo.worktrees/e2-c00`; branch `codex/e2-r01-c00-integration`. A tarefa nativa ainda tem cwd cadastrado no checkout original; todos os comandos de escrita usam C00 explicitamente. O app não permite à tarefa transferir a si mesma. Não criar outra conversa por esse motivo.
- Baseline original: `84985b5485247df6a8dc7270e33d18601aca0421` (`dev`/origin/dev observado). Base recuperada seletiva: `6cb8ba15bae15f5a6129b0db6e740a66f8f82b3f`. Manifesto local em `etapa-2-operacao/reports/baseline-local-manifest.json` identifica arquivos/herança/hashes. Baseline operacional publicado: `479d1bd1771b13e0cd96084d244fc2cdc6b0e556`; seis worktrees verificadas abaixo.
- 55 arquivos herdados compõem correções aprovadas de skills, governança/visual e ferramentas de índice necessárias, mais reconciliação dos rastreadores. Não são implementação nova de app; correções Tutor/learning/config Claude permanecem somente no checkout original. Relatório de auditoria preservado relata tarefa de origem e não certifica íntegra desse pacote parcial na C00.
- Janela Owner: **08/09/2026 12:20 → 16/09/2026 12:20**, America/Sao_Paulo. Owner confirmou **dev como entrega e localhost ligado diretamente ao Supabase real**. Push de branch R01 é distinto de merge/dev, execução localhost e deploy/produção.
- Preparação `2026-09-08T12:19:18-03:00`: inspeção Git, inventário e instruções; zero ação do produto promovida, zero pacote remoto aplicado. Critério de parada desta preparação: seis worktrees válidas,219 IDs com dono único, protocolo/prompts/automação verificados, ponto de retomada preservado.

### Registro das conversas e ownership

As cinco conversas não foram criadas automaticamente. O Owner abre a sessão na pasta e cola o prompt em `etapa-2-operacao/next-round/R01-CXX-prompt.md`. Primeiro handoff registra ID real/modelo e confirma I001. Não usar IDs das rodadas antigas.

| Executor | Nome exato | IDs | Worktree | Branch | Registro |
|---|---|---|---|---|---|
| C01 | `E2 R01 C01 — Identidade e acesso` | 44 | `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c01` | `codex/e2-r01-c01-identidade` | 01a08197-7b62-73c1-9673-5fd40fa40452; r14 recebido; integração por SHA no estado operacional |
| C02 | `E2 R01 C02 — Forms mídia e cuidado` | 32 | `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c02` | `codex/e2-r01-c02-forms-midia` | 01a0819a-f1f1-7421-95dd-d645ca9f5747; r12 recebido; integração por SHA no estado operacional |
| C03 | `E2 R01 C03 — Operações` | 68 | `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c03` | `codex/e2-r01-c03-operacoes` | 01a0819b-a12e-7110-88cb-99e51a82f384; r3 recebido; integração por SHA no estado operacional |
| C04 | `E2 R01 C04 — Estruturas e pessoas` | 47 | `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c04` | `claude/e2-r01-c04-estruturas` | e0191513-6656-4f3e-a0e8-753dd70bb590; r4 recebido; integração por SHA no estado operacional |
| C05 | `E2 R01 C05 — Comunicação e Principal` | 28 | `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c05` | `claude/e2-r01-c05-comunicacao` | 2a43a349-a639-4be5-aefc-1ff180d1fc7a; r2 recebido; integração por SHA no estado operacional |

### Disponibilidade confirmada — 2026-09-08T12:23:42-03:00

Seis worktrees conferidas pelo Git. C01/C03/C04/C05 partem de `479d1bd1771b13e0cd96084d244fc2cdc6b0e556`; C02 criou previamente a worktree correta em `6cb8ba15bae15f5a6129b0db6e740a66f8f82b3f`, reutilizada sem alterar HEAD durante sessão ativa. C02 lê protocolo/assignment vivos na C00; não precisa merge para começar. C01–C03 foram abertos pelo Owner, não pela C00. IDs reais: C01 `01a08197-7b62-73c1-9673-5fd40fa40452`; C02 `01a0819a-f1f1-7421-95dd-d645ca9f5747`; C03 `01a0819b-a12e-7110-88cb-99e51a82f384`. Nome nativo C02: `E2 R01 C02 — Forms mídia e cuidado`. C04/C05 possuem IDs externos relatados na tabela; não são IDs Codex verificáveis. Mensagem única de disponibilização enviada a C01/C02/C03; não repetir por aviso anterior à criação. Acknowledgement de instrução/handoff ainda não presumido.

### Contagem e última evidência

Inventário vigente:219 IDs únicos/38 famílias;194 ativas,22 adiadas,3 gates, nenhum sem dono/duplicado. FE219 aplicáveis; BE212 aplicáveis e7N/A; E2E187ativas,3gates e22adiadas separados. Auditoria parcial R01:59/219 FE(52/194ativas,7/22adiadas),10/212 contratos BE, dos quais5 IDs com critérios SQL local; remoto0/212,E2E0/187. Certificados FE0/219,BE0/212,E2E0/187, nenhum ID certificado. Números não medem implementação. IDs/critérios/evidências em reports/R01-checkpoint-1330-metricas.json e relatório associado.

Últimas revisões processadas: C01/r14(13:44),C02/r12(13:45:12),C03/r3(13:45),C04/r4(13:42),C05/r2(última evidência12:49). Rastreadores sincronizados até essas revisões. C01r8/10/11/12 integrados e63 testes C00 passam; sequência contínua integrada continua3 porque Convites/Erros/grid aguardam revisão. Catálogo mídia44/44 SQL local; compatibilidade141/143 versus baseline97/99, mesmas2falhas; SQL ainda candidato não integrado. Fila/SHAs/testes e reservas detalhados nas assignments e estado-operacional.json, sem inferir conclusão pelo estado pending-verification.

### Ack inicial C01 — 2026-09-08T12:25:00-03:00

Handoff R01/C01/r1, fonte12:22:29−03:00, recebido/aceito como contrato de abertura; I001 confirmada. Sem commit de código/teste runtime concluído, sem promoção, integrado0. Proposta: investigar reset concorrente com sessão e preparar personas. ETA condicional do primeiro lote: implementação30–60min se reproduzir corrida; testes15–30min após runtime;handoff5–10min; restante44 IDs desconhecido. Os três rastreadores sincronizados a r1 somente para proveniência/planejamento. C02–C05 sem revisão recebida neste snapshot.

### Fila inicial e dependências

1. C02 publica contrato mínimo de mídia/crosswalk cedo; leitura M03 existente já documentada no PROTOCOLO. C04/C05 consomem; C04 publica Locais/IDs/snapshot para C02/C03.
2. C01 trabalha sessão/contratos internos, libera lease auth scope/shell no primeiro lote; C00 controla router/barrels/roots e migrations nominais, sem múltiplos escritores.
3. C02 recupera `f84d1dd7` e `97769124`; C03 recupera view `ca4c82ab`; C04 revisa snapshot `9e689374`. Todos candidatos retidos até prova, não entrega nova. Demais commits em branches antigas podem ter cherry-picks equivalentes; comparar patch-id/diff.
4. `07e6e837` preserva material de benchmark e revisão Eng2 fora de dev; não integrar branch inteira. Consultar evidência Eng2 por `git show 07e6e837:docs/reviews/evidence/etapa-2/engenheiro-2/plano-e-revisoes-2026-09-07.md` se precisar de proveniência; material de marketing fora de escopo.
5. C00 recebe/revisa/testa/integra lotes aptos incrementalmente, publica SHA novo e acknowledgements. C01 lote Auth integrado em2dd5a9bc, pendente entrega dev; C02 R26fd676e2/Forms44465b0c e C03 harnessdb3dd9e9 integrados; fila ampliada por novos handoffs no estado-operacional.json; C01 continuidade integrada em9aa46721/e788c453/7a12addf/7118f7e8. Push origin permitido nas branches nominais; integração em dev autorizada, preservando trabalho original alheio. Nenhum deploy implícito.

### Decisões, reservas, ambiente e ETA

Contradições registradas em `docs/open-questions.md`, seção R01: writers antigos/denominadores/famílias visuais resolvidos pela ordem vigente; Planos e Catálogo requerem crosswalk/evidência; critérios FE não dependem de BE/E2E. Perguntas materiais já abertas: Conta self, perfis globais, Forms/Locais, limite de anexos Chat e contratos clínicos/Suporte. Não pedir aprovação geral que já existe, nem inventar novas políticas.

Reservas e release: PROTOCOLO tabela R01-SHARED-01(C01),R01-MEDIA-01(C02),router/roots/barrels/migrations centrais(C00). Authorizations remotas R01: nenhuma nominal registrada; janela global e localhost real não criam permissão irrestrita de mutação. Personas/cenários preparados em `reports/personas-cenarios.json`, **sem contas Auth/tenants criados**. C00 deve validar pacote/cenário concreto e pedir autorização nominal só quando reviewable; testes mutantes serializados por lease.

Docker: consulta inicial falhou; após o Owner mostrar Engine running, a CLI confirmou Docker Server29.7.2 e `docker ps` vazio com exit0 em 2026-09-08T12:20:45-03:00. Bloqueio de engine removido; C00 executou replay nominal de catálogo,44/44 e compatibilidade sem novas falhas; C03 executou23/23 SQL novos e regressões comparadas, sem remoto. Não resetar dados/WSL/config. Credenciais não foram lidas/copied. Flutter/Dart/Node/Python presentes; localhost produtivo ainda não iniciado por esta preparação.

Primeiros lotes C01 medidos3–10min, sem extrapolar para todos os aceites. C04 estima1,5–2h para inserir seções/campo; demais contratos exigem inspeção. Integração/documentação têm fila ativa; espera externa Auth/produção/capacidade de mídia permanece desconhecida. Espera externa: decisões nominais/produção e runtime local. Caminhos que podem determinar término: Auth/realm039 → gateways/SQL nominais → consumidores/runtime → prova remota/E2E; em paralelo catálogo/transporte de mídia C02 → consumidores C04/C05 e Forms/XLSX. Risco da janela: ainda não quantificável, elevado enquanto ambiente, contratos e primeiros lotes não forem calibrados. Menor mitigação: publicar lote FE verificado, resolver capacidade de imagem e dependências nominais Auth/SQL, e obter fluxo normal completo por frente, sem refazer READs já implementados.

### Agenda nativa e renovação

Heartbeat único ativo/verificado: `e2-r01-c00-acompanhamento-30-min`, anexado ao ID C00, fuso America/Sao_Paulo. Plataforma recusou múltiplos heartbeats por tarefa; consolidado em despertar10min com consulta executores apenas30min. Próximos ticks calculados pela regra: próximo minuto múltiplo de10; `reports/agenda-nativa.json` registra horário calculado/limitação. API de view confirma cartão, mas não retorna nextRunAt: não afirmar execução futura garantida. Eventos08/09:13:00,15:00,17:40;09/09:05:30,06:00,07:40. Atrasos registrados com hora real; estado idempotente em `reports/estado-operacional.json`.

Automação antiga `checkpoint-coelo-rc-40min` foi pausada via ferramenta para remover writer concorrente; `coordena-o-coelo-50min` já estava pausada. ID histórico `etapa-2-acompanhamento-hor-rio` não existe no inventário local atual. Não inventar que está ativo. Nenhuma ponte Codex–Claude disponível: sessões Claude devem registrar mecanismo nativo local e ID no handoff; arquivo não acorda sessão. C01–C03 têm IDs reais registrados; Heartbeat C02 `e2-r01-c02-retomada-30-min` confirmado ACTIVE via view/TOML, intervalo30min; disparo efetivo não comprovado. C04 relatou CronCreate e50dd60a às13/:43, sessão-only/idle-only; não verificável pela C00. C05 ainda sem automação ativada comprovada na última evidência12:49.

Fechamento09/09:05:30 fechar com segurança;06:00 suspender novos lotes; até07:40 entregar feedback/prompts R02 com SHAs/WIP/limites. Remover somente worktrees limpas/sem sessão/preservadas/integração comprovada. Renovação C00 requer transferência explícita e acknowledgement do sucessor, com heartbeat antigo desativado. Nenhuma limpeza ou branch removida nesta preparação.


### Registro cronológico R01 — entradas posteriores prevalecem

### Ack C02/r1 e reserva I002 — 2026-09-08T12:28:13-03:00

Crosswalk recebido, Deno sintético40/40 relatado, sem commit/push/certificação nova. `_shared/r2_s3.ts` e seu teste são o núcleo real usado pelo wrapper Moments; reserva nominal adicionada a C02 para GET limitado/PUT server-side compatíveis. Forms/XLSX ainda usa Storage legado; catálogo/autorização precisam de inspeção, sem criar arquitetura pelo nome da ADR. Instrução I002 publicada. Timestamp r1 futuro corrigível registrado sem aceitar como hora efetiva; usar recibo12:28:13 até próximo handoff. C02 permanece trabalhando independentemente; nova intervenção apenas pela dependência/reserva solicitada.

### Ack C01/r2 — 2026-09-08T12:30:25−03:00

Candidato Auth login/reset reproduzido; SDK sintético10/10 relatado no handoff, sem SHA/push. Mensagem anuncia regressões155/155 e pacote25/25, analyzer ainda ativo; aguardar consolidação no arquivo e revisão de código. Nenhuma ação integralmente auditada/certificada por esse teste focal. Substituição externa da sessão diretamente no SDK continua aberta. Scope/shell devolvidos sem mudança por mensagem; C00 reassume, coelo_auth permanece C01. Pacote C01-AUTH-PERSONAS-v1 recebido: cinco personas, sem necessidade de novo Owner, escopos mínimos e cleanup proposto; conferir catálogo/ledger e transformar em pacote executável antes de pedir autorização nominal.

### Integração C01/r3 — 2026-09-08T12:34:18−03:00

Código1fd7f9ec → C00 2dd5a9bc revisado, sem conflito; 11/11 SDK/remount e25/25 pacote Auth reproduzidos na C00. Origem push10f893a7 confirmada. Rastreadores sincronizados C01/r3,C02/r1; nenhuma promoção de conclusão. R01-SHARED-01 encerrada e devolvida à C00. Dev ainda84985b54 no snapshot, sem deploy. Evidência/limites/tempos em reports/R01-C01-auth-integracao.md.

### Fila C02/r3

C02/r3 fonte12:34:24−03:00 recebida/aceita para revisão, I002 confirmada; código76a34dda (dois arquivos R2) na fila C00, integrado0. Executor relata49/49 Deno+4/4 estáticos Moments; mediaDart45/45; Forms recuperado102/102+DTO15/15 ainda WIP separado; preflight97769124 reproduzido71/71 Pester3.4.0 com mocks, sem runtime real. Timestamp corrigido. Decoder/catálogo/autorização e E2E continuam abertos; sem promoção de ações.

### Recebimento C03/r2

C03/r2 recebida, última evidência12:36:00−03:00: código445ee6e2 corrige apenas toque/rolagem no harness mobile; revisão C00 pendente, integrado0. Executor relata73/73 focais e156 PASS/9 cenários golden FAIL. IDs auditados visualmente: activities.list/create/detail/edit/location; publish/assessment ainda não nominais. Hipótese do C03: masters anteriores a workflow de6 etapas/shell atual; C00 ainda precisa revisar evidências visuais, nenhuma aprovação de golden. Sete IDs mantidos pending-verification; bloqueio visual retém somente fechamento dependente. C03 segue runtime/comandos/Avaliações. Push informado em mensagem1d6fae2f, ainda pendente no texto do handoff; conferir remoto antes de integrar.

### Integração e reservas vigentes — 2026-09-08T12:46:31−03:00

C02/r4 e C03/r2 integrados conforme reports/R01-C02-C03-integracao-1246.md: R249/49+4/4,Forms102/102+DTO15/15 C00; nove goldens Atividades continuam abertos. Baseline de código db3dd9e9. Rastreadores C01/r3,C02/r4,C03/r2; nenhuma promoção. C02 I003 tem dois arquivos SQL nominais de catálogo; C03 I002 dois arquivos de save transacional, todos locais, sem migração histórica/runner/remoto. Escrita R2 comum continua C00; demais mídia C02. Dev ainda aguarda entrega segura, sem deploy.

### Recebimento C01/r5

C01/r5 recebido em12:49:18, fonte12:47:00: Convites7779bbf na fila de revisão visual C00, integrado somente até r3/Auth. Executor relata65PASS/5goldenFAIL, com as mesmas diferenças em baseline anterior (9 imagens); nenhum golden aprovado. IDs invites.list/create auditados parcialmente; READ internal-users.list e access-models.list/filter/detail revalidado107/107 local sem mudança de código. Capturas locais1440 light/dark estão na .dart_tool C01 e precisam inspeção C00 antes de integrar. Próximo lote C01 Erros/Conta; decisões Perfis/personas seguem C00. Nenhuma promoção FE/BE/E2E.

### Checkpoint13:00 vigente

Relatório `etapa-2-operacao/reports/R01-checkpoint-1300.md`; revisões C01r8,C02r6,C03r2,C04r2,C05r2 sincronizadas antes de publicar. Integradas C01r3,C02r4,C03r2; demais em revisão/WIP.41 IDs FE parcialmente auditados,6 contratos BE,zero conclusão promovida. C04 sessão Claude e0191513-6656-4f3e-a0e8-753dd70bb590, CronCreate e50dd60a :13/:43 relatado; C05 harness2a43a349-a639-4be5-aefc-1ff180d1fc7a, loop ainda inativo na última evidência. Não são IDs nativos do Codex. C04/C05 I002 publicadas13:03, confirmação pendente do mecanismo local.

Router/routes/main estão exclusivamente C04 para hunks Locais/CHILD até release; C00 mantém demais contratos. C05 implementação Agora/Notices prossegue sem atualizar masters automaticamente. Classificador Claude recusou update-goldens, sem contorno. C00 prioriza perfil SQL nominal e personas, fila de revisão e entrega segura dev; nenhuma produção nova autorizada. Horário real e limitações estão no relatório.

C01/r8 fonte13:09 recebida antes de publicar: formulário556bedba entregue para revisão,5/5 focais+19/19 regressão parcial anterior; três goldens iguais aoHEAD. Suíte ampla interrompida exit1:211 é progresso, nunca211/211final. Diretório IntrinsicHeight e overlays continuam abertos; nenhuma integração/promoção deste lote.


### Integração e reservas — 2026-09-08T13:54:50-03:00

C01 lotes8/10/11/12 integrados em7118f7e8 com63 testes e analyzer3arquivos. C04 I003 reserva pass-through SuperadminApp e CHILD local; C02 I005 reserva XLSX/download em6arquivos e confirmou13:50. C01 I003 reserva teste de duplicação na rota normal, sem editar router sob C04. Goldens não impedem implementar aceites já aprovados. SQL Locais requer tabela vazia e pode afetar Atividades, revisão cruzada antes de aplicar. Catálogo mídia passou44/44, duas falhas Acontece idênticas ao baseline; recuperação histórica apenas no perfil temporário, sem migration remota. Relatório reports/R01-checkpoint-1330.md.

### Entrega dev verificada — 2026-09-08T13:58:23-03:00

Origin/dev avançou de84985b54 para **0bf9e0398574df9a8dc49c257bba1f586904889b**, junto da branch C00, por push atômico e conferência ls-remote. Trabalho local alheio permaneceu no checkout original dev84985b54; não foi forçado a sincronizar e localhost dessa pasta não foi atualizado. Nenhum apply/deploy manual; produção não verificada. Catálogos/SQL candidatos permanecem fora da entrega. Manifests Formsfe271f95681e10cedb1aa2e89931224229d68f2d preparados depois somente na C00, aguardando handlers. C03 I003 recebeu janela SQL local; C00 aguarda release antes de novo replay.

## Registro R01 — 2026-09-08T14:25:04-03:00

C00 integrou sete lotes C01 até d058aeb7,100+40 testes locais passam; fonte visual canônica e memória409 reconciliadas sem aprovação de golden. Três rastreadores sincronizados até C01r21/C02r17/C03r3/C04r6/C05r2; detalhes/SHAs/limites em `etapa-2-operacao/reports/R01-checkpoint-1400.md`. C03/C01 I004 publicadas por mensagem nativa, C04 I004 disponível na assignment; aguardam ack. C04 root ainda reservado até release explícito. C03 mantém replay local exclusivo; nenhuma nova autorização remota. dev permanece0bf9e039 neste registro.

Isolamento solicitado pelo Owner conferido: seis worktrees R01 e original separados, gitdirs próprios e branches corretas; evidência `R01-worktrees-verificadas.json`. Pasta histórica interna `.worktrees/finalizacao-telas-operacoes` não registrada e resolve original; preservada. C00 cwd nativo ainda original, comandos de escrita usam explicitamente e2-c00. Registro não prova atividade de todas as sessões nem ausência universal de escrita no original.

## Registro R01 — 2026-09-08T14:33:36-03:00

Leitura14:30: C01r22/C02r18/C03r3/C04r6/C05r3; fonte C05 futura14:48 recebida14:31 deve ser corrigida. Auth integrado c5c26477,70 testes C00/analyzer limpo, release I004 aceito. C05 I003 indicador/teste reservado, alvo48 preservado e transporteR2 distinguido de contrato Flutter. Relatório `etapa-2-operacao/reports/R01-checkpoint-1430.md`. Três rastreadores sincronizados sem novas certificações.


Entrega confirmada 2026-09-08T14:35:41-03:00: `origin/dev` e branch C00 em `d4924a2c34eb9cbb90e20caf8d4f90fb0215f9f6` por push atômico fast-forward e ls-remote. Inclui lotes de cliente revistos até Auth r22 e os manifests históricos sem handler de form-export-download; esses manifests não ativam função nem certificam pacote XLSX. Checkout original dev84985b54 preservado; sem deploy ou mutação Supabase/Cloudflare executados por C00. Este registro posterior prevalece sobre estados pending-dev anteriores.


## Avaliações — decisão de preparação local 2026-09-08T14:41:51-03:00

C00 consultou produção em transação read-only: versão20260901182838 tem0 registros no ledger; context_options/closing_queue/validate_students ausentes. Não há prova de aplicação desse candidato; o último timestamp geral20260901200206 não significa uma cadeia contínua. I006 autoriza C03 corrigir somente os três defeitos locais no arquivo candidato existente, preservando fonte3da039be e commits anteriores, sem reparar ledger ou banco remoto. Próxima prova deve usar bytes canônicos do commit corrigido e perfil nominal declarado, removendo derivações TEMP. Aplicação remota futura exige pacote nominal autorizado e forward-only. Resultado I00534/35 é prova local com duas pré-condições derivadas, ainda não candidato canônico aprovado.

## Checkpoint R01 — 15:00 (consolidado 2026-09-08T15:02:23-03:00)

Fonte `etapa-2-operacao/reports/R01-checkpoint-1500.md` e JSON de métricas/IDs/critérios/evidências. C00 único escritor. Sincronizado C01/r24 (14:50), C02/r20 (14:49:32), C03/r5 (recebido14:53), C04/r7 (última evidência14:38), C05/r5 (14:55:16). Deltas pós-r20 C02 recebidos por mensagem estão identificados como ainda não consolidados/testados.

Verificação parcial FE91/219 (83/194ativas,8/22adiadas,0/3gates); BE15/212 (12IDs com SQL local;0runtime remoto), com7N/A. Conclusão FE0/219,BE0/212,E2E0/187: nenhum ID novo certificado, sem percentual de implementação. Testes de uma parte não substituem aceites integrais; pending-verification não significa ausência de implementação.

Lotes C0016052b51/4436174e/aa960d54:61/61 testes; c3ce3127:37/37 diretórios. Analyzer3+4arquivos limpo. Auth r22 e lotes anteriores entregues emdevd4924a2c; próximos pushes por SHA no relatório. Avaliações9f97d80235/35 canônicos no perfilA01, com lint/cadeia ampla/remoto ainda abertos. XLSX55a41PASS/abort, helper14a1→49PASS/abort na fixture lifecycle, resultado globalFAIL; novo patch de fixture e107asserts da fatia seguinte não executados. Nenhum SQL candidato aplicado/integrado por esta medição.

C04 cria Locais no cliente (create_v2 já existe no candidato), edição/persistência/replay restantes; C05 card375 preserva alvo48 e devolve componente central sem alterações. Goldens novos/antigos aguardam revisão nominal. Contrato mínimo de leitura/lifetime publicado; upload/HTTP, decoder, XLSX completo e cenários Auth reais permanecem abertos. Risco da janela8dias elevado, ETA total desconhecida; menor ação: finalizar contrato mínimo de upload/pacote Auth revisável e reduzir fila de integração antes da UI real. Não somar tempos paralelos.


Publicação verificada às2026-09-08T15:04:03-03:00: push atômico + ls-remote confirmaram **origin/dev=e564d33991d41bf9ccd6c56e513469658b64552d**, com os quatro lotes de cliente revistos e este checkpoint. Não inclui candidatos SQL. C00 também estava nesse SHA no push; registro posterior pode avançar só documentação C00. Originaldev84985b54 preservado; nenhum deploy/produção certificado. Este recibo prevalece sobre os estados anteriores de push pendente.

## Histórico preservado — anterior à R01

## Finalidade

Este documento é o índice operacional da Etapa 2. Ele preserva propriedade,
proveniência, checkpoints e handoffs entre conversas. O recorte é exclusivo de
`apps/superadmin` e dos pacotes/backend indispensáveis ao Superadmin. Nenhuma
frente está autorizada a alterar `apps/admin`, `apps/site` ou `apps/principal`.
Não substitui os três rastreadores especializados e não promove `local-green`,
mock ou rota `/dev` para conclusão Flutter, Supabase ou ponta a ponta.

## Progresso estrito de referência

- Projeto estrito `done`: 0/229 unidades.
- Flutter `local-green`: 105/207 ações; Flutter `verified`: 0/207.
- Supabase `local-green`: 3/37 famílias; Supabase `done`: 0/37.
- Integração E2E: 0/202 ações.
- Tempo total usado e ETA geral: não calculáveis até os checkpoints finais das
  seis frentes e a confirmação do orçamento global de coordenação.

## Propriedade por frente

| Frente | Conversa | Propriedade exclusiva ou principal | Integrações compartilhadas |
| --- | --- | --- | --- |
| Comunicação | `01a05db6-b171-7a80-9e07-592e2e08dbe9` | Chat/Conversas, Convites e Comunicações/Avisos | Entrega o núcleo funcional de Chat à superfície Coelo (Principal) do Superadmin; recebe handoff histórico de Chat de Estruturas. |
| Operações | `01a05d88-3187-79a3-9443-218a0c5cb8ae` | Cardápios, Formulários, Agenda, Importações e Planos | Consome o shell Superadmin; não recria cabeçalho mobile. |
| Acessos e Saúde/Cuidado | `01a05d66-fdec-7f31-a4c3-fe7f7654e51b` | Pessoas, Usuários internos, Segurança da criança, Perfis/Modelos, Saúde e Medicação | Auth permanece transversal; não duplica Chat ou shell. |
| Auth | `01a05d37-a36d-7610-b9dc-f8259243ffcd` | Login, sessão, bootstrap, autorização transversal e produção Auth | Testes de rotas de outras features comprovam somente gates Auth. |
| Estruturas | `01a05d2b-d4e4-7a90-95a6-e9a401ab5836` | Instituições, Unidades, Turmas, Atividades, Avaliações e cabeçalho mobile global do Superadmin | Handoff de Chat para Comunicação; `SuperadminShell` é compartilhado por todas as telas Superadmin. |
| Coelo (Principal) | `01a05dce-96ed-7ca3-b3eb-e4701473510b` | Menu/superfícies Acontece, Para Você, Agora, Momentos, Perfil e Circulares dentro do Superadmin | Implementa o launcher e a superfície de Chat desse menu consumindo o núcleo de Comunicação; não altera `apps/principal`. |

## Contratos transversais

### Cabeçalho mobile do Superadmin

- Proprietário: Estruturas.
- Implementação compartilhada: `SuperadminShell`, com base no commit
  `d9232a94`.
- Abrangência: todo `apps/superadmin`.
- As outras frentes validam rotas representativas dentro do shell e registram
  incompatibilidades; não criam cabeçalhos locais concorrentes.
- O menu Coelo (Principal) permanece dentro de `apps/superadmin`; esta etapa não
  materializa nem altera o aplicativo `apps/principal`.

### Chat

- Comunicação mantém domínio, repository, backend, RLS, permissões e fluxo
  funcional compartilhável.
- Coelo (Principal) mantém somente a integração visual e a navegação dentro do
  menu homônimo do Superadmin.
- Estruturas não continua Chat; seu trabalho anterior deve chegar a
  Comunicação por checkpoint recuperável.
- Conclusão exige abrir, listar, enviar, negar acesso indevido, persistir e
  recarregar nos consumidores aplicáveis.

### Arquivos compartilhados e conflitos esperados

- `superadmin_router.dart`: Comunicação, Operações, Acessos, Auth e Estruturas.
- `superadmin_auth_scope.dart`: Auth, Acessos e Estruturas.
- testes de rotas de Chat: Comunicação, Auth e handoff histórico de Estruturas.
- navegação administrativa: Operações e Acessos.
- os três rastreadores: múltiplas frentes, sempre com atualização por
  `action_id`/checkpoint e reconciliação final pelo Coordenador.

## Snapshot recuperável das worktrees

Referência: 2026-09-01, após a redistribuição de Chat/Circulares.

| Frente | Branch | HEAD | Estado observado |
| --- | --- | --- | --- |
| Comunicação | `codex/finalizar-tela-comunicacao` | `1b7fd395` | Integração seletiva materializada em `dev` até `f516be71`; 301/301 testes pós-merge e analyzer global verdes. A branch permanece preservada porque contém históricos excluídos de Circulares e propostas documentais já reconciliadas. |
| Operações | `codex/finalizacao-telas-operacoes` | `84759675` | Worktree limpa; Flutter `/dev` das cinco áreas passou 344/344, mas backend permanece 0/40 E2E e bloqueado por drift/schema. |
| Acessos e Saúde | `codex/accessos-ponta-a-ponta` | `6e56d3e4` | Handoff final recebido; worktree limpa. Sete rotas `/dev`, 152/152 testes críticos e analyzer global verdes; models backend apenas `static-green`, remoto/E2E ausentes. Revisão independente em andamento antes da integração. |
| Auth | `codex/auth-first-local-green` | `36ae7c86` | Worktree limpa no snapshot; produção permanece condicionada aos gates registrados pela frente. |
| Estruturas | `codex/estruturas-superadmin` | `49a52f6e` | Rastreadores e artefatos de migration/modelo por unidade continuam preservados fora do commit final; `.artifacts` permanece fora de Git. |
| Coelo (Principal) | `codex/finalizar-telas-coelo-principal` | `14ff3d50` | Worktree limpa; `momentos.view` fullscreen aprovado em review independente após `008c14c2`, com 38/38 testes e analyzer focado. Circulares é o próximo recorte; backend/E2E seguem abertos. |

## Evidências e referências

- Evidência do inventário de pastas do Coordenador:
  `docs/reviews/evidence/etapa-2/coordenador/`.
- Comunicação preservou nove referências visuais no commit `f6d44af9`.
- Nenhuma referência temporária deve ser considerada preservada somente porque
  permanece no histórico da conversa; deve possuir arquivo estável e manifesto.
- Comunicação concluiu inventário 9/9 no commit `ab484019`, com origem,
  tela/fluxo e SHA-256 em
  `docs/superpowers/specs/assets/2026-09-01-superadmin-communication/manifest.md`.
- Estruturas preservou 15/15 anexos no commit `2eb3985e` e mais três QA no
  checkpoint `c249db2f`, manifestados em
  `docs/reviews/evidence/etapa-2/estruturas-superadmin/README.md`.
- Acessos/Saúde preservou 13/13 anexos no commit `4a8168d4`, manifestados em
  `docs/reviews/evidence/etapa-2/acessos-saude/manifest.md`.
- Operações preservou 30/30 PNGs no commit `86e55dc7`, manifestados em
  `docs/reviews/evidence/etapa-2/operacoes/manifest.md`.
- Coelo (Principal) recuperou 12/12 anexos do histórico local no commit
  `8f89d6d6` e os inventariou com tela/uso/dimensões/SHA-256 no commit
  `cb6fa272`, em
  `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/`. Não há referência
  ausente nem vídeo informado nessa frente.

## Handoffs recebidos

### Auth-first — `36ae7c86`

- Worktree limpa e quatro commits preservados: `ac167623`, `70065ad3`,
  `db712f24` e `36ae7c86`.
- Quatro ações Auth não-MFA propostas como Flutter/backend `local-green`;
  integração continua `blocked-supabase`, MFA permanece `blocked-decision` e
  `fail-closed`.
- Evidências informadas: `coelo_auth` 21/21, foco Superadmin 57/57, replay
  Auth-only pgTAP 29/29 e lifecycle local real completo.
- Produção permaneceu sem mutação. O ledger produtivo não é compatível com uma
  aplicação segura do pacote atual; dump/replay compatível, migration única
  forward-only, URL/redirect e E2E continuam pendentes.
- Diffs dos três rastreadores estão preservados nos commits de documentação e
  aguardam reconciliação central com o código alcançável.
- Verificação fresca do Coordenador: `coelo_auth` passou 21/21 e analyzer sem
  problemas. A regressão ampliada Superadmin terminou com 14 testes vermelhos
  tanto neste worktree (309 verdes) quanto no `dev` de comparação (295 verdes),
  incluindo débitos de rotas e três goldens de Login. Portanto, o resultado não
  caracteriza regressão nova de Auth, mas a integração permanece retida até
  revisão independente e validação pós-cherry-pick.
- O review independente encontrou bypass recovery→rota protegida; o commit
  `f280e291` corrigiu o guard e passou 66/66 Auth/guards/router + 21/21
  `coelo_auth`. O bloqueio crítico local foi removido.
- A branch ainda altera `apps/catalog`, fora do recorte exclusivo Superadmin,
  por quebra de compatibilidade do stream Auth. A frente deve preservar
  compatibilidade/remover esses dois deltas antes da integração.

### Comunicações/Avisos — `ee8d3aff`

- `notices.list` permanece Flutter `local-green` e integração
  `blocked-supabase`; nenhuma promoção foi proposta.
- Evidências informadas: 37/37 testes focados, analyzer e validador visual
  verdes, 20 fixtures coerentes e 13 goldens revisados.
- Produção, RLS, permitido/negado, vínculo revogado, tenant A/B, persistência,
  reload, auditoria e E2E continuam abertos.
- As 45 linhas propostas foram reconciliadas nos rastreadores oficiais no
  commit central `e052493b`; a frente restaurou somente esses três diffs e
  confirmou worktree limpa.
- A revisão de integração reabriu Chat: `principal-chat` pode exibir o launcher
  flutuante dentro da própria tela porque o shell só o ocultava para
  `conversations`. Nove goldens Chat e dois InviteForm também permanecem RED.
  Comunicação deve corrigir/classificar esses gates antes do cherry-pick.
- Os gates foram corrigidos depois: launcher `465482c0`, ordem multi-message/
  pós-envio `78ac0ae8`, goldens `c2396f2a`/`2401282e` e escopo Convites
  `b0dd30a5` + `57b746a5`. Rastreadores promovem somente
  `chat.list/open/send` a Flutter `local-green`; integração continua bloqueada.

### Comunicação — integração seletiva em `dev` até `f516be71`

- **Chat / lista (`chat.list`):** último passo concluído foi integrar busca,
  fixtures e ordenação newest-first; launcher duplicado foi removido. Estado
  Flutter `local-green`; backend/remoto/E2E continuam bloqueados.
- **Chat / conversa aberta (`chat.open`):** último passo concluído foi validar
  2+ mensagens, leitura e sequência visual. Estado Flutter `local-green`;
  persistência/reload remoto não comprovados.
- **Chat / envio (`chat.send`):** último passo concluído foi corrigir a ordem
  pós-envio e validar o fluxo local. Estado Flutter `local-green`; autorização,
  auditoria e E2E remotos não comprovados.
- **Chat / editar, anexar, receipts e revogar:** somente auditados/fail-closed;
  primeiro próximo passo é fechar contrato RPC, mídia, capability e negativos.
- **Convites / diretório, detalhe e formulário:** fixtures `/dev` agora respeitam
  instituição/unidade/turma/busca/limite e rejeitam combinações cross-scope;
  goldens locais passaram. CRUD produtivo, RLS, remoto e E2E seguem abertos.
- **Comunicações/Avisos / diretório e criar-editar:** integração preservou o
  estado Flutter local já registrado; RPCs de gestão e `notice_events` ausentes
  impedem qualquer promoção integrada.
- **Evidência pós-merge:** 301/301 testes focados passaram no `dev`, incluindo
  Chat, Convites, Avisos, rotas, navegação e shell; `flutter analyze` terminou
  sem issues e `git diff --check` ficou verde. Os commits `393fc7ff` (WIP de
  Circulares), `d22a9b3d` (ownership Coelo Principal) e os diffs documentais já
  reconciliados não foram incorporados por esta seleção.
- **Próximo passo:** backend/RLS/remoto somente após classificação e autorização
  nominal do ambiente. ETA ponta a ponta permanece não calculável enquanto
  esses gates externos estiverem abertos.

### Estruturas — `560ce79c`

- Commits preservados: `b0fb1293`, `d9232a94`, `0b20d76a` e `560ce79c`.
- Evidências informadas: analyzer completo sem problemas; 62 testes de
  Atividades/Chat, 18 de Auth/router, seis de adapters e 86 de shell/rotas
  estruturais passaram. Chat aparece somente como regressão/handoff histórico.
- Adapters de Unidades/Turmas não são CRUD produtivo concluído: os RPCs legados
  são people-based e o ator interno permanece bloqueado pela OQ-043.
- Migration e pgTAP de modelos por Unidade continuam não rastreados. O teste
  prevê 31 asserts, mas não houve replay Docker; estado correto é
  `in-progress/local-review`, nunca `local-green`.
- Diffs dos três rastreadores, spec e projeção de dataset estão preservados;
  `.artifacts` permanece fora da entrega. Ao reconciliar, corrigir a referência
  antiga de 12 para 31 asserts sem promover estado.

### Convites — worktree Comunicação em `ee8d3aff`

- Diretório/detalhe e fixtures `/dev` foram corrigidos localmente; importação e
  exportação permanecem placeholders explicitamente indisponíveis.
- Evidências informadas: 46 testes funcionais/responsivos, quatro goldens e 12
  testes de repository passaram; analyzer, validador visual e diff-check verdes.
- Flutter local do diretório/detalhe pode ser proposto como `local-green`, mas
  CRUD/RLS/remoto/E2E continuam abertos e Convites não está concluído ponta a
  ponta.
- `InviteFormPage` conserva overflow preexistente de 45 px em 375 px/200% e
  goldens divergentes; registrar como pendência Flutter explícita.
- Alterações e sete goldens permanecem sem commit na worktree compartilhada e
  não devem ser perdidos durante o checkpoint da frente Comunicação.

### Formulários — `dfca4b5c`

- Diretório, editor, rota de respostas e agendamento recorrente foram
  commitados; a UI separa criar, editar e ver respostas e mantém produção
  fail-closed.
- Evidências informadas: 128/128 testes de Forms, analyzer, validador visual e
  diff-check verdes; goldens do diretório/editor foram regenerados
  deliberadamente e incluídos no commit.
- Estado proposto: Flutter `local-green`; Supabase/remoto/E2E continuam sem
  promoção. Nenhum dos três rastreadores foi editado pela frente.

### Operações — auditoria backend/Supabase

- Auditoria read-only confirmou 0/40 ações E2E no recorte: Agenda 6,
  Planos 5, Cardápios 6, Forms 16 e Importações 7 continuam bloqueadas por
  decisão, schema, implantação ou composição produtiva.
- Há drift não reproduzível no ledger remoto e referências a tabelas de Agenda
  inexistentes; a orientação é não aplicar o tail de migrations em lote.
- Sequência segura proposta: reconciliar drift/replay, ACL/RLS comuns, Forms,
  Importações, Cardápios, Planos após decisão e somente então criar o backend
  novo de Agenda. Nenhuma mutação remota ocorreu.

### Convites — auditoria backend em `64a92497`

- Produção permanece com `UnavailableInviteRepository`; `/dev` usa fixture
  isolada. Não existe `SupabaseInviteRepository` produtivo atual.
- O remoto observado é SELECT-only sobre schema legado, expõe colunas
  sensíveis a `authenticated`, não possui RPCs `superadmin_invite_*` e não
  comprova os hardenings necessários. Nenhuma mutação remota ocorreu.
- Proposta: `invites.list/detail/create/resend/revoke` no máximo Flutter
  `local-green`; Supabase e integração `blocked-decision`/`blocked-supabase`.
  OQ-039, spec 047, provenance do schema, idempotência, versionamento, outbox,
  tenant negativo e E2E permanecem abertos.

### Coelo (Principal) — `0fee7a46`

- Spec 050, plano e conhecimento foram corrigidos para limitar o trabalho ao
  menu dentro de `apps/superadmin`; nenhum diff existe em `apps/admin`,
  `apps/site`, `apps/principal` ou `SuperadminShell`.
- A integração contextual de Chat deverá consumir `ChatRepository` de
  Comunicação; é proibido criar repository, RPC, migration ou widgets de
  domínio duplicados.
- `momentos.view` tem regressão aberta: a rota atual permanece no shell e a
  mídia é limitada por `AspectRatio`/aside, divergindo da experiência
  fullscreen registrada. O `local-green` deve permanecer suspenso até nova
  evidência de viewport, retorno e foco.
- Circulares preserva referências em `f6d44af9`; `d22a9b3d` é candidato a
  integração/revalidação e `393fc7ff` é WIP não integrável sem wiring/teste.

### Coelo (Principal) — Momentos `e1cf1be3`

- **Tela/subtela/action_id:** Momentos, viewer imersivo ready/navegação/
  fechar/Escape/restauração de foco, `momentos.view`.
- **Passo concluído:** viewer movido para rota top-level fullscreen, shell global
  suspenso, retorno contextual e fallback de deep link preservados.
- **Evidência independente:** 28/28 testes focados passaram; analyzer dos quatro
  arquivos afetados não encontrou issues; diff-check e worktree estão limpos.
- **Estado:** Flutter `local-green` preservado, ainda sob review independente;
  nenhum backend, remoto ou E2E foi executado. A referência está em
  `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/momentos-responsive-reference.png`
  e possui SHA-256 no manifesto.
- **Próximo passo:** concluir review; depois revalidar `circulars.view` a partir
  de `d22a9b3d`, sem incorporar o WIP `393fc7ff`. ETA informada: 10–15 min para
  o review de Momentos e 25–35 min para o recorte local de Circulares.
- **Fechamento posterior:** `008c14c2` adicionou saídas seguras também nos
  estados configuração inválida, loading, failure, unauthorized e empty; review
  independente aprovado sem achados. Gate final local: 38/38 testes, analyzer
  focal e diff-check verdes; bookkeeping em `14ff3d50`. O próximo passo agora é
  `circulars.view`/`circulars.file-actions`, ETA local 25–35 min.

### Segurança da criança — `b943a5fe`

- `child-safety.list` corrigiu overflow/alinhamento do grid sem altura rígida;
  card Criar e cards de crianças compartilham altura por linha, inclusive em
  375 px, claro/escuro e texto 200%.
- Evidência informada: 10/10 testes e um golden inspecionado/atualizado. Estado
  máximo proposto é Flutter `local-green`; backend/remoto/E2E não mudam.

### Acessos e Saúde/Cuidado — handoff `6e56d3e4`

- **Pessoas:** diretório/cards/tabela/filtros/paginação e wizard criar/editar/
  vínculos/mapa estão entregues somente em `/dev`; produção preserva leitura
  existente e mutações fail-closed. Importar/exportar, geocodificação real,
  dois testes legados produtivos e dez goldens permanecem abertos.
- **Segurança da criança:** diretório, detalhe, criar, editar e revisar estão
  Flutter local; 164 registros sintéticos coerentes e um golden focado verde.
  Lifecycle sensível, suspensão/revogação, remoto e E2E continuam pendentes.
- **Usuários internos:** diretório e wizard de quatro etapas estão locais;
  rotas produtivas agora falham fechadas em vez de 404. Ponte Auth/Convites,
  RPCs produtivas, import/export e 23 goldens permanecem abertos.
- **Perfis e permissões:** Perfis/Modelos foram unificados visualmente com abas
  Superadmin/Admin/Principal somente dentro do Superadmin; Principal continua
  read-only quando aplicável. OQ-044 bloqueia herança/composição transversal.
- **Modelos de perfil:** adapter Flutter e composição candidata existem. As
  migrations `e7520192` e `5b3c01a3` propõem quatro tabelas FORCE RLS, dez RPCs
  e 18 capabilities; evidência é somente revisão estática com planos 35+10
  asserts, sem replay Docker, Advisors, remoto ou E2E.
- **Perfis de cuidado e Planos de medicação:** diretórios/wizards e CRUD fake
  estão Flutter local. Produção permanece fail-closed por OQ-003/OQ-040 e por
  ausência de backend/RLS comprovado.
- **Gates:** 152/152 testes críticos e analyzer completo foram informados
  verdes; gate funcional Acessos 259/259 e Saúde 127/127. A dívida visual
  permanece explícita: 59 comparações divergentes fora do golden Safety e três
  cenários antigos de Convites; nenhuma atualização em massa foi autorizada.
- **Git/evidência:** branch `codex/accessos-ponta-a-ponta`, HEAD `6e56d3e4`,
  worktree limpa; 13/13 referências preservadas no manifesto. Nenhum arquivo em
  `apps/admin`, `apps/site` ou `apps/principal`. Revisões independentes Flutter
  e banco estão em andamento antes de qualquer cherry-pick.
- **P0 do review Supabase:** as RPCs candidatas de Modelos usam
  `current_person_id()`/`has_platform_permission()`, dependentes de pessoa e
  membership legada. ADR 0019/spec 039 exigem contexto interno Superadmin por
  sessão/realm, ator interno auditável e gateways nominais. Os commits de banco
  ficam bloqueados até correção e negativos cross-app; não integrar como
  closure produtiva.
- Outros achados bloqueantes: lookup de modelo ocorre antes da autorização em
  detalhe/update/delete/duplicate; anti-escalation cobre apenas `platform`;
  motivo não é obrigatório em create/update/duplicate; planos pgTAP 35+10 não
  foram executados; e o replay completo permanece RED por dependência anterior.
  As quatro tabelas são herdadas de `20260811215451`, não criadas por `e7520192`.
- **Review Flutter bloqueou promoção:** 100/100 testes funcionais passaram, mas
  cinco suítes golden terminaram `+1 -13` com diferenças materiais; o handoff
  confundiu capabilities com `action_id` e omitiu ações oficiais abertas.
  `access-profiles.detail`/`access-models.detail` só permanecem por deep link;
  filtro multi-escopo e `totalCount` produtivos estão incorretos; o mapa chama
  tiles públicos OSM sem decisão de provider/cache/privacidade; fixture de 30
  adultos compartilhados pode perder escopo. Nenhuma promoção adicional.
- Estratégia aprovada: integrar primeiro evidências e fixtures por domínio;
  Segurança infantil é a primeira fatia candidata, mantendo suspend pendente.
  Reter Perfis/Modelos, mapa/dependências e os componentes compartilhados até
  correções e regressão conjunta.

### Estruturas — checkpoint `c249db2f`

- Shell mobile, Instituições, Unidades, Turmas, Atividades e Avaliações foram
  decompostos por tela/subtela/action_id no handoff vinculante.
- Avaliações produtivas permanecem fail-closed: os 12 RPCs
  `superadmin_assessment_*` chamados pelo adapter não existem nas migrations.
  O commit `7e702447` preserva esse bloqueio e 4/4 testes de rotas passaram.
- Três diffs antigos dos rastreadores aguardam confirmação de captura central;
  não devem ser descartados até reconciliação. ETA para limpeza local após essa
  confirmação: 2 minutos. Backend produtivo estimado 8–16 h somente após
  OQ-043, contrato v2, Docker e ambiente OQ-041.

## Monitoramento e encerramento

### Retomadas ativas em 2026-09-01

- **Comunicação:** retomou três linhas paralelas: Chat RPC/RLS+adapter/cutover;
  Avisos lifecycle/audience/jobs/receipts+cutover; Convites auditoria das cinco
  decisões OQ-039. Remoto permanece read-only por OQ-041.
- **Operações:** retomou pelo inventário exato de drift e matriz de composição
  produtiva; ordem vinculante é ledger/schema → Auth/capabilities → Planos →
  Cardápios → Forms → Importações → Agenda → E2E/Advisors.
- **Auth:** a frente reportou autorização recebida na própria conversa para o
  menor ajuste fail-closed no Catalog, ETA 30–60 min. Isso ainda não é commit ou
  gate verde; aguardar handoff e verificar que não há expansão adicional.
- **Estruturas:** executa em paralelo gateways internos v2 de
  Instituições/Unidades/Turmas e schema/RPC/RLS de Avaliações. Inventário remoto
  read-only confirmou ledger até `20260821200000`, ausência das migrations v2 e
  ausência das 12 RPCs/tabelas de Avaliações. Os 34 avisos de RLS em
  `app_private` serão primeiro classificados por exposição/grants, sem correção
  cega; remoto continua sem mutação por OQ-041.
- **Coelo (Principal):** Circulares menu/diretório/arquivos fechou localmente em
  `ebc0ac29`/`cb6763ed`/`52735a18`, 21/21 e review aprovado; `393fc7ff` excluído.
  Criar/editar/detalhe/publicar e backend continuam pendentes. Próximo passo é
  Acontece/Publicar agora e Perfil sem seguidores públicos, ETA 35–50 min.
- **Pessoas/detalhe-reload:** `d4a87af8` compôs
  `superadmin_person_detail_v2`; 16/16 testes e analyzer focado verdes. Promoção
  retida até replay pgTAP; Docker instalado, daemon indisponível; remoto sem
  mutação. Lista/criar/editar continuam no legado people-based/fail-closed.
- **Avisos/status:** `c5085746` fail-closed; Notices 96/96, adapter 5/5 e worker
  2/2 verdes. SQL existente auditado estaticamente; replay Docker travou e foi
  interrompido sem resíduos. OQ-038/OQ-041/Storage×R2 bloqueiam.
- **Convites/contrato:** produção Unavailable preservada; auditoria 10/10.
  Migration histórica rejeitada por realm people-based, issuer person e
  backfill especulativo. OQ-039 aguarda decisão Owner+AAL2/issuer interno.
- **Auth/Catalog:** `5e8d2655` concluiu recovery fail-closed; review sem P0/P1,
  corrida P2 corrigida, `coelo_auth` 23/23 e Auth/router 129/129. Falta integrar;
  remoto bloqueado por 17 migrations/infra/identity.
- **Formulários/leitura:** `236f12cd` conectou monitor, respostas, detalhe e jobs
  de arquivo às APIs produtivas; rotas 7/7. Commands criar/editar/publicar/
  testar/responder continuam fail-closed; sem sessão remota/E2E.
- **Instituições v2:** `bd611d02`/`d864f19a` compõem seis gateways internos de
  list/options/detail/edit; Flutter 6/6. PgTAP 20 asserts somente estático por
  Docker indisponível. Create/status, Unidades e Turmas permanecem fail-closed;
  remoto read-only revelou EXECUTE privado antigo ainda não hardenizado.

- Automação horária ativa: `etapa-2-acompanhamento-hor-rio`.
- Cada frente deve enviar checkpoint diretamente ao Coordenador pelo menos uma
  vez por hora, além de reportar conclusão de unidade, bloqueio, regressão,
  mudança de ETA, commit e proximidade de limite/contexto.
- Escrita dos três rastreadores oficiais é centralizada no Coordenador. As
  frentes executoras entregam proposta estruturada por `action_id`/gate,
  evidência, estado, bloqueio e ETA; não criam novas edições concorrentes em
  `coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` ou
  `coelo-flutter-integrado-supabase-pendencias.md`.
- Diffs de rastreadores já existentes em worktrees são preservados e tratados
  como propostas de handoff. O Coordenador valida contra código, testes e
  ambiente antes de incorporá-los à versão canônica.
- Cada relatório deve separar concluído, pendente, bloqueado, Flutter,
  Supabase, E2E, testes, commits, worktree e ETA.
- O campo `Passo` é obrigatório por tela, subtela e `action_id`: cada linha
  registra último passo concluído, passo exato em execução, primeiro próximo
  passo, estados separados Flutter/Supabase local/Supabase remoto/E2E,
  evidência, bloqueio, commit/worktree, arquivos sujos e ETA do passo/unidade.
  Diretório, detalhe, criar, editar, arquivos, filtros e estados loading/vazio/
  erro/acesso negado não podem ser ocultados em um progresso genérico da frente.
- Conversa parada com recorte aberto recebe continuação no primeiro gate
  incompleto.
- Antes de consolidar: exigir checkpoint/commit, diff-check, varredura de
  segredos, rastreadores atualizados e lista de arquivos não rastreados.
- Depois de consolidar: executar regressão conjunta, conferir os três
  rastreadores, validar conhecimento, provar ancestralidade e só então remover
  worktrees/branches autorizadas.
