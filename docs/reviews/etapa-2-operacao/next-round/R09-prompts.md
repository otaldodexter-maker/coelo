---
source: R08-fechamento; R09-plano; handoffs G0-G8; orientação do Owner de 2026-09-12 sobre CRUD real, Astra médio e consumo
status: prompts-preparados-nao-iniciados
generated_at: 2026-09-12
---

# R09 — prompts preparados: CRUD real, Astra médio e consumo limitado

## Como usar e abrir a rodada

Pacote revisado por pedido do Owner de 12/09/2026: avançar em todas as frentes,
priorizando app utilizável, CRUD real, RLS e hierarquia. Todos os papéis C0/G0–G8
usam **GPT-6 Astra, esforço médio** (`gpt-6-astra`, `medium`). Preparar estes
prompts não inicia a rodada. O envio do prompt de abertura abaixo ao coordenador
autoriza a janela nele descrita; não iniciar R10 automaticamente.

Copiar primeiro o prompt C0. As frentes existentes são reutilizadas pelo C0,
com modelo/esforço explicitamente ajustados e sem criar tarefas duplicadas.
Os prompts individuais ao fim também podem ser enviados pelo Owner.

```text
Abra a R09 do Coelo como C0, GPT-6 Astra, esforço médio. Autorizo até quatro
horas de execução a partir do T0 real, mais até trinta minutos de fechamento,
com encerramento antecipado obrigatório pelos limites de consumo do protocolo.
Não iniciar R10. Reutilize as tarefas G0–G8 existentes e envie a todas os prompts
individuais, com modelo gpt-6-astra e esforço medium; ative por vagas, sem
duplicar tarefas. Todas as frentes participam, mas não precisam rodar juntas.

Em C:/Users/adrie/Documents/Coelo faça git fetch origin e leia com git show
origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md integralmente.
Siga o Contrato comum, o controle de consumo e a seção C0. Leia AGENTS.md e as
skills canônicas indicadas. Nunca edite nem dê pull no checkout principal.
Reconcilie worktrees e escritor vigente; use
C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-coordenacao na branch
work/etapa2-r09-coordenacao a partir de origin/dev, criando só se não existir,
sem sobrescrever WIP. Publique posse e IDs antes de liberar escrita.

O resultado principal é CRUD utilizável na rota normal, persistência no Supabase
real, reload, negativa RLS e hierarquia server-side. Feche ações por evidência;
não passe a rodada só em auditorias, API sem consumidor, goldens ou recibos.
Meça FE, BE e E2E separadamente. Se não houver fechamento, intervenha conforme
o protocolo. Integre, teste, atualize inventário e três MDs e publique dev.
Reserve consumo para a entrega final. Preserve worktrees, branches e ignorados.
```

## Controle de consumo e entregas

Snapshot preparatório: bucket Codex semanal com 49% usados, 51% restantes.
C0 consulta novamente na abertura e a cada checkpoint de dez minutos; somente
C0 consulta a cota. O limite é compartilhado pela conta e não corresponde a
uma quantidade fixa de tokens ou horas. Não somar buckets nem contar com reset,
crédito, reserva de outro modelo ou execução contínua garantida.

- Até 70% usados: no máximo C0 + três executoras ativas. Uma vaga para runtime
  ou backend quando bloquearem consumidor; demais para fatias de produto.
- A partir de 70%: C0 + uma executora, apenas terminar fatias já próximas do
  aceite. Não abrir novas tarefas, auditorias amplas ou censo dispendioso.
- A partir de 75%: iniciar fechamento antecipado de todas as frentes; nenhuma
  nova fatia. Commit/push do trabalho revisável, WIP identificado, integrar e
  validar. Meta de encerrar até 85% usados, preservando 15% da conta.
