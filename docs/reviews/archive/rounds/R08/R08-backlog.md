---
title: "R08 — backlog reconciliado da Etapa2"
source: "inventario-etapa-2.json; R07-varredura-r01-r07.md; R07-decisoes-owner-20260912.md"
status: "planejado; nao iniciado"
generated_at: "2026-09-12"
---

# Primeiro gate, dono e escopo

68 ações E2E ativas ainda não certificadas, de199. IDs inalterados:
231FE/224BE; 201ações MVP incluem2client-only. Três gates formais,22adiamentos
e5flutter-only ficam separados abaixo. Cada frente executa primeiro o gate
de sua seção; C0 libera runtime/slot. Matriz não é estimativa por contagem.

## MVP ativo pendente

| action_id | Frente | FE / BE / E2E | Primeiro gate |
| --- | --- | --- | --- |
| auth.recover | G2 | verified / pending-verification / pending-verification | Provar entrega segura/recuperação com QA e expiração do link; P51=B não certifica envio SMTP. |
| auth.reset | G2 | verified / pending-verification / pending-verification | Provar redefinição real e nova sessão, sem registrar token/link em evidência pública. |
| institutions.status | G1 | pending-verification / pending-verification / pending-verification | Usar fixture válida, alterar estado pela UI e reler com negativa de escopo. |
| institutions.files | G1 | pending-verification / pending-verification / pending-verification | Exercitar gateway de arquivos autorizado, MIME/limites, persistência e reautorização. |
| institutions.error | G1 | pending-verification / local-green / pending-verification | Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.access-denied | G1 | pending-verification / local-green / pending-verification | Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| institutions.locations-map | G1 | pending-verification / local-green / pending-verification | Provar seleção/associação de Local autorizado, mapa/detalhe e reload; alias locations.detail-links não cria ID. |
| units.error | G1 | pending-verification / local-green / pending-verification | Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| units.access-denied | G1 | pending-verification / local-green / pending-verification | Provocar falha/negação da ação com contexto válido e verificar ausência de vazamento/retorno. |
| groups.members | G1 | local-green / local-green / pending-verification | Adicionar/remover vínculo sintético de turma pela rota real e reler; negar contexto cruzado. |
| groups.location | G1 | local-green / local-green / pending-verification | Selecionar Local válido e autorizado na turma, persistir e reler. |
| people.create | G2 | local-green / done / pending-verification | Criar pela tela com resolvedor170700 já aplicado; @ e reload; goldenA não prova CRUD. |
| people.edit | G2 | local-green / done / pending-verification | Editar dados/@ com disponibilidade/cooldown real; manter prova backend válida e medir nova UI. |
| access-profiles.edit | G2 | verified / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-profiles.assign | G2 | pending-verification / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-profiles.delete | G2 | pending-verification / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-models.edit | G2 | local-green / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| access-models.duplicate | G2 | pending-verification / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| invites.resend | G2 | pending-verification / done / pending-verification | Preparar convite expirado seguro com G5; reenviar e comprovar recibo sem expor link. |
| activities.list | G1 | verified / local-green / pending-verification | Completar prova backend da leitura real/destinatário; P53A apenas visual. |
| activities.publish | G1 | local-green / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| activities.assessment | G1 | pending-verification / local-green / pending-verification | Salvar/ativar configuração válida e criar período sintético; lote54 já removeu gate. |
| assessments.entry | G1 | local-green / local-green / pending-verification | Executar assessments.entry com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.gradebook | G1 | pending-verification / local-green / pending-verification | Executar assessments.gradebook com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.close | G1 | pending-verification / local-green / pending-verification | Executar assessments.close com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.reopen | G1 | pending-verification / local-green / pending-verification | Executar assessments.reopen com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| assessments.detail | G1 | pending-verification / local-green / pending-verification | Executar assessments.detail com turma/aluno/período sintéticos válidos; lote54 já aplicado; persistência/reload/negação. |
| attendance.mark | G3 | local-green / done / pending-verification | Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| attendance.correct | G3 | local-green / done / pending-verification | Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| attendance.finish | G3 | local-green / done / pending-verification | Recertificar nova CallPage/PublicationSurface por ação; observações375 e CRUD/reload; BE done preservado. |
| chat.create-group | G4 | verified / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| chat.attach | G4 | blocked-environment / local-green / pending-verification | Concluir consumidor Flutter de chat-media já implantada; prepare/PUT/finalize/read e autorização. |
| forms.location-answer | G3 | local-green / pending-verification / pending-verification | Ocorrência nova com item Local publicado; responder/persistir/reload; decisão ADR9/12 resolvida. |
| forms.upload | G3 | pending-verification / local-green / pending-verification | Concluir question-image e fluxo de resposta distintos: upload_url/required_headers, PUT e finalize. |
| forms.resolve-file | G3 | pending-verification / local-green / pending-verification | Ligar consumidor autorizado de mídia e provar reautorização/read em arquivo privado. |
| forms.expire-file | G3 | pending-verification / local-green / pending-verification | Provar expirado/negado sem servir arquivo e registrar ciclo de expiração. |
| forms.delete-file | G3 | pending-verification / local-green / pending-verification | Provar remoção autorizada, estado do formulário e reconsulta sem órfão acessível. |
| acontece.create | G4 | local-green / done / pending-verification | Provar acontece.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.view | G4 | verified / done / pending-verification | Provar agora.view na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.create | G4 | local-green / local-green / pending-verification | Provar agora.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.publish | G4 | pending-verification / local-green / pending-verification | Provar agora.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| agora.expire | G4 | pending-verification / local-green / pending-verification | Confirmar disparador agendado de expiração, executar prova sintética e reler (H09). |
| momentos.view | G4 | verified / done / pending-verification | Provar momentos.view na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.create | G4 | local-green / local-green / blocked-environment | Provar momentos.create na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.publish | G4 | pending-verification / local-green / pending-verification | Provar momentos.publish na tela reconstruída com PNG sintético privado, contexto real e reload; gateway existente não basta. |
| momentos.remove | G4 | pending-verification / local-green / pending-verification | Provar remoção/escopo e reconsulta da publicação com mídia privada. |
| principal.for-you | G4 | verified / blocked-decision / pending-verification | Provar leitura/escopo da ponte já aplicada; conciliar CTA de Comunicação H13, não repetir P17/P35. |
| principal.profile-view | G4 | verified / local-green / pending-verification | Provar leitura/escopo real do Perfil e retorno no shell. |
| principal.profile-edit | G4 | local-green / blocked-decision / pending-verification | Conciliar edição Sobre/dado oficial e abas H02/H03; provar save/reload autorizado. |
| catalog.list | G7 | verified / pending-verification / pending-verification | Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.validate | G7 | verified / pending-verification / pending-verification | Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.sync | G7 | verified / pending-verification / pending-verification | Provar catálogo no contrato/destino produtivo; distinguir validação local, sincronização e hospedagem. |
| catalog.publish | G7 | pending-verification / pending-verification / pending-verification | Medir destino de publicação/hosting real; validate/sync local não equivale a publicação. |
| plans.assign | G7 | pending-verification / pending-verification / pending-verification | Resolver R07-PLANO conforme spec051; não confundir com activate=restaurar nem P51SMTP. |
| meal-plans.list | G4 | verified / local-green / local-green | Provar meal-plans.list pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.create | G4 | local-green / local-green / pending-verification | Provar meal-plans.create pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.edit | G4 | local-green / local-green / pending-verification | Provar meal-plans.edit pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| meal-plans.publish | G4 | local-green / local-green / pending-verification | Provar meal-plans.publish pela UI sobre scopeRules/lote55; não reabrir fail-closed de tenant já removido. |
| internal-users.create | G2 | local-green / local-green / pending-verification | Criar pela UI usando v3, reautorizar hierarquia e provar Auth/identidade/reload; implementar link seguro P51=B se faltar. |
| internal-users.edit | G2 | local-green / done / pending-verification | Executar a ação canônica pela rota normal no contexto QA, conferir autorização, persistência/releitura e evidência da camada ainda pendente. |
| internal-users.suspend | G2 | pending-verification / local-green / pending-verification | Suspender usuário sintético elegível e negar uso da sessão conforme contrato. |
| errors.403 | G4 | verified / pending-verification / pending-verification | Provocar errors.403 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.404 | G4 | verified / pending-verification / pending-verification | Provocar errors.404 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.409 | G4 | local-green / pending-verification / pending-verification | Provocar errors.409 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.500 | G4 | verified / pending-verification / pending-verification | Provocar errors.500 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.503 | G4 | verified / pending-verification / pending-verification | Provocar errors.503 por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| errors.retry | G4 | verified / pending-verification / pending-verification | Provocar errors.retry por rota/erro autorizado real, conferir feedback e retry sem vazar dados; não simular código500 como prova do backend. |
| circulars.attach | G6 | local-green / done / pending-verification | Origem3014 + circular-mediav13:prepare/PUT/finalize/save/read/reload com negativo; nenhum novo deploy genérico. |

