---
source: inventario-etapa-2.json; R08-fechamento; nove handoffs R08
status: preparado-nao-iniciado
generated_at: 2026-09-12
---

# R09 — backlog de retomada

Base de encerramento R08:231FE/224BE/199E2E ativos;68E2E abertos.
A abertura R09 exige T0/janela do Owner. Reconciliar origin/dev e o fechamento
R08 antes de qualquer ação; não repetir SQL59, provas API ou fixtures concluídas.
Gate bloqueado é registrado; a frente segue no próximo trabalho independente autorizado.

Execução revisada: seguir R09-prompts.md (CRUD real, todos em Astra médio,
vagas em revezamento e fechamento antecipado por consumo). Primeiras fatias:
G1 vínculos/Locais ou status institucional; G2 Pessoas criar/editar; G3 Chamada;
G4 Cardápios ou Chat; G6 anexo Circular; G7 atribuição de plano se executável,
senão sessões próprias. G0 runtime, G5 backend/negativas e G8 testes removem
dependências dessas entregas. Os 68 IDs abaixo continuam abertos: esta mudança
de prioridade não promove nenhum estado nem redefine critérios.

## Ações MVP E2E abertas

| action_id | Dono | FE / BE / E2E | Primeiro gate |
| --- | --- | --- | --- |
| auth.recover | G2 | verified / pending-verification / pending-verification | P51 link/allowlist já provados; senha e recuperação efetiva ficam fora desta entrega. Não repetir criação Auth nem expor link. |
| auth.reset | G2 | verified / pending-verification / pending-verification | Fora da entrega por ordem Owner: correção de senha fica na revisão de segurança; não executar na retomada automática. |
| institutions.status | G1 | pending-verification / pending-verification / pending-verification | R08 G1 — primeiro gate: Usar fixture válida, alterar estado pela UI e reler com negativa de escopo. |
| institutions.files | G1 | pending-verification / pending-verification / pending-verification | R08 G1 — primeiro gate: Exercitar gateway de arquivos autorizado, MIME/limites, persistência e reautorização. |
| institutions.error | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.access-denied | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.locations-map | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provar seleção/associação de Local autorizado, mapa/detalhe e reload; alias locations.detail-links não cria ID. |
| units.error | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| units.access-denied | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| groups.members | G1 | local-green / local-green / pending-verification | R08 G1 — primeiro gate: Adicionar/remover vínculo sintético de turma pela rota real e reler; negar contexto cruzado. |
| groups.location | G1 | local-green / local-green / pending-verification | R08 G1 — primeiro gate: Selecionar Local válido e autorizado na turma, persistir e reler. |
| people.create | G2 | local-green / done / pending-verification | R08 G2 — primeiro gate: Criar pela tela com resolvedor170700 já aplicado; @ e reload; goldenA não prova CRUD. |
| people.edit | G2 | local-green / done / pending-verification | R08 G2 — primeiro gate: Editar dados/@ com disponibilidade/cooldown real; manter prova backend válida e medir nova UI. |
| access-profiles.edit | G2 | verified / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-profiles.assign | G2 | pending-verification / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-profiles.delete | G2 | pending-verification / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-models.edit | G2 | local-green / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-models.duplicate | G2 | pending-verification / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| invites.resend | G2 | pending-verification / done / pending-verification | R08 G2 — primeiro gate: Preparar convite expirado seguro com G5; reenviar e comprovar recibo sem expor link. |
| activities.list | G1 | verified / local-green / pending-verification | R08 G1 — primeiro gate: Completar prova backend da leitura real/destinatário; P53A apenas visual. |
| activities.publish | G1 | local-green / done / pending-verification | R08 G1 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| activities.assessment | G1 | pending-verification / local-green / pending-verification | Configuração833a89d8 ativa v2 já criada por API; reutilizar período aberto e provar UI/reload, sem nova configuração. |
| assessments.entry | G1 | local-green / local-green / pending-verification | Usar diário d2c945d8 draft v1 e período c4e38ada; preparar lançamento de nota sintética pela rota normal e negativa real, sem recriar cadeia. |
| assessments.gradebook | G1 | pending-verification / local-green / pending-verification | Reutilizar diário d2c945d8; provar UI/nota/reload/negação; API de criação/releitura já passou. |
| assessments.close | G1 | pending-verification / local-green / pending-verification | Comandos reais submit/review/return/publish: alinhar transição da ação antes de executar no diário retido, com contexto e versão atuais. |
| assessments.reopen | G1 | pending-verification / local-green / pending-verification | Mapear retorno/reabertura aos comandos reais e regra vigente; reutilizar diário retido, sem inventar RPC close/reopen. |
| assessments.detail | G1 | pending-verification / local-green / pending-verification | R08 G1 — primeiro gate: Executar assessments.detail com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| attendance.mark | G3 | local-green / done / pending-verification | R08 G3 — primeiro gate: Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| attendance.correct | G3 | local-green / done / pending-verification | R08 G3 — primeiro gate: Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| attendance.finish | G3 | local-green / done / pending-verification | R08 G3 — primeiro gate: Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| chat.create-group | G4 | verified / done / pending-verification | R08 G4 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| chat.attach | G4 | local-green / local-green / pending-verification | R08: consumidor Flutter e cadeia API prepare/PUT/finalize/read concluidos; proximo gate e UI/reload/negativa real na mesma composicao, sem recriar catalogo/Edge. |
| forms.location-answer | G3 | local-green / pending-verification / pending-verification | R08 G3 — primeiro gate: Ocorrência nova com item Local publicado; responder/persistir/reload; decisão ADR9/12 resolvida. |
| forms.upload | G3 | local-green / local-green / pending-verification | Question-image e answer-image API/R2 já passaram; provar upload pela UI, câmera física e fluxo anônimo separadamente. |
| forms.resolve-file | G3 | local-green / local-green / pending-verification | Download autorizado200/reload da mesma resposta já passou viaAPI; falta UI/reabertura e negativa real, sem novo upload redundante. |
| forms.expire-file | G3 | pending-verification / local-green / pending-verification | R08 G3 — primeiro gate: Provar expirado/negado sem servir arquivo e registrar ciclo de expiração. |
| forms.delete-file | G3 | pending-verification / local-green / pending-verification | R08 G3 — primeiro gate: Provar remoção autorizada, estado do formulário e reconsulta sem órfão acessível. |
| acontece.create | G4 | local-green / done / pending-verification | R08 G4 — primeiro gate: Provar acontece.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.view | G4 | verified / done / pending-verification | R08 G4 — primeiro gate: Provar agora.view na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.create | G4 | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar agora.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.publish | G4 | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Provar agora.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.expire | G4 | pending-verification / local-green / pending-verification | Cron lote56 ativo e executou; fixture392ee49a vence13/09/2026 12:24:39 BRT. Medir estado após prazo natural, sem esperar nem executar agora e sem excluir masterR2. |
| momentos.view | G4 | verified / done / pending-verification | R08 G4 — primeiro gate: Provar momentos.view na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.create | G4 | local-green / local-green / blocked-environment | R08 G4 — primeiro gate: Provar momentos.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.publish | G4 | pending-verification / local-green / pending-verification | R08 G4 — primeiro gate: Provar momentos.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.remove | G4 | pending-verification / local-green / pending-verification | Lote58 e retirada API corrigidos; falta rota normal/reload/negativa real, sem repetir grant. |
| principal.for-you | G4 | verified / blocked-decision / pending-verification | R08 G4 — primeiro gate: Provar leitura/escopo da ponte já aplicada; conciliar CTA de Comunicação H13, não repetir P17/P35. |
| principal.profile-view | G4 | verified / local-green / pending-verification | R08 G4 — primeiro gate: Provar leitura/escopo real do Perfil e retorno no shell. |
| principal.profile-edit | G4 | local-green / blocked-decision / pending-verification | R08: H03 quatro abas ja atendidas; nao reabrir. H02 atualizacao de dado oficial permanece decisao nominal. Primeiro gate executavel: Sobre save/reload real no sujeito/contexto autorizado; correcoes parser/reload locais ja integradas. |
| catalog.list | G7 | verified / pending-verification / pending-verification | R08 G7 — primeiro gate: Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.validate | G7 | verified / pending-verification / pending-verification | R08 G7 — primeiro gate: Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.sync | G7 | verified / pending-verification / pending-verification | R08 G7 — primeiro gate: Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.publish | G7 | pending-verification / pending-verification / pending-verification | R08 G7 — primeiro gate: Medir destino de publicação/hosting real; validate/sync local não equivale a publicação. |
| plans.assign | G7 | pending-verification / pending-verification / pending-verification | R08 G7 — primeiro gate: Resolver R07-PLANO conforme spec051; não confundir com activate=restaurar nem P51SMTP. |
| meal-plans.list | G4 | verified / local-green / local-green | R08 G4 — primeiro gate: Provar meal-plans.list pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.create | G4 | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar meal-plans.create pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.edit | G4 | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar meal-plans.edit pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.publish | G4 | local-green / local-green / pending-verification | R08 G4 — primeiro gate: Provar meal-plans.publish pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| internal-users.create | G2 | local-green / local-green / pending-verification | P51 criaçãoAPI+allowlist+7checks concluídos; provar UI/reload/negativa sem repetir usuário nem alterar senha. |
| internal-users.edit | G2 | local-green / done / pending-verification | R08 G2 — primeiro gate: Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| internal-users.suspend | G2 | pending-verification / local-green / pending-verification | R08 G2 — primeiro gate: Suspender usuário sintético elegível e negar uso da sessão conforme contrato. |
| errors.403 | G4 | verified / pending-verification / pending-verification | R08 G4 — primeiro gate: Provocar errors.403 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.404 | G4 | verified / pending-verification / pending-verification | R08 G4 — primeiro gate: Provocar errors.404 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.409 | G4 | local-green / pending-verification / pending-verification | R08: preservar composicao409 aprovada P26 e conflitos contextuais. Identificar gatilho produtivo especifico antes de requerer nova tela global; nao ha disparador global normal comprovado. |
| errors.500 | G4 | verified / pending-verification / pending-verification | R08: identificar gatilho produtivo especifico antes de nova tela global; nao simular HTTP500 nem apresentar /dev como backend real. |
| errors.503 | G4 | verified / pending-verification / pending-verification | R08 G4 — primeiro gate: Provocar errors.503 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.retry | G4 | verified / pending-verification / pending-verification | R08: provar retry contextual em Momentos: falha transitoria, nova leitura autorizada list_visible_moments e feed/reload. Negacao sem retry. Nao exigir wiring global novo. |
| circulars.attach | G6 | local-green / done / pending-verification | Provar UI3014 com fixture NOVA sintetica, autorizada pelo C0, identificada e retida. Nao restaurar/recriar o recurso do incidente aa9e26a6; ele segue excluido logicamente para auditoria. |