- Antes desses marcos, antecipar o fechamento se a taxa medida de consumo
  projetar atingir 85% antes de concluir a integração. Usar o maior ritmo das
  duas últimas amostras, sem tratá-lo como garantia. Salto de consumo, cota
  indisponível ou limitação da sessão exige reduzir atividade e preservar o
  checkpoint; nunca gastar o restante esperando alcançar um percentual.
- Corte efetivo: o primeiro entre corte de tempo e corte por consumo. Não
  consumir a reserva tentando cumprir quatro horas. Consultas de outros chats
  podem consumir a margem; explicar isso se afetar a entrega.

Todas as nove frentes têm dono e fila. C0 faz rodízio das vagas, garantindo a
cada frente de produto uma primeira fatia antes de oferecer a terceira fatia
a outra, salvo desbloqueio comum indispensável. A fila de espera não faz polling
nem releituras: entrega checkpoint curto e aguarda follow-up de C0.
Não confundir espera planejada por consumo com abandono da frente.

Referência de ambição do Owner: avanço de 6–10 pontos percentuais nas camadas
de conclusão em uma rodada produtiva. Na base R08, atingir pelo menos +6 p.p.
exigiria +14 FE verified, +14 BE done e +12 E2E; +10 p.p. exigiria +24/+23/+20.
São metas de planejamento, não promessa, quota de certificação nem autorização
para reduzir critérios. C0 seleciona IDs candidatos distintos e estima depois
de inspecionar os gates. Um BE já done não gera novo avanço BE ao fechar E2E.
Os sete indicadores continuam separados; não forçar crescimento de SQL/visual
sem necessidade nem de local-green, cujo denominador muda quando ações fecham.

Unidade de execução: uma fatia coerente de CRUD por frente, com ações canônicas
existentes. Cada fatia percorre implementação → teste focal → integração →
aplicação autorizada quando necessária → rota normal → reload → delta de aceite.
Operações de excluir/revogar só quando fizerem parte do contrato; usar sintéticos
próprios, sem limpeza geral ou remoção dos recursos retidos da R08.

Reusar leitura e evidência válidas; C0 lê os três rastreadores completos uma vez,
executores leem cabeçalhos, IDs e dependências do próprio recorte. Retomadas leem
apenas mudanças desde a revisão conhecida. Cada frente mantém um JSON, um handoff,
deltas e provas mínimas em arquivos commitados; não criar recibos de recibos,
novos censos ou resumos repetidos. Checkpoint em até seis linhas: ações, mudou,
prova P/F, aberto/dono, commits, próximo gate. Atualização documental necessária
acompanha o código; não conta como avanço funcional.

## Contrato comum obrigatório

R09 permanece exclusivamente na Etapa 2. A ADR 0035 registra a futura Etapa 3
do MVP (acesso temporal/afastamento contextual, tour, home IA, Admin/Principal),
sem autorizar implementação, SQL ou deploy agora. Não puxar esse escopo para
esta rodada; a abertura futura exige proposta após revisar todas as entregas.

Este pacote prepara a rodada; a execução só começa com envio do prompt de
abertura pelo Owner e T0/janela registrados por C0. Não prolongar R08.

Ler AGENTS.md e skills canônicas /rtk, /ponytail, coelo-backend, coelo-frontend,
coelo-frontend-backend e coelo-knowledge; coelo-ui governa visual. Não reconfigurar
ferramentas globais para eliminar avisos. Fazer fetch origin e ler de origin/dev
o fechamento R08, plano/backlog/prompts R09, comunicação/inventário/rastreadores
no recorte devido. Checkout principal nunca é editado nem recebe pull.

Reconciliar trabalho existente antes de criar isolamento; sem sobrescrever WIP.
C0 define branch/worktree/dono de integração e publica posse. Reutilizar tarefas
sem duplicatas. Exclusivos C0: dev, inventário, três rastreadores, decisões finais,
filaSQL/deploy/composição. Executores propõem deltas nos próprios handoffs.
Cada ação identifica apps/superadmin → menu → tela/subtela/estado → action_id.