## Resíduos históricos e requisitos complementares

Estes itens não acrescentam IDs ao denominador. São subaceites, decisões
ou revisão profunda; estar aqui não apaga uma certificação ainda válida.
H01 foi resolvido pelo C0, mantido para recibo. H19/H20 são pistas a medir.
Decisões visuais já respondidas estão na lista nominal, não voltam ao Owner.

| ID | Origem | Item | Dono | Estado medido / primeiro gate |
| --- | --- | --- | --- | --- |
| H01 | R06 | Credencial QA exposta | C0 | RESOLVIDO: senha de qa-r06-estrutura rotacionada via Auth Admin em12/09T13:06:51Z; login verificado e sessão de prova encerrada204; arquivo privado atualizado. Reutilizar arquivo privado novo; não copiar credencial antiga. |
| H02 | noturna/R01 | Atualizar dado oficial a partir do Sobre | G4 + Owner | ProfileAboutOfficialUpdateRequest tem domínio/testes, sem consumidor produtivo localizado. Conciliar contrato aprovado, conectar ou registrar adiamento; não afirmar implementado. |
| H03 | noturna/R01 | Composição de quatro abas de Perfil | G4 | PrincipalProfileContentTabs sem consumidor produtivo localizado. Comparar composição usada com referência vigente e decidir destino do componente. |
| H04 | noturna/R02/R07 | Compositor antigo de Circular e blocos intercalados | G6 | PrincipalCircularComposerPage só em testes; produção usa SuperadminCircularComposerPage. Owner reafirma perguntas/mídia no meio do texto. Conciliar os dois hosts; implementar/provar na rota normal sem usar golden homônimo como aceite. |
| H05 | noturna/R01 | Denominador histórico de recibos do Chat | G4 + G5 + Owner | SQL considera participantes ativos atuais, sem corte joined_at/data da mensagem. Definir destinatários históricos versus atuais; preservar aceite MVP já existente enquanto não muda contrato. |
| H06 | noturna/R01 | Revogar em Chat somente leitura | G4 + Owner | Cliente desliga onRevoke em isReadOnly; RPC não tem essa restrição. Conciliar a semântica de revogar; não tratar como vazamento nem ampliar autorização por inferência. |
| H07 | noturna/R01 | Hash de edição/revogação sem conversation_id | G5 | Hash atual mantém o residual histórico. Registrar teste de replay/contexto na revisão profunda pós-MVP; não reabrir automaticamente E2E. |
| H08 | R02 | Duplicar Aviso | G6 + Owner | Spec prevê novo rascunho; ação de duplicar não localizada no diretório atual. Conciliar requisito com MVP vigente como subaceite, antes de implementar/adiar. |
| H09 | R04/R06 | Disparo agendado de expiração Agora | C0 + G4 + G5 | Migration190500 declara disparador externo ausente; varredura não localizou agendador no código. Medir agendamento efetivo em produção; filtro de leitura não prova cleanup material. |
| H10 | noturna/R01 | Múltiplas regras de audiência de Formulários | G3 + Owner | Editor lê primeira regra e salva uma; risco depende de distribuição com várias regras. Testar preservação de audiência existente e definir autoria sem ampliar/reduzir audiência silenciosamente. |
| H11 | noturna/R01 | Autosave de autoria de Formulários | G3 + Owner | _scheduleAutosave depende de authoringApi; host produtivo passa api, não authoringApi. Conciliar autosave do autor com requisito; não confundir com autosave da resposta. |
| H12 | noturna/R01 | Autoria de mínimo/máximo de seleção | G3 | Editor preserva minSelections/maxSelections; controles de autoria não localizados na inspeção focal. Definir origem/autoria dos limites e registrar aceites pertinentes. |
| H13 | noturna/R01 | Destino do CTA de Comunicação | G4 + G6 + Owner | PlatformNotice não tem URL; adaptador passa rótulo e UI informa indisponibilidade. Ratificar adiamento ou definir destino autorizado; não converter feedback em navegação real. |
| H14 | R06 | Sino sem action_id/subaceite | C0 + G6 | ContextNotificationFeed composto; leitura/read_at relatados sem ID canônico. Mapear subaceite à ação-pai e reutilizar evidência válida; não criar novo denominador. |
| H15 | R06 | Atribuir Plano e colisão P51 | G7 + Owner | plans.assign pendente; spec051 apenas leitura de vínculos; P51 foi reutilizado para SMTP. Pergunta R07-PLANO: confirmar atribuição no MVP; activate=restaurar não é assign. |
| H16 | R06 | Leitura people-based de políticas de cuidado | G5 | Policy usa has_platform_permission(platform.read) com um argumento; alcance institucional requer prova. Revisão profunda de escopo entre unidades; se surgir vazamento reproduzido, tratar como incidente e gate imediato. |
| H17 | R06 | Papel fixo além de capacidade em cuidado | G5 + Owner | set_v1 exige owner/operations e units.update. Conciliar com perfis/permissões; não ampliar papel implicitamente. |
| H18 | R06 | Unicidade global concorrente de @ | G5 + G1 | Checagem de disponibilidade antes de insert/trava por request; sem lock global por handle localizado. Revisão profunda concorrente entre tabelas; manter primeiro gate e não declarar falha explorável sem prova. |
| H19 | R06 | Responsável vazio em Medicação | G3 | Pista do handoff ainda não reconciliada na prova atual. Reproduzir com contexto/destinatário válido antes de classificar como defeito ou fechado. |
| H20 | R06 | Imagem da dose sem gateway | G3 | Pista do handoff; evidência posterior de medication.evidence não basta para todos os fluxos. Conferir consumidor de mídia/rota e prova específica; preservar aceite que não foi invalidado. |
| H21 | R07 | Limite de texto/rodapé Circular | G6 + Owner | Spec037:10.000; referência Publicação mostra4.000; seis R no compositor web. Comparar host/referência; pergunta focal de limite/geometria, sem reduzir contrato silenciosamente. |

