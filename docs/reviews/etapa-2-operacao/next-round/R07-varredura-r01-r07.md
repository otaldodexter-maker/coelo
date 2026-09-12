---
title: "R07 — varredura R01 a R07 e preservação por conteúdo"
source: "fechamentos/handoffs/reports R01–R07; JSONs atuais e legados; inventário; três rastreadores; skills; Git local/remoto"
status: "achados encaminhados; limites de leitura explicitados"
generated_at: "2026-09-12"
---

# Resultado

Foram encontrados resíduos com justificativas antigas, gates resolvidos que
continuavam abertos e subaceites sem encaminhamento vigente. Não se declara
“nada ficou para trás”:28 registros abaixo preservam o que foi encontrado,
incluindo pistas não reproduzidas e revisão profunda. H01 foi resolvido
antes de o Owner pedir que a revisão de credenciais ficasse fora da entrega.
As decisões da G8rev19 foram integradas: P53A, rodapé modelo e Circular
intercalada; não permanecem como “aguarda aprovação”.

## Registro com origem

| ID | Origem | Arquivo-fonte | Item | Estado medido | Dono / primeiro gate |
| --- | --- | --- | --- | --- | --- |
| H01 | R06 | docs/reviews/evidence/etapa-2/r06-estrutura/handoff.md:91 | Credencial QA exposta | RESOLVIDO: senha de qa-r06-estrutura rotacionada via Auth Admin em12/09T13:06:51Z; login verificado e sessão de prova encerrada204; arquivo privado atualizado. | C0 — Reutilizar arquivo privado novo; não copiar credencial antiga. |
| H02 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/perfil-para-voce.json:1008 | Atualizar dado oficial a partir do Sobre | ProfileAboutOfficialUpdateRequest tem domínio/testes, sem consumidor produtivo localizado. | G4 + Owner — Conciliar contrato aprovado, conectar ou registrar adiamento; não afirmar implementado. |
| H03 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/perfil-para-voce.json:998 | Composição de quatro abas de Perfil | PrincipalProfileContentTabs sem consumidor produtivo localizado. | G4 — Comparar composição usada com referência vigente e decidir destino do componente. |
| H04 | noturna/R02/R07 | docs/reviews/etapa-2-operacao/reports/NOTURNA-decisao-owner-circulares-acoes-ausentes.md:163 | Compositor antigo de Circular e blocos intercalados | PrincipalCircularComposerPage só em testes; produção usa SuperadminCircularComposerPage. Owner reafirma perguntas/mídia no meio do texto. | G6 — Conciliar os dois hosts; implementar/provar na rota normal sem usar golden homônimo como aceite. |
| H05 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/chat-comunicacoes.json:418 | Denominador histórico de recibos do Chat | SQL considera participantes ativos atuais, sem corte joined_at/data da mensagem. | G4 + G5 + Owner — Definir destinatários históricos versus atuais; preservar aceite MVP já existente enquanto não muda contrato. |
| H06 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/chat-comunicacoes.json:440 | Revogar em Chat somente leitura | Cliente desliga onRevoke em isReadOnly; RPC não tem essa restrição. | G4 + Owner — Conciliar a semântica de revogar; não tratar como vazamento nem ampliar autorização por inferência. |
| H07 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/chat-comunicacoes.json:435 | Hash de edição/revogação sem conversation_id | Hash atual mantém o residual histórico. | G5 — Registrar teste de replay/contexto na revisão profunda pós-MVP; não reabrir automaticamente E2E. |
| H08 | R02 | docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md:165 | Duplicar Aviso | Spec prevê novo rascunho; ação de duplicar não localizada no diretório atual. | G6 + Owner — Conciliar requisito com MVP vigente como subaceite, antes de implementar/adiar. |
| H09 | R04/R06 | docs/reviews/etapa-2-operacao/comunicacao/principal-chat-sistema-handoff.md:64 | Disparo agendado de expiração Agora | Migration190500 declara disparador externo ausente; varredura não localizou agendador no código. | C0 + G4 + G5 — Medir agendamento efetivo em produção; filtro de leitura não prova cleanup material. |
| H10 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json:1439 | Múltiplas regras de audiência de Formulários | Editor lê primeira regra e salva uma; risco depende de distribuição com várias regras. | G3 + Owner — Testar preservação de audiência existente e definir autoria sem ampliar/reduzir audiência silenciosamente. |
| H11 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json:1446 | Autosave de autoria de Formulários | _scheduleAutosave depende de authoringApi; host produtivo passa api, não authoringApi. | G3 + Owner — Conciliar autosave do autor com requisito; não confundir com autosave da resposta. |
| H12 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json:1453 | Autoria de mínimo/máximo de seleção | Editor preserva minSelections/maxSelections; controles de autoria não localizados na inspeção focal. | G3 — Definir origem/autoria dos limites e registrar aceites pertinentes. |
| H13 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/perfil-para-voce.json:552 | Destino do CTA de Comunicação | PlatformNotice não tem URL; adaptador passa rótulo e UI informa indisponibilidade. | G4 + G6 + Owner — Ratificar adiamento ou definir destino autorizado; não converter feedback em navegação real. |
| H14 | R06 | docs/reviews/evidence/etapa-2/r06-publicacoes-agenda/handoff.md:18 | Sino sem action_id/subaceite | ContextNotificationFeed composto; leitura/read_at relatados sem ID canônico. | C0 + G6 — Mapear subaceite à ação-pai e reutilizar evidência válida; não criar novo denominador. |
| H15 | R06 | docs/reviews/evidence/etapa-2/r06-operacoes/handoff.md:30 | Atribuir Plano e colisão P51 | plans.assign pendente; spec051 apenas leitura de vínculos; P51 foi reutilizado para SMTP. | G7 + Owner — Pergunta R07-PLANO: confirmar atribuição no MVP; activate=restaurar não é assign. |
| H16 | R06 | docs/reviews/evidence/etapa-2/r06-realm-interno/handoff.md:79 | Leitura people-based de políticas de cuidado | Policy usa has_platform_permission(platform.read) com um argumento; alcance institucional requer prova. | G5 — Revisão profunda de escopo entre unidades; se surgir vazamento reproduzido, tratar como incidente e gate imediato. |
| H17 | R06 | docs/reviews/evidence/etapa-2/r06-realm-interno/handoff.md:83 | Papel fixo além de capacidade em cuidado | set_v1 exige owner/operations e units.update. | G5 + Owner — Conciliar com perfis/permissões; não ampliar papel implicitamente. |
| H18 | R06 | docs/reviews/evidence/etapa-2/r06-realm-interno/handoff.md:91 | Unicidade global concorrente de @ | Checagem de disponibilidade antes de insert/trava por request; sem lock global por handle localizado. | G5 + G1 — Revisão profunda concorrente entre tabelas; manter primeiro gate e não declarar falha explorável sem prova. |
| H19 | R06 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado-rotina-handoff.md:69 | Responsável vazio em Medicação | Pista do handoff ainda não reconciliada na prova atual. | G3 — Reproduzir com contexto/destinatário válido antes de classificar como defeito ou fechado. |
| H20 | R06 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado-rotina-handoff.md:69 | Imagem da dose sem gateway | Pista do handoff; evidência posterior de medication.evidence não basta para todos os fluxos. | G3 — Conferir consumidor de mídia/rota e prova específica; preservar aceite que não foi invalidado. |
| H21 | R07 | docs/reviews/etapa-2-operacao/next-round/R07-decisoes-owner-20260912.md | Limite de texto/rodapé Circular | Spec037:10.000; referência Publicação mostra4.000; seis R no compositor web. | G6 + Owner — Comparar host/referência; pergunta focal de limite/geometria, sem reduzir contrato silenciosamente. |
| H22 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/publicacoes-midia.json:441 | Descritor privado de Circular | RPC autorizada retorna bucket_id/object_key com grant authenticated; não demonstra bucket público. | G6 + G5 — Conciliar descritor/localizador com ADR0032 na revisão de segurança; não declarar vazamento sem prova. |
| H23 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/chat-comunicacoes.json:395 | Continuidade visual no refresh de Avisos | Carga atual usa loading; não reproduzido visualmente nesta varredura. | G6 — Classificar com UX vigente; não criar bloqueio MVP automático. |
| H24 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/perfil-para-voce.json:417 | Rótulos de Sobre | Rótulos semânticos, valores visíveis; referência antiga citada no código. | G4 — Comparar referência vigente e observações Owner, sem confundir estados de outras famílias. |
| H25 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json:1202 | Alvo de redimensionamento de tabela | Histórico de conflito com ordenação/teste ignorado; dimensão atual não medida. | C0 + G3 — Medir teclado/semântica/toque no composto e atribuir ajuste acessível; não remover skip sem causa. |
| H26 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json:1286 | Opcional omitida, escala legada invertida/opções vazias | Pistas históricas ainda sem reconciliação completa. | G3 — Inspecionar contrato atual por caso antes de propor defeito ou mudança de estado. |
| H27 | noturna/R01 | docs/reviews/etapa-2-operacao/comunicacao/perfil-para-voce.json:498 | Sinal de atualização Momentos e saudação fixa | Pistas de UX/escopo, não regressão comprovada. | G4 — Classificar com composição vigente e defaultP54, sem reabrir E2E automaticamente. |
| H28 | R01 | docs/reviews/etapa-2-operacao/reports/R01-fechamento-20260909.md | Filtros de Pessoas/atividade/localidade, avatar e buffers de upload | Pistas em deltas R01; reconciliação de todos os hunks não concluída. | G2 + G4 — Rever apenas diferenças funcionais persistentes; branches e manifests preservados, sem quitação global. |