Um Chrome e um flutter test globais com posse; trabalho local independente
não espera runtime. E2E só após runtime medido; SQL só após espelho/pgTAP.
Não aplicar/reaplicar lotes56–59; próximo60 confirmado antes da nova fila.
Segredos nunca entram em arquivo público, log, URL ou bundle. Preservar dados
sintéticos até fim formal Etapa2; logout scope=local, sem afetar outras sessões.

G0–G8 participam de todo ciclo. JSON por revisão/relógio real, ACK20min,
commit/push próprio e feito/pendente/commits30min. Gate concluído: próxima fatia
autorizada; gate bloqueado: registrar e continuar trabalho independente.
Não encerrar apenas após relatório se houver gate executável. Não repetir
testes verdes sem delta material ou verificação obrigatória integrada.

Aprovação visual/local-green/API não vira verified/done/E2E. Preservar
certificados históricos com limites; concluir ação exige rota normal,
persistência real, negativa de tenant e reload. Sem senha/histórico de
credenciais/endurecimento amplo; controles obrigatórios permanecem.
Revisão/fechamento no corte de C0, WIP/ignorados identificados, branches e
worktrees preservadas. Não gastar esta rodada com remoção/restauração de worktrees.

Hierarquia não é endurecimento opcional: instituição → unidade → turma;
atividade vinculada a uma ou mais turmas, nunca solta. Ator, capacidade,
ownership e contexto são validados no servidor. Provar caminho permitido e
negação de contexto/hierarquia; esconder botão não satisfaz autorização.
Aplicar a régua MVP vigente da ADR 0034, inclusive reutilização de prova RLS da
mesma família/contrato quando válida. Não inventar segunda sessão por ação ou
golden exaustivo como condição nova, nem chamar mesma instituição de cross-tenant.
Prova local não substitui negativa real exigida pelo contrato vigente.

## C0 — coordenação

Ao receber abertura do Owner, registrar T0 real, duração/corte autorizados,
revisão monotônica, tarefas G0–G8 e posse exclusiva; publicar dev antes de liberar.
Heartbeat10min com encerramento no corte. Reconciliar estado realR08:
SQL59 aplicado/flagtrue; APIAvaliações completa; imagemresposta download completo.
Ler inventário e três rastreadores completos. Integrar por conteúdo e testar base
conjunta; apply-tracker-delta.cjs/validate-trackers.cjs; push HEAD:dev semforce.
Backup/pgTAP/preflight/aplicação/ledger/ordem/composição/deploy só pela coordenação.
Fechar sete percentuais, testes reais/limites, memória, dados/chaves, WIP e remoto.

Você é integrador técnico e responsável pelo resultado funcional. Quando uma
frente empacar, reproduza o bloqueio, resolva a dependência compartilhada ou
redistribua o pacote com arquivos e dono explícitos; não apenas cobre status.

1. Abertura: medir cota e runtime e montar fila por action_id com primeiro gate,
   dependência, dono, prova restante e estimativa inspecionada. Reutilizar IDs
   das tarefas via list_threads/read_thread; verificar também arquivadas se
   faltar uma. Não confiar só no título. Ler nove JSONs por branch atual.
2. Primeiros 30 minutos: G0 mede login/leitura/reload pelo canal permitido;
   G5 prepara prova de autorização dos consumidores escolhidos. G1/G2/G3/G4/
   G6/G7 entram por vagas com trabalho executável. Se login falhar após duas
   tentativas diferentes, C0 assume decisão técnica no mesmo checkpoint.
   Testar canal suportado alternativo ou corrigir causa com G0; sem contornar
   bloqueios de ferramentas, injetar sessão para certificar login ou enfraquecer
   Auth. Não deixar nove frentes repetirem o diagnóstico.
3. Cada 10 minutos: relógio/cota/recursos/status compacto. Cada 20: ACK somente
   revisões novas dos nove canais. Cada 30: merge dos pacotes prontos, validação
   focal na base integrada, deltas e push HEAD:dev. Gate terminado antes do ciclo
   segue imediatamente para integração/prova se houver recurso, sem esperar timer.