## Fora do E2E ativo / gates formais

| action_id | Escopo | Primeiro gate / limite |
| --- | --- | --- |
| auth.mfa | gate-formal-mvp | C0 + G7: cumprir gate formal de publicação/segurança aplicável antes do encerramento da Etapa2; não conta entre199E2E. |
| shell.load | flutter-only | Preservar contrato Flutter; não criar backend para ação que não o exige. |
| shell.navigate | flutter-only | Preservar contrato Flutter; não criar backend para ação que não o exige. |
| shell.switch-context | flutter-only | Preservar contrato Flutter; não criar backend para ação que não o exige. |
| shell.unauthorized | flutter-only | Preservar contrato Flutter; não criar backend para ação que não o exige. |
| shell.reload | flutter-only | Preservar contrato Flutter; não criar backend para ação que não o exige. |
| institutions.import | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| institutions.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| units.import | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| units.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| units.people-export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| groups.import | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| groups.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| attendance.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.list | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.create | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.upload | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.preview | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.confirm | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.status | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| imports.download | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.import | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.preview | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.confirm | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.status | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| profile-files.download | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| audit.export | deferred-post-mvp | Manter indisponibilidade honesta; reabrir só após decisão do Owner no fim do MVP. |
| account.mfa | gate-formal-mvp | C0 + G7: cumprir gate formal de publicação/segurança aplicável antes do encerramento da Etapa2; não conta entre199E2E. |
| internal-users.mfa | gate-formal-mvp | C0 + G7: cumprir gate formal de publicação/segurança aplicável antes do encerramento da Etapa2; não conta entre199E2E. |

