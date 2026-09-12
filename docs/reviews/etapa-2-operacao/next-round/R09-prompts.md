---
source: R08-fechamento; R09-plano; handoffs G0-G8
status: prompts-preparados-nao-iniciados
generated_at: 2026-09-12
---

# R09 — prompts preparados

## Contrato comum obrigatório

Este pacote prepara a rodada; a execução só começa com abertura explícita do
Owner e T0/janela registrados por C0. Não inventar quatro horas nem prolongar R08.

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
Revisão/fechamento no corte de C0, WIP/ignorados identificados, branches
preservadas. Só C0 remove worktree encerrada, integrada e salvaguardada.

## C0 — coordenação

Ao receber abertura do Owner, registrar T0 real, duração/corte autorizados,
revisão monotônica, tarefas G0–G8 e posse exclusiva; publicar dev antes de liberar.
Heartbeat10min com encerramento no corte. Reconciliar estado realR08:
SQL59 aplicado/flagtrue; APIAvaliações completa; imagemresposta download completo.
Ler inventário e três rastreadores completos. Integrar por conteúdo e testar base
conjunta; apply-tracker-delta.cjs/validate-trackers.cjs; push HEAD:dev semforce.
Backup/pgTAP/preflight/aplicação/ledger/ordem/composição/deploy só pela coordenação.
Fechar sete percentuais, testes reais/limites, memória, dados/chaves, WIP e remoto.

## G0 — ambiente/runtime

Medir servidor/browser/RAM/Docker e canal de controle permitido; não presumir
que processos R08 persistam. Resolver primeiro gate do login UI sem contornar
restrições. Preservar uma aba e publicar source/hash/HTTP. Executar espelho de
candidatos novos por SHA e regressões dos consumidores; não reaplicar H28 remoto.
Preparar censo com C0/G8 na primeira janela útil; ambiente-runtime.json.

## G1 — estrutura

Reutilizar configuração833a89d8, períodoc4e38ada e diáriod2c945d8 já criados
pela API R08. Próximo gate: UI/notas/transições pelos comandos reais, com dados
sintéticos e versão atual; não refazer criação nem testes de resume sem mudar
blob d59e17f62. Reutilizar fakeproofG4/guardsG1. Groups.location precisa UI real;
45A não certificam CRUD. Respeitar domínios Estrutura e handoffR08.

## G2 — acessos/pessoas

H28 SQL59/flagtrue e19testesC0 concluídos: primeiro gate é UI dos filtros e
reload na base integrada. Reutilizar fixture/44pgTAP, sem nova migration para
o mesmo corpo. Continuar Pessoas/Perfis/Convites pelos IDs pendentes; P51 já
criou usuário e provou link/allowlist. Não repetirAuth nem alterar senha.

## G3 — formulários/cuidado/rotina

Reutilizar form-media21 e cadeias question/answer-image; API download/reload
passou. Provar UI, anônimo e câmera física separadamente; remediar só falhas
reproduzidas. Retomar attendance.mark/correct/finish e forms.location-answer
no primeiro gate real. H19 precisa decisão de elegibilidade; H20 gateway de
dose. H25 mantém residual32/42 em sortestreito; não declararAAglobal.

## G4 — principal/chat/sistema

Prioridade: runtime/login permitido+Chrome nominal → PNG UI/reload/retirada
→ Cardápios → Chat → Perfil/erros. Reutilizar APIs/recursos R08 e correções
Perfil; não repetir revisão câmera ou fake401/resume sem delta. Agora expira
13/09/2026 12:24:39BRT; cron altera estado, não limpa masterR2. H02/H05/H06/H13
seguem perguntas nominais. Negativa QA de mesma instituição não é cross-tenant.

## G5 — realm interno

Apoiar novas fixtures/ACL/RLS e gates de negativas reais. Lote59 final44/44
aplicado; não refazer composição. Preservar v21/atorinterno/TTL/edit_secretnull
e P51 concluídos. SQL somente local por posseG0; fila/deployC0. Revisão de
segurança ampla fora de escopo, mas invariantes de autorização permanecem.

## G6 — publicações/agenda

Seis R só após Owner indicar caminho/componente/recorte/rodapé por arquivo.
Preservar A/A+, intercalamento, teto10.000 e provasP50/R06-R08 sem delta.
Gate independente circulars.attach UI3014, com fixture NOVA sintética, autorizada pelo C0, identificada e retida;
não restaurar/recriar/excluir o recurso do incidente sem instrução nominal. Complementar
shell.load/read_at apenas quando houver evento, sem inventar action_id.

## G7 — operações

Retomar account.sessions, support, catalog, plans.assign/help_center e estados
informativos pelos IDs abertos. Sessões somente de identidades sintéticas
próprias. Não alterar senha; importação/exportação geral indisponível, salvo
exceção forms.responses.export aprovada. Revisões independentes ajudam C0 sem
editar rastreadores. Inventariar worktrees/WIP sem remover por conta própria.

## G8 — suítes

fase0.json, grupo suites. Com slotC0 e RAM medida, executar censo completo
em SHA fixo na primeira janela útil, uma execução. Parser preserva IDs/suites/
done/hash/exit/skips/erros e distingue loaders/hooks/colisões. R07 não é R09;
85PASSacessibilidade e19PASSPeople são focais. Corrigir dívida históricaPeople
somente por contrato atual, sem apagar falhas reais ou regravar seisR.