4. Em 45 minutos sem fechar nenhum gate executável: reavaliar o caminho crítico,
   suspender trabalho secundário e atribuir uma correção concreta. Em 60 minutos
   sem nenhum novo aceite FE/BE/E2E: informar falha da estratégia e mudar a
   alocação; não repetir a mesma hora de atividade nem certificar por pressão.
   Backend pode fechar seu aceite sem UI quando seus próprios gates estiverem
   atendidos. Local-green permanece quando faltar prova; registrar causa exata.
5. Runtime/SQL/browser têm fila com dono, PID, horário e expiração. Um Chrome
   e um flutter test globais. Não encerrar processo alheio. Censo completo só
   quando não atrasar as provas focais e couber na reserva; não bloqueia CRUD
   por dívida histórica não relacionada. Regressões introduzidas são corrigidas.
6. Nenhum pacote pronto pode ficar esquecido por um ciclo: integrar, devolver
   com falha concreta ou registrar bloqueio e dono. Uma Edge Function/RPC
   compartilhada tem autor único; G5 apoia por atribuição, não edita em paralelo.
7. SQL: confirmar próximo lote (60 na R08), espelho na ordem real, pgTAP e
   regressões dos consumidores. Fazer dump lógico antes de cada lote, fora do
   Git, conforme dispensa de PITR da ADR 0034 Decisão 8 enquanto aplicável.
   Preflight verde precede aplicação forward-only; ALTER TYPE ADD VALUE em
   transação separada; ledger, mover candidato para migrations e registrar
   ordem; depois ligar composição e provar consumidor. Sem espelho, sem SQL.
   Conferir objeto/versão antes de retomar lote interrompido. Nunca reaplicar
   56–59 nem ampliar grants para obter teste verde.
8. Fechamento inicia no primeiro corte. Pedir revisão curta (até dez minutos,
   menor se consumo exigir), congelar novas fatias, integrar publicável e
   preservar WIP. Rodar analyze/testes afetados e validate-trackers; memória
   durável pelas skills, sem criar artigo de atividade. Atualizar blocos vigentes
   e linhas afetadas dos três MDs, inventário, pendências e R09-fechamento.
   Comparar heads locais/remotos de todas as frentes; zero commits do recorte
   fora da entrega ou WIP explicitamente identificado. Pausar heartbeat.

Entrega: antes/depois/delta em p.p. nos sete indicadores; IDs de novos aceites
separados de reconciliações; CRUDs demonstráveis por tela e limites; provas e
testes P/F/ignorados/não executados; entregas G0–G8; consumo inicial/final;
remoto final; dados sintéticos/chaves (somente nomes/roteiros, nunca valores);
pendências com primeiro gate e dono. Não declarar Etapa 2 concluída pelo relógio.

## G0 — ambiente/runtime

Medir servidor/browser/RAM/Docker e canal de controle permitido; não presumir
que processos R08 persistam. Resolver primeiro gate do login UI sem contornar
restrições. Preservar uma aba e publicar source/hash/HTTP. Executar espelho de
candidatos novos por SHA e regressões dos consumidores; não reaplicar H28 remoto.
Preparar censo com C0/G8 somente quando couber após gates focais; ambiente-runtime.json.
Seu produto é um runtime utilizável pelos consumidores, não HTTP200 do index.
Entregar primeiro login, leitura autorizada e reload medidos, depois espelho
serializado para SQL. Sem vaga ativa, não subir processos nem repetir diagnóstico.

## G1 — estrutura