## Gates superados e reconciliação

- internal-users.create: R06 já tinha FE/BE local-green e SQLlote55; inventário
  omitiu. Reconciliação aplicada; internal-user-createv3implantada/preflight
  não certifica CRUD. P52resolvida.
- forms.location-answer: decisão de Local já respondida ADR9/12; R07tem
  cobertura local. Falta ocorrência/resposta real, não decisão genérica.
- attendance.entry/complete eram aliases; mark/finish/correct foram
  reconstruídas. FE/E2E anteriores retirados da certificação vigente.
- Agenda/Circularcreate/edit têm provasR06 posteriores à reconstrução;
  certificados foram atualizados sem promover novos IDs.
- 180060 não muda comportamento do papel; decisão resolvida. CHECKresidual
  continua revisão profunda, não nova pergunta sobre o mesmo papel.
- P17/P35, gateway/CORS e saída de Instituições têm sucessores/provas;
  primeiro gate atual está no backlog, não repetir diagnóstico histórico.
- Corrida de resposta anônima não é sustentada pelo SQLatual que usaFORUPDATE;
  imagemCardápio envia expected_revision; Chat preserva origem Perfil/ParaVocê.
  Não transplante correções antigas sem reprodução.
- Quatro REDs numéricos/moeda/limites/texto de Formulários têm reconciliação
  posterior. Não os contar novamente como defeitos atuais.
