---
source: inventario-etapa-2.json; R09-fechamento; preparacao solicitada pelo Owner
status: planejamento-sem-execucao-r10
generated_at: 2026-09-12
---

# R10 ? local-green e reconciliacao historica

Base68e21e422, FE175/231, BE161/224, E2E148/199. As listas abaixo nao sao
pedidos de aprovacao visual: local-green e teste local, nao aceite completo.
Nao pedir ao Owner que aprove em bloco nem promover BE por aprovacao humana.
Aprovacoes visuais exigem a imagem/estado exatos. units.import e adiada no
backend/E2E; nao implementar importacao para elevar indicador.

## FE:14 acoes local-green

| action_id | FE / BE / E2E | Primeiro gate registrado |
| --- | --- | --- |
| units.import | local-green / deferred-post-mvp / deferred-post-mvp | Diretórios/formulários locais e adapters existentes; detalhe READ possui página/rota/DI com guards D01. Writes não herdam conclusão do detalhe. |
| groups.members | local-green / local-green / pending-verification | R09: consumidor UUID/parser corrigidos e35 testes unicos verdes. UI resolveu pessoa draft (recusada) e depois QA R04 Responsavel9f04...0062 ativo existente; segunda inclusao tambem recusada, grupo1043c165 permanecev2/zero membros. Causa group_save/role guardian pendente C0/G5, sem retry cego/SQL G1; nao E2E. |
| activities.publish | local-green / done / pending-verification | R08 G1 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| assessments.entry | local-green / local-green / pending-verification | R08 G1: cadeia API unica autorizada C0 concluida em35922525b/exit0: configuracao833a89d8 ativa v2, periodoc4e38ada aberto, diariod2c945d8 draft v1, replay e releituras confirmados. Nenhum lancamento de notas ou submit/review/return/publish; UI e negativa cross-tenant real continuam pendentes. Reutilizar os recursos retidos, nao repetir criacao. |
| chat.attach | local-green / local-green / pending-verification | R08: consumidor Flutter e cadeia API prepare/PUT/finalize/read concluidos; proximo gate e UI/reload/negativa real na mesma composicao, sem recriar catalogo/Edge. |
| forms.location-answer | local-green / pending-verification / pending-verification | R08 G3 — primeiro gate: Ocorrência nova com item Local publicado; responder/persistir/reload; decisão ADR9/12 resolvida. |
| forms.upload | local-green / done / pending-verification | R08: cadeia API de imagem de resposta concluida e recursos preservados. Primeiro gate restante: rota normal interativa de Formulario com upload/download/reload e negativa no outro tenant; camera/anonimo nao certificados por API. |
| forms.resolve-file | local-green / done / pending-verification | R09 C0: reautorizacao e TTL de download por API provados parcialmente; G3 ainda precisa download/reabertura pela rota normal com runtime G0 e negativa real de tenant/contrato. API e expiracao do link nao certificam UI nem expiracao do ativo. |
| acontece.create | local-green / done / pending-verification | R08 G4 — primeiro gate: Provar acontece.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.create | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar agora.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.create | local-green / local-green / blocked-environment | R08 G4 — primeiro gate: Provar momentos.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| principal.profile-edit | local-green / blocked-decision / pending-verification | R08: H03 quatro abas ja atendidas; nao reabrir. H02 atualizacao de dado oficial permanece decisao nominal. Primeiro gate executavel: Sobre save/reload real no sujeito/contexto autorizado; correcoes parser/reload locais ja integradas. |
| errors.409 | local-green / pending-verification / pending-verification | R08: preservar composicao409 aprovada P26 e conflitos contextuais. Identificar gatilho produtivo especifico antes de requerer nova tela global; nao ha disparador global normal comprovado. |
| circulars.attach | local-green / done / pending-verification | R09 C0: primeiro gate e permissao Allow access to file URLs da extensao para o seletor real; depois prepare/PUT/finalize/save/read/reload. Mock QA foi tornado opt-in, nenhum novo E2E, BE historico preservado. |

## BE:20 acoes local-green

| action_id | FE / BE / E2E | Primeiro gate registrado |
| --- | --- | --- |
| institutions.error | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.access-denied | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.locations-map | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provar seleção/associação de Local autorizado, mapa/detalhe e reload; alias locations.detail-links não cria ID. |
| units.error | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| units.access-denied | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| groups.members | local-green / local-green / pending-verification | R09: consumidor UUID/parser corrigidos e35 testes unicos verdes. UI resolveu pessoa draft (recusada) e depois QA R04 Responsavel9f04...0062 ativo existente; segunda inclusao tambem recusada, grupo1043c165 permanecev2/zero membros. Causa group_save/role guardian pendente C0/G5, sem retry cego/SQL G1; nao E2E. |
| assessments.entry | local-green / local-green / pending-verification | R08 G1: cadeia API unica autorizada C0 concluida em35922525b/exit0: configuracao833a89d8 ativa v2, periodoc4e38ada aberto, diariod2c945d8 draft v1, replay e releituras confirmados. Nenhum lancamento de notas ou submit/review/return/publish; UI e negativa cross-tenant real continuam pendentes. Reutilizar os recursos retidos, nao repetir criacao. |
| assessments.gradebook | pending-verification / local-green / pending-verification | R08 G1: cadeia API unica autorizada C0 concluida em35922525b/exit0: configuracao833a89d8 ativa v2, periodoc4e38ada aberto, diariod2c945d8 draft v1, replay e releituras confirmados. Nenhum lancamento de notas ou submit/review/return/publish; UI e negativa cross-tenant real continuam pendentes. Reutilizar os recursos retidos, nao repetir criacao. |
| assessments.close | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Executar assessments.close com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.reopen | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Executar assessments.reopen com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.detail | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Executar assessments.detail com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| chat.attach | local-green / local-green / pending-verification | R08: consumidor Flutter e cadeia API prepare/PUT/finalize/read concluidos; proximo gate e UI/reload/negativa real na mesma composicao, sem recriar catalogo/Edge. |
| forms.expire-file | pending-verification / local-green / pending-verification | R08 G3 — primeiro gate: Provar expirado/negado sem servir arquivo e registrar ciclo de expiração. |
| forms.delete-file | pending-verification / local-green / pending-verification | R08 G3 — primeiro gate: Provar remoção autorizada, estado do formulário e reconsulta sem órfão acessível. |
| agora.create | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar agora.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.publish | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Provar agora.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.expire | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Confirmar disparador agendado de expiração, executar prova sintética e reler (H09). |
| momentos.create | local-green / local-green / blocked-environment | R08 G4 — primeiro gate: Provar momentos.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.publish | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Provar momentos.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.remove | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Provar remoção/escopo e reconsulta da publicação com mídia privada. |