Reutilizar configuração833a89d8, períodoc4e38ada e diáriod2c945d8 já criados
pela API R08. Gate de Avaliações: UI/notas/transições pelos comandos reais, com dados
sintéticos e versão atual; não refazer criação nem testes de resume sem mudar
blob d59e17f62. Reutilizar fakeproofG4/guardsG1. Groups.location precisa UI real;
45A não certificam CRUD. Respeitar domínios Estrutura e handoffR08.
Primeira fatia: groups.members e groups.location, ou institutions.status se
inspeção mostrar gate mais próximo. Concluir alteração, releitura e negativas
de hierarquia/escopo. Depois Avaliações: activities.assessment, assessments.entry/
gradebook/detail e transições previstas; nenhuma RPC inventada. Atender todas
as famílias na fila, sem abrir todas as alterações simultaneamente.

## G2 — acessos/pessoas

H28 SQL59/flagtrue e19testesC0 concluídos: gate restante de H28 é UI dos filtros e
reload na base integrada. Reutilizar fixture/44pgTAP, sem nova migration para
o mesmo corpo. Continuar Pessoas/Perfis/Convites pelos IDs pendentes; P51 já
criou usuário e provou link/allowlist. Não repetirAuth nem alterar senha.
Prioridade de fechamento: people.create/edit na UI, depois access-profiles.edit/
assign/delete e access-models.edit/duplicate. H28 é regressão focal incluída
na visita a Pessoas; seus filtros não devem consumir uma rodada inteira.
Não alterar modelo de sistema ou revogar acesso de usuário real para provar CRUD.

## G3 — formulários/cuidado/rotina

Reutilizar form-media21 e cadeias question/answer-image; API download/reload
passou. Provar UI, anônimo e câmera física separadamente; remediar só falhas
reproduzidas. Retomar attendance.mark/correct/finish e forms.location-answer
no primeiro gate real. H19 precisa decisão de elegibilidade; H20 gateway de
dose. H25 mantém residual32/42 em sortestreito; não declararAAglobal.
Primeira fatia attendance.mark/correct/finish: recertificar a tela reconstruída
com dado sintético, persistência e reload. Depois forms.upload/resolve-file e
location-answer. Não bloquear Chamada ou download por câmera física indisponível;
registrar a modalidade não provada sem promover ação que ainda a exija.

## G4 — principal/chat/sistema

Dependência E2E: runtime/login permitido+Chrome nominal. Fila de produto:
Cardápios/Chat → PNG UI/reload/retirada → Perfil/erros. Reutilizar APIs/recursos R08 e correções
Perfil; não repetir revisão câmera ou fake401/resume sem delta. Agora expira
13/09/2026 12:24:39BRT; cron altera estado, não limpa masterR2. H02/H05/H06/H13
seguem perguntas nominais. Negativa QA de mesma instituição não é cross-tenant.
Escolher na abertura a cadeia mais próxima entre Cardápios e chat.create-group/
attach; fechar antes da segunda. Em seguida publicadores/retirada já aplicados,
Perfil e retry contextual. Não refazer API comprovada só porque Chrome está
ocupado; corrigir o consumidor e preparar prova seguinte. Dono de meal_plans,
chat e principal_* exceto principal_circulars; C0 resolve compartilhamentos.

## G5 — realm interno

Apoiar novas fixtures/ACL/RLS e gates de negativas reais. Lote59 final44/44
aplicado; não refazer composição. Preservar v21/atorinterno/TTL/edit_secretnull
e P51 concluídos. SQL somente local por posseG0; fila/deployC0. Revisão de
segurança ampla fora de escopo, mas invariantes de autorização permanecem.
Cada pacote seu nomeia os action_ids e a frente consumidora que desbloqueia.
Primeiro apoiar G1/G2/G3/G4/G6/G7 com fixture válida, negação e hierarquia; fechar
BE pendente por provas dos provedores quando suficiente, sem esperar UI para
o aceite BE. Não reauditar todo RLS nem reescrever funções já verdes. Publicar
assinatura/envelope/capacidade antes do cliente; coordenar autoria com a frente.

## G6 — publicações/agenda