## Entrega e plano

### Complemento histórico recuperado

| ID | Origem | Item | Dono | Estado medido / primeiro gate |
| --- | --- | --- | --- | --- |
| H22 | noturna/R01 | Descritor privado de Circular | G6 + G5 | RPC autorizada retorna bucket_id/object_key com grant authenticated; não demonstra bucket público. Conciliar descritor/localizador com ADR0032 na revisão de segurança; não declarar vazamento sem prova. |
| H23 | noturna/R01 | Continuidade visual no refresh de Avisos | G6 | Carga atual usa loading; não reproduzido visualmente nesta varredura. Classificar com UX vigente; não criar bloqueio MVP automático. |
| H24 | noturna/R01 | Rótulos de Sobre | G4 | Rótulos semânticos, valores visíveis; referência antiga citada no código. Comparar referência vigente e observações Owner, sem confundir estados de outras famílias. |
| H25 | noturna/R01 | Alvo de redimensionamento de tabela | C0 + G3 | Histórico de conflito com ordenação/teste ignorado; dimensão atual não medida. Medir teclado/semântica/toque no composto e atribuir ajuste acessível; não remover skip sem causa. |
| H26 | noturna/R01 | Opcional omitida, escala legada invertida/opções vazias | G3 | Pistas históricas ainda sem reconciliação completa. Inspecionar contrato atual por caso antes de propor defeito ou mudança de estado. |
| H27 | noturna/R01 | Sinal de atualização Momentos e saudação fixa | G4 | Pistas de UX/escopo, não regressão comprovada. Classificar com composição vigente e defaultP54, sem reabrir E2E automaticamente. |
| H28 | R01 | Filtros de Pessoas/atividade/localidade, avatar e buffers de upload | G2 + G4 | Pistas em deltas R01; reconciliação de todos os hunks não concluída. Rever apenas diferenças funcionais persistentes; branches e manifests preservados, sem quitação global. |

Por ordem do Owner de12/09, a revisão restante de segurança fica separada
da entrega; H01 registra a rotação já concluída antes dessa instrução.
H07/H16–H18/H22 não autorizam endurecimento amplo nesta consolidação.

Ver R08-plano.md e os dez prompts em R08-prompts.md. P52 está resolvida por
deploy/preflight; P53=A foi recebida. Pendência de execução visual não é
nova pergunta. O runtime Docker ainda exige recuperação; as frentes não
devem repetir o diagnóstico de G0. Só C0 aplica SQL/deploy/deltas de estado.