## Preservacao R01?R09

Auditoria por refs/handoffs, nao reauditoria de todos os hunks de nove rodadas.
15branches locais nao ancestrais de dev, todas com head identico no remoto.
O manifest R10-historical-refs.json lista commits e equivalencia de patches.
Cinco branches noturnas (formularios-cuidado, import-orfao, operacoes-sistema,
perfil-para-voce, publicacoes-midia) tem todos os patches equivalentes em dev.
As outras dez sao candidatas/historico retido, nao dez funcionalidades ausentes:
sete branches R02, wip/fase0-arquivo-chat, noturna-copia-previa e checkpoint1534.
Patch nao equivalente nao prova ausencia semantica: merges seletivos e sucessores
precisam ser comparados antes de propor qualquer reaplicacao.

R01 tem manifesto de13grupos retidos e bundle preservado; a reconciliacao
R01/R02 ja enumera Auth, Safety, Cardapios, Auditoria, Agenda, Locais e Chat.
R03 preservou91e011dc6 (ARQUIVO/launcher), hoje com sucessores visiveis no
shell R09; rever somente diferencas ainda aplicaveis. R04?R08 possuem
perguntas/handoffs e certificados por action_id no inventario; nao reabrir
aceites ou reaplicar SQL por ler um documento antigo. R09 nove heads finais
estao integrados;24worktrees sem WIP de produto na conferencia119, sem stash.
O checkpoint1534d2ed31572 fica historico; nao reativar tarefas/timers antigos.

Fila funcional atual:51E2E ativos abertos. Residuos concretos: avatar OC,
papeis Membros/cadeia de alunos, Avaliacoes sem aluno, picker de midia,
Sobre somente vazio, catalogo sem destino/contrato, Planos.assign somente
leitura e perguntas H02/H05/H06/H13/H19. Origem historica continua ligada
nas linhas do inventario; nenhuma dessas pendencias desaparece no novo prompt.
Nao executar import/export geral, senha ou Etapa3 para inflar os numeros.

## Estrategia e custo

Uma conversa executora/integradora Astra medium. Evita a fila sem canal de
mensagem observada na R09. No maximo um auxiliar Terra medium da mesma arvore, por tarefa
curta e independente, se a cota real e a ferramenta permitirem; padrao serial.
Nao recriar nove conversas. Um Chrome e um flutter test globais.

Meta7?9p.p. por camada, sem promessa; >10p.p. excelente se houver gates reais.
FE14local-green sozinho nao basta para7p.p.; uma das14 e importacao adiada.
BE20local-green permite no maximo8,93p.p. se todos forem legitimamente aceitos.
Selecionar tambem pendentes implementados; nao confundir estoque intermediario
com conclusao. R09 obteve14FE/12BE/17E2E, custo observado12p.p. de cota.
Extrapolar isso linearmente para R10 seria pouco confiavel: restam bloqueios
mais concentrados. Cota real nesta preparacao69% usada,31% disponivel;
Owner informou cerca29%; usar o menor saldo ao planejar e medir na abertura.

Ordem adaptativa: (1) atividade publicar/avaliacao, acesso atribuir/excluir e
Local institucional; (2) destravar seletor suportado e consumir cadeia R08
para Circular/Forms/Chat/Acontece/Agora/Momentos; (3) contrato Membros e
aluno elegivel para5acoes Avaliacoes; (4) Local de resposta, Perfil Sobre,
erros reais e catalogo com contrato. Avatar OC e correcao pequena incluida,
mas nao conta como novo shell.load se o action_id ja estiver verified.
Executar uma fatia ate publicar, nao manter quatro diagnosticos abertos.

Janela sugerida no prompt: ate3h de execucao +30min fechamento, com corte de
consumo prioritario: nenhuma nova fatia em84% usados; terminar ate88%;
90% e teto absoluto de trabalho, nunca meta. Fechar antes se o ritmo exigir.
Nao usar o teto75% da R09 encerrada para a nova R10, nem gastar todo saldo.
Checkpoint curto commitado a cada10min/entrega e antes de compactacao,
sem depender de lembranca/conversa longa. Sem garantia absoluta contra falha
do host; Git remoto e o registro recuperavel. Nenhum loop/timer oculto.

Ajuste do Owner: C0 Astra medium usa Chrome e integra; auxiliar Terra medium
resolve gargalos FE/BE em worktree propria e responde pelo canal da mesma arvore.
Contrato em R10-dev-senior.md; nao abrir conversa independente sem canal real.