Seis R só após Owner indicar caminho/componente/recorte/rodapé por arquivo.
Preservar A/A+, intercalamento, teto10.000 e provasP50/R06-R08 sem delta.
Gate independente circulars.attach UI3014, com fixture NOVA sintética, autorizada pelo C0, identificada e retida;
não restaurar/recriar/excluir o recurso do incidente sem instrução nominal. Complementar
shell.load/read_at apenas quando houver evento, sem inventar action_id.
Primeira fatia circulars.attach pela UI com R2 privado, persistência, releitura
e autorização; depois gates funcionais abertos de Circulares/Agenda do inventário.
As seis decisões visuais pendentes não paralisam o CRUD independente autorizado.

## G7 — operações

Retomar account.sessions, support, catalog, plans.assign/help_center e estados
informativos pelos IDs abertos. Sessões somente de identidades sintéticas
próprias. Não alterar senha; importação/exportação geral indisponível, salvo
exceção forms.responses.export aprovada. Revisões independentes ajudam C0 sem
editar rastreadores. Inventariar worktrees/WIP sem remover por conta própria.
Priorizar plans.assign se contrato/spec051 resolver o gate; caso haja decisão
aberta, assumir account.sessions na identidade sintética própria e os próximos
IDs executáveis. Não consumir a fatia com inventário de worktrees ou recertificar
Suporte já fechado. Catálogo só avança com destino e contrato reais identificados.

## G8 — suítes

fase0.json, grupo suites. Com slotC0 e RAM medida, executar primeiro testes
das fatias integradas; censo completo em SHA fixo só se couber no consumo e
não atrasar CRUD, uma execução. Parser preserva IDs/suites/
done/hash/exit/skips/erros e distingue loaders/hooks/colisões. R07 não é R09;
85PASSacessibilidade e19PASSPeople são focais. Corrigir dívida históricaPeople
somente por contrato atual, sem apagar falhas reais ou regravar seisR.
Seu resultado é liberar aceites e detectar regressões reais com o menor conjunto
suficiente. Não escrever features/shared sem transferência nominal; devolver
falha reproduzível à dona e seguir outro teste pertinente. Não abrir servidores
de análise ou lotes duplicados enquanto aguarda vaga. Antes do censo, estimar
duração medida e espaço para fechamento; se não couber, registrar não executado.

## Prompts individuais para as tarefas existentes

Cada bloco é um prompt de retomada completo por referência. O contrato comum
e a seção indicada acima são obrigatórios. C0 ajusta modelo/esforço ao enviar.

### G0

```text
Você é R09 G0 — Ambiente/runtime, GPT-6 Astra, esforço médio. Faça git fetch
origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no checkout principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G0, além de AGENTS.md/skills.
Reutilize esta tarefa; só execute na vaga liberada por C0 e até seu corte de
tempo/consumo. Primeiro login/leitura/reload utilizáveis; depois espelho/pgTAP.
Não contorne bloqueios de ferramenta. Comunicação ambiente-runtime.json, handoff
e branch próprios. Avise imediatamente o gate pronto; não faça polling ocioso.
```

### G1

```text
Você é R09 G1 — Estrutura, GPT-6 Astra, esforço médio. Faça git fetch origin
em C:/Users/adrie/Documents/Coelo; nunca edite/pull no checkout principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G1, AGENTS.md/skills e seus IDs
no backlog. Reutilize tarefa/worktree conforme C0, sem sobrescrever WIP.
Na vaga de C0, feche groups.members/location ou institutions.status pelo gate
mais próximo, depois Avaliações na cadeia existente. Prove CRUD real, reload,
RLS e hierarquia; publique deltas/commits e estrutura.json. Respeite o corte.
```

### G2

```text
Você é R09 G2 — Acessos/Pessoas, GPT-6 Astra, esforço médio. Faça git fetch
origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no checkout principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G2, AGENTS.md/skills e seus IDs
no backlog. Reutilize tarefa/worktree definida por C0. Na vaga liberada, feche
people.create/edit pela UI, depois perfis/modelos/convites executáveis. H28 já
tem SQL59; senha fora. Publique acessos-pessoas.json, provas, deltas e commits.
CRUD inclui persistência, reload, RLS e hierarquia. Respeite corte de consumo.
```