## Gates transversais sem novos IDs

- G0: runtime/login por ferramentas permitidas; mesma topologia e recursos retidos. Não contornar bloqueio CDP.
- G8/C0: testes focais primeiro; censo completo em SHA fixo somente com RAM/slot e consumo suficientes, sem atrasar CRUD/fechamento; não confundir R07 com resultado R09.
- H28 people.list: SQL59 aplicado, flagtrue e19testesC0; novos filtros ainda precisam UI/reload. Certificado histórico do diretório não é certificado novo dos filtros.
- Seis R Circular: decisão nominal de caminho/componente/recorte/rodapé antes do delta visual.64A/5A+/6R nominais não equivalem a75ações E2E.
- H19/H02/H05/H06/H13: ver R08-perguntas-owner-20260912.md; manter decisões adjacentes já recebidas.
- H20: gateway de imagem de dose; H25: targets sort32/42 em colunas estreitas, sem declaração AA global.
- Dívida de teste: suíte histórica People com assinatura12/permissões antigas, censo completo e falhas R07 ainda não recertificadas.

## Fora do MVP ativo

22adiamentos,5flutter-only,3gates formais e2ações MVP client-only mantêm
classificação do inventário. Importação/exportação geral continua indisponível;
forms.responses.export XLSX é a exceção aprovada. Senha/histórico de credenciais/
endurecimento amplo ficam na revisão de segurança. Preservar controles obrigatórios.