- Indicador visual histórico53incluía7objetos sóR; régua correta era46A.
  G8acrescentou8IDs explícitos, total54A. Não somar64imagens ao denominador.

## Branches não ancestrais — disposição por conteúdo

“Arquivar” aqui é manter a branch como referência; nenhuma foi apagada ou
renomeada. Ausência de ancestralidade não prova código novo. Os números de
commits abaixo não são progresso. Não houve merge em bloco de branchantiga.

| Branch | HEAD | Commits fora da base integrada | Decisão |
| --- | --- | --- | --- |
| codex/e2-r02-d01-autenticacao | dc44df9e1 | 30 | Arquivar como referência: delta de memória já refletido; não reintroduzir Auth antigo. |
| codex/e2-r02-d02-estrutura | 40ec50d72 | 81 | Arquivar como referência:10/36 arquivos produtivos candidatos idênticos; três migrations equivalentes atuais; catálogo/reservas preservados em histórico. Sucessores vigentes. Hunk residual demonstrado vai aG1. |
| codex/e2-r02-d03-acompanhamento | 0a2ecb34e | 46 | Arquivar como referência:4/12 caminhos idênticos; SQL arquivado integral; Rotina atual adiciona versão/UUID/guardas. G3 recupera só diferença funcional demonstrada. |
| codex/e2-r02-d04-acessos | 375e0a62a | 34 | Arquivar como referência:7/22 caminhos idênticos; filtro no histórico e segurança em170800; código atual de retry/recibo/criação preservado. Residual concretoG2/G3/G5. |
| codex/e2-r02-l00-coordenacao-claude | bdef0f559 | 50 | Arquivar como recibo documental de coordenação. |
| codex/e2-r02-l01-publicacoes | 3697dd49e | 40 | Arquivar referência; resíduos funcionais H04/H08/H09/H22, worker e migrações posteriores preservados. |
| codex/e2-r02-l02-chat-comunicacoes | 45d92b9c1 | 49 | Arquivar referência; resíduos H05–H07/H23; CHAT_READ_ONLY e worker têm sucessores. |
| wip/fase0-arquivo-chat | 91e011dc6 | 1 | Arquivar referência; ícones Planos/Cardápios e launcher sucedidos emR04; P53 agoraA. Não é código ativo perdido. |
| work/etapa2-noturna-copia-previa | 80f160599 | 1 | Arquivar: frases antigas removidas, D3 sucedeu o patch. |
| work/etapa2-noturna-formularios-cuidado | 55f4b5910 | 5 | Arquivar registro de método/qualificação; sem código produtivo novo no último patch. |
| work/etapa2-noturna-import-orfao | 8a09d66ac | 1 | Arquivar: import já ausente na base atual. |
| work/etapa2-noturna-operacoes-sistema | dd1a95bcd | 2 | Arquivar registro de atribuição/limites; contratoRPC atual reconciliado peloC0. |
| work/etapa2-noturna-perfil-para-voce | 1d46746ff | 2 | Arquivar qualificação de provas; resíduos H02/H03/H13/H24/H27. |
| work/etapa2-noturna-publicacoes-midia | 69e377f3e | 3 | Arquivar qualificação de entrega; resíduos H04/H22. |