### G3

```text
Você é R09 G3 — Formulários/Cuidado/Rotina, GPT-6 Astra, esforço médio. Faça
git fetch origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G3, AGENTS.md/skills e seus IDs
no backlog. Reutilize tarefa/worktree definida por C0. Na vaga liberada, feche
attendance.mark/correct/finish, depois forms.upload/resolve-file/location-answer.
Reutilize APIs R08 e prove rota normal, persistência, reload e RLS/hierarquia.
Publique formularios-cuidado-rotina.json, provas, deltas e commits até o corte.
```

### G4

```text
Você é R09 G4 — Principal/Chat/Sistema, GPT-6 Astra, esforço médio. Faça git
fetch origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G4, AGENTS.md/skills e seus IDs
no backlog. Na vaga de C0, feche Cardápios ou chat.create-group/attach pelo gate
mais próximo; depois mídia/publicadores e Perfil executáveis. Use worktree
própria definida por C0. Prove UI, persistência, reload e RLS/hierarquia.
Publique principal-chat-sistema.json, provas/deltas/commits; respeite o corte.
```

### G5

```text
Você é R09 G5 — Realm interno/Backend, GPT-6 Astra, esforço médio. Faça git
fetch origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G5, AGENTS.md/skills e backlog.
Na vaga de C0, destrave CRUDs das frentes com contratos, fixtures, RLS e hierarquia;
feche BE pelos gates próprios. Não faça auditoria ampla. Worktree/autoria por
C0; nenhuma aplicação remota sua. Publique realm-interno.json, candidatos,
pgTAP, deltas e commits. Próximo lote é confirmado por C0. Respeite o corte.
```

### G6

```text
Você é R09 G6 — Publicações/Agenda, GPT-6 Astra, esforço médio. Faça git fetch
origin em C:/Users/adrie/Documents/Coelo, sem editar/pull no checkout principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G6, AGENTS.md/skills e seus IDs
no backlog. Na vaga de C0, feche circulars.attach com fixture nova nominal,
rota normal, R2 privado, persistência, reload e RLS; depois funcional restante.
Não restaurar recurso do incidente nem transformar seis R em A. Worktree por
C0; publique publicacoes-agenda.json, provas/deltas/commits até o corte.
```

### G7

```text
Você é R09 G7 — Operações, GPT-6 Astra, esforço médio. Faça git fetch origin
em C:/Users/adrie/Documents/Coelo, sem editar/pull no checkout principal.
Leia por git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md
o Contrato comum, Controle de consumo e seção G7, AGENTS.md/skills e seus IDs
no backlog. Na vaga de C0, feche plans.assign se executável; senão sessões
sintéticas próprias e próximo CRUD autorizado. Catálogo exige destino real.
Não mudar senha nem remover worktrees. Prove persistência, reload e autorização.
Worktree por C0; publique operacoes.json, provas/deltas/commits até o corte.
```

### G8

```text
Você é R09 G8 — Suítes, GPT-6 Astra, esforço médio. Faça git fetch origin em
C:/Users/adrie/Documents/Coelo, sem editar/pull no checkout principal. Leia por
git show origin/dev:docs/reviews/etapa-2-operacao/next-round/R09-prompts.md o
Contrato comum, Controle de consumo e seção G8, AGENTS.md/skills. Reutilize a
tarefa existente, worktree por C0, fase0.json/grupo suites. Com vaga/slot global,
valide fatias integradas e corrija expectativas obsoletas pelo contrato atual.
Censo só se couber após gates focais, sem duplicar lotes. Preserve falhas reais.
Publique provas/commits e libere o slot; respeite corte de tempo e consumo.
```
