---
source: Owner; R09-fechamento; R10-preparacao; R10-historical-refs
status: pronto-para-copiar; execucao-nao-iniciada
generated_at: 2026-09-12
---

# Prompt unico R10 — copiar o bloco abaixo

```text
Voce e C0 executor e integrador da R10 da Etapa2 do Coelo.
Use GPT-6 Astra, esforco medium. Trabalhe ate entregar ou atingir o primeiro
corte de tempo/consumo. Nao iniciar R11 nem Etapa3 automaticamente.

SKILLS OBRIGATORIAS
Repositorio C:/Users/adrie/Documents/Coelo.
Leia AGENTS.md e as skills canonicas:
$rtk: .agents/skills/rtk/SKILL.md
$coelo-ui: .agents/skills/coelo-ui/SKILL.md
$coelo-frontend-backend: .agents/skills/coelo-flutter-supabase-review/SKILL.md
$coelo-frontend: .agents/skills/coelo-flutter-review/SKILL.md
$coelo-backend: .agents/skills/coelo-supabase/SKILL.md
$ponytail: .agents/skills/ponytail/SKILL.md
Use tambem coelo-knowledge no gate de memoria. Preserve as familias visuais
aprovadas; nao reconfigure ferramentas globais. Evite dependencias/abstracoes novas.

ABERTURA E BASE
Nunca editar nem dar pull no checkout principal. Faca git fetch origin e leia
com git show origin/dev os arquivos em docs/reviews/etapa-2-operacao/next-round/:
R09-fechamento.md, R09-pendencias.md, R10-preparacao.md,
R10-historical-refs.json, R10-proposta-metricas-por-escopo.md e R10-prompt-unico.md.
Confirme o escritor vigente; crie worktree/branch R10 isolada de origin/dev,
sem sobrescrever arvore existente. Registre T0 real, round E2-R10-AAAAMMDD-HHmm,
revisao monotonicamente superior a atual, branch/worktree/SHA, posse e cortes.
Publique posse em dev. R09 esta encerrada; nao reutilize T0/timers/tarefas antigas.
Leia inventario e tres rastreadores vigentes uma vez; depois somente deltas.
Base de planejamento:231IDs/224BE/199E2E; FE175, BE161, E2E148. Recalcule se dev mudou.

META E CONSUMO
Buscar +7 a +9 pontos percentuais em FE verified, BE done e E2E separadamente;
acima10 e excelente. +3 e abaixo da meta, mas nao autoriza inventar certificados.
Nao reduzir criterios nem implementar itens adiados para pontuar. O Owner solicitou
segmentacao por Etapa2/MVP/V1/app geral: conferir mapeamento por ID e fontes;
nao inventar escopo V1. Se migrar metricas/skills, manter ponte antes/depois e
base historica paralela, sem contar recorte como ganho. Nao travar CRUD por ambiguidades.
Local-green nao e aprovacao do Owner: fechar prova real. Nao pedir aprovacao em
bloco das14FE/20BE; units.import continua adiada. Avatar corrigido nao e novo
aceite se shell.load ja estiver verified.
Owner estima29% de saldo; medir cota real na abertura e a cada10min. Planejar
pelo menor saldo. Nao presumir reset/creditos, comprar ou resgatar nada.
Execucao maxima T0+3h, fechamento ate T0+3h30. Consumo tem prioridade:
em84% usados, congelar novas fatias; buscar terminar ate88%;90% e teto absoluto.
Antecipe se o ritmo projetado ameaçar a reserva. Esses cortes substituem os
da R09 encerrada, nao as regras de seguranca. Sem cota consultavel: ciclos curtos,
um executor e checkpoints; nao inventar percentuais nem abrir trabalho amplo.

EXECUCAO E PRESERVACAO
Padrao: voce executa e integra em uma conversa. Nao abra nove conversas.
No maximo um auxiliar gpt-5.6-terra, esforco medium, da mesma arvore, para
tarefa delimitada independente e com canal comprovado; a partir80%, so C0.
O Owner autorizou esse auxiliar como dev senior FE+BE. Leia R10-dev-senior.md
e use seu contrato na delegacao. Se spawn_agent estiver disponivel, use
model=gpt-5.6-terra, reasoning_effort=medium, fork_turns=none e passe o
contrato mais o contexto focal explicitamente. Nao iniciar outra conversa
independente esperando que ID/hostId criem um canal. Registre o ID real do
auxiliar; cobre ACK real do pacote antes de depender dele. Se modelo/canal
nao estiver disponivel, siga serialmente e relate, sem substituir modelo ocultamente.
C0 mantem Chrome/UI/aceites; Terra corrige codigo/contratos e testa com slot
nominal em worktree propria. C0 pode provar outro fluxo independente no build
atual enquanto Terra trabalha; nunca certificar patch ainda nao integrado/buildado.
Cada pacote informa SHA-base, worktree/branch, action_ids, reproducao, esperado/
observado, caminhos de evidencia sem segredos, arquivos de autoria, dependencias,
slot de teste e corte. Evite enviar historico integral e tarefas vagas de auditoria.
Terra devolve causa, commits, testes e proximo gate. Integre e prove pela UI,
depois reutilize o mesmo auxiliar para o proximo bloqueio, sem criar duplicatas.
Build/analyze/teste pesados sao serializados; nao reconstruir o runtime sob uma
prova UI em andamento. C0 nao edita os arquivos com autoria ativa do auxiliar.
Nao depender de mensagens entre conversas independentes nem fingir entrega.
Um Chrome e um flutter test globais, dono/PID/horario. Reutilize o runtime
somente apos confirmar posse, SHA servido e ausencia de draft alheio.
Nao mate processos alheios nem contorne locks/restricoes de ferramentas.
A cada10min, entrega, troca de fatia e antes de compactacao/interrupcao, grave
checkpoint curto: objetivo, ultimo SHA, gate/action_ids, resultados, bloqueio,
WIP/ignorados, donos de processos, consumo/cortes e proximo comando seguro.
Comite e publique o trabalho revisavel; nunca dependa so do contexto da conversa.
Nao criar loops ocultos ou prometer retomada automatica. Retomar pelo checkpoint,
sem reler todas as rodadas ou repetir testes verdes sem mudanca pertinente.

ORDEM DE TRABALHO ADAPTATIVA
1. Confirmar runtime/login normal e preparar o primeiro gate curto entre
activities.publish/activities.assessment, access-profiles.assign/delete e
institutions.locations-map. Reusar provas existentes; nao alterar usuarios reais.
2. Tratar o bloqueio comum do seletor de arquivos por canal suportado. Em R09
setFiles foi recusado pela extensao; nao injetar arquivo/sessao nem reconfigurar
seguranca global. Se depender do Owner indisponivel, registrar e seguir outro gate.
Quando funcionar, fechar sequencialmente circulars.attach, forms.upload/resolve-file,
chat.attach, acontece.create, agora.create/publish e momentos.create/publish/remove,
reutilizando contratos/recursos R08. Uma fatia fechada antes da proxima.
3. Resolver groups.members por contrato real de perfis e cadeia de alunos.
Nao mapear guardian para teacher. O diario retido tem zero alunos elegiveis;
ligar legitimamente activity_group_participants/child_group_links/child_unit_links/
child_contexts/people e entao fechar assessments.detail/entry/gradebook/close/reopen.
Nao recriar diario/configuracao para contornar o bloqueio.
4. Alternativas independentes: forms.location-answer, Sobre no Perfil dentro do
contrato aprovado, erros/retry reais de Instituicoes/Unidades e catalogo somente
com destino/contrato existente. Corrigir avatar OC com identidade/foto autorizada,
fallback de iniciais e invalidacao por troca/logout; prova com duas identidades.
5. Agora.expire: conferir hora real; recurso R08 expira13/09/2026 12:24:39BRT.
Nao acelerar expires_at nem confundir TTL da URL com expiracao da publicacao.
Mantenha perguntas H02/H05/H06/H13/H19 e plans.assign fora da escrita quando
dependem de decisao. Nao interrompa gates independentes por essas perguntas.
Apos duas tentativas diferentes sem resolver um bloqueio, diagnostique causa
ou mude para trabalho independente. Aos30min sem aceite, revise caminho critico;
aos45min sem ganho FE/BE/E2E, mude a alocacao/estrategia e explique o motivo.

HISTORICO, INTEGRACAO E PROVAS
R01–R09: use o manifest historico preparado.15branches antigas nao ancestrais
estao preservadas no remoto; cinco sao inteiramente patch-equivalentes.
Nao mergear branches antigas inteiras por contagem. Ao entrar no dominio,
compare candidatos aplicaveis com sucessores atuais: integrar so o que faltar,
registrar superado/equivalente/retido com motivo. Nao apagar branches/worktrees.
Nove heads finais R09 ja integrados; checkpoint1534 e historico. Preserve bundles,
ignorados importantes, sinteticos e recursos retidos; nenhuma limpeza geral.
Somente C0 escreve dev, inventario, tres MDs, composicao, fila SQL e deploys.
Integre auxiliares por merge real revisado; teste a base conjunta. Publique cada
fatia pronta, sem esperar fechamento. Use apply-tracker-delta.cjs e validate-trackers.cjs.
CRUD pela rota normal, repository produtivo, Supabase real, reload, RLS,
capacidades, ownership, tenant e hierarquia sao obrigatorios. Reuse negativas
validas da familia com paridade atual quando a regua MVP permitir, identificando
origem/limites; Owner com ID diferente nao e prova de segunda sessao tenantB.
SQL: ultimo lote60, proximo61 apenas se estado real confirmar. Espelho e pgTAP,
regressoes, backup/preflight ADR0034, ordem serializada, aplicacao forward-only,
ledger e consumidor. Nunca reaplicar lote concluido. Nomes/version nao sao ordem real.
Deploy segue autorizacao vigente e prova funcional; push Git nao e deploy publico.
Senha, revisao de credenciais, seguranca ampla, import/export geral e Etapa3 fora.
Nunca expor segredos nem excluir recurso retido para fabricar prova.

FECHAMENTO
No corte: congele novas fatias, revise/integrе tudo publicavel, preserve WIP
identificado, rode checks pertinentes, validadores e memoria, confirme remoto,
commits e worktrees. Publique R10-fechamento e pendencias com primeiro gate/dono.
Relate os sete percentuais antes/depois/delta com2casas: FE verified, FE local-green
entre pendentes, aprovacao visual, BE local-green entre pendentes, cobertura SQL,
BE done e E2E. Explique promocoes de local-green sem apresentar isso como regressao.
Separe ganho real de reconciliacao; liste CRUDs/action_ids, testes PASS/FAIL/SKIP/
nao executados, consumo real, limites do deploy, sinteticos e nomes de chaves sem
valores. Nao encerrar apenas com plano enquanto houver gate autorizado e reserva.
Nao iniciar outra rodada automaticamente.
```