As demais brancheswork/codex eram ancestrais da base integrada em12/09:
`codex/e2-r02-l03-perfil-para-voce@b209b4e0f`, `work/etapa2-noturna-acessos-pessoas@992f3530d`, `work/etapa2-noturna-alunos-rotina@c73f7b526`, `work/etapa2-noturna-avisos-chave-de-linha@cb0a386d8`, `work/etapa2-noturna-chat-comunicacoes@c1e6756c7`, `work/etapa2-noturna-chat-volta-mobile@fb31e11dc`, `work/etapa2-noturna-estrutura@6709f1473`, `work/etapa2-r03-acessos-pessoas@d47e16839`, `work/etapa2-r03-coordenacao@98cc0529d`, `work/etapa2-r03-estrutura@63be8a474`, `work/etapa2-r03-formularios-cuidado-rotina@fdc89c488`, `work/etapa2-r03-operacoes@3fa07edd0`, `work/etapa2-r03-principal-chat-sistema@a9faabd01`, `work/etapa2-r03-publicacoes-agenda@3b21db696`, `work/etapa2-r03-realm-interno@7ce4337b1`, `work/etapa2-r04-acessos-pessoas@3b499860f`, `work/etapa2-r04-coordenacao@9bf60463b`, `work/etapa2-r04-estrutura@189cbb852`, `work/etapa2-r04-formularios-cuidado-rotina@508d9e842`, `work/etapa2-r04-operacoes@a71928c7c`, `work/etapa2-r04-principal-chat-sistema@4ddef877f`, `work/etapa2-r04-publicacoes-agenda@3895238a5`, `work/etapa2-r04-realm-interno@d89c236de`, `work/etapa2-r05-acessos-pessoas@d6ceff4be`, `work/etapa2-r05-coordenacao@ca60b096b`, `work/etapa2-r05-estrutura@48fb00f06`, `work/etapa2-r05-formularios-cuidado-rotina@395f4552f`, `work/etapa2-r05-operacoes@4c9101fe5`, `work/etapa2-r05-principal-chat-sistema@45d3e681d`, `work/etapa2-r05-publicacoes-agenda@a371fce6d`, `work/etapa2-r05-realm-interno@f30516f31`, `work/etapa2-r06-acessos-pessoas@bf98ecb73`, `work/etapa2-r06-coordenacao@8589c4603`, `work/etapa2-r06-estrutura@001a33e06`, `work/etapa2-r06-formularios-cuidado-rotina@67e04fb10`, `work/etapa2-r06-operacoes@7b1a83caa`, `work/etapa2-r06-principal-chat-sistema@2be3ed6b7`, `work/etapa2-r06-publicacoes-agenda@c813becfe`, `work/etapa2-r06-realm-interno@04da3e59b`, `work/etapa2-r07-acessos-pessoas@72980497b`, `work/etapa2-r07-coordenacao@2f0a1cfb7`, `work/etapa2-r07-estrutura@84a84e2a1`, `work/etapa2-r07-formularios-cuidado-rotina@c105bff1d`, `work/etapa2-r07-operacoes@ff0e2338d`, `work/etapa2-r07-principal-chat-sistema@30ba45a80`, `work/etapa2-r07-publicacoes-agenda@7bdb38a09`, `work/etapa2-r07-realm-interno@d25d1ddcb`, `work/etapa2-r07-suites@d4a62918c`.

## Cobertura e limites da varredura

Lidos os fechamentos e handoffs das frentes R03–R07, reconciliação R01/R02
e fechamentoOwnerR02, sete promptsC01–C07R01 e todos os23Markdown narrativos
R01remanescentes (checkpoints, integrações, deltas, mídia e visual).
HandoffsR02ausentes no checkout foram recuperados das branches.
R04usa fechamento embutido/canais/perguntas, não arquivo autônomo inexistente.

JSONs de inventário/canais atuais foram processados integralmente; os canais
legados foram inspecionados em achados, perguntas, bloqueios, retestes e
fechamentos, com fontes registradas acima. Isso não equivale a leitura
semântica integral de cada registro cumulativo. Os manifests extensos
R01de replay, painéis/métricas, Forms/Locationswriter têm lacunas de leitura.
A comparação D02/D03/D04 cobriu caminhos produtivos/migrations apontados
pelos handoffs, não todos os hunks de router/bootstrap/testes/tooling.

Portanto, as branches/manifests permanecem preservados; não se certifica
equivalência total nem autoriza apagá-los. Primeiro gate de recuperação
adicional: demonstrar hunk funcional ausente contra a base atual (C0 com
G1/G2/G3/G4), nunca reabrir toda a rodada por quantidade de commits.

## Entrega atual

Todos os oito HEADs finaisR07, inclusiveG8d4a62918c, chegaram por merge.
CensoC0:6727PASS/33FAIL/11SKIP; analyzerlimpo; Deno25+3PASS, sem somar
reruns. A lista de33falhas e seus donos está na evidência do coordenador.
Testes/build não substituem a prova real dos68E2Eainda pendentes.
R08-backlog.md contém cada ação, subaceite e primeiro gate.
