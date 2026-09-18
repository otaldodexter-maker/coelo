---
source: Owner 2026-09-13 — cota aproximada de8% e divisão R12/R13; R12-owner-items.json; R11-fechamento.md
status: planejamento aprovado pelo pedido de divisão; execução não iniciada
generated_at: 2026-09-13
---

# R12 — Correções focais com reserva de fechamento

Atualização operacional posterior: R12-prompt-unico.md inclui o disparo
independente preparado em R12-disparo-luna.md. O Owner autorizou que o fechamento
publicado da R12 libere a execução R13 em Luna médio, com passagem supervisionada
para a reserva disponível. Esta preparação não iniciou nenhuma rodada.

## Objetivo e limite

O backlog total contém53 compromissos de vários domínios, com lacunas de
contrato, decisões, SMTP e quatro candidatos SQL ainda não aplicados. Não há
base para prometer concluir todos com8p.p. de cota. A R11 consumiu5p.p. em
aproximadamente115min e entregou correções locais, sem novo aceite E2E integral;
isso calibra a cautela, não serve como preço fixo por item.

Escopo R12 reduzido a R12-07, R12-41 e R12-43. Os outros50 têm destino R13.
Catálogo original e IDs preservados; destinationRound é a autoridade de destino
sobre menções históricas a C0 R12 nos arquivos de captura. Não iniciar R12 ou
R13 por esta manutenção documental; a abertura explícita executa este recorte.

Leitura nesta preparação:92% usados, janela10080min, reset1789820315
(2026-09-19T12:18:35Z). Os8p.p. até100 não são orçamento seguro integral.
Na abertura medir U0 novamente, incluindo o consumo deste planejamento:

- teto = min(U0 + 6p.p., 98% usados);
- congelar novas fatias a teto - 2p.p.; reservar esses2p.p. para testes finais,
  integração, MDs, transferência de abertos e push;
- buscar terminar1p.p. antes do teto quando possível; nunca esperar chegar98
  para começar o fechamento;
- medir a cada10min, entrega e antes de build; sem margem para uma fatia
  completa, fechar antecipadamente e transferir o restante;
- um reset não estende a rodada silenciosamente. R13 terá orçamento próprio
  medido na abertura; não cabe prometer seus50 itens nos2p.p. de margem.

Estimativa provisória do conjunto: cerca de90min de execução e30min de
fechamento, com máximo de2h de execução +30min de fechamento, sempre subordinado
à cota. Base da estimativa: três composições existentes, testes disponíveis e
nenhuma alteração backend prevista. Ainda falta reproduzir as imagens/estados;
se aparecer alteração de contrato ou componente global, reduzir o recorte e
transferir a parte maior. Não converter esta estimativa em compromisso de
três aceites integrais ou percentual de código escrito.

## Contrato de execução serial C0

- Confirmar fetch/HEAD/origin-dev, status/stash/worktree e processos. Usar
  checkout consolidado; preservar WIP, ignorados e Chrome do Owner.
- Aplicar coelo-ui, coelo-frontend, ponytail, RTK e coelo-knowledge; consultar
  coelo-frontend-backend quando a conclusão cruzar o servidor. Execução inline,
  um Chrome QA e um flutter test globais; sem enxame de auxiliares.
- Hospedeiro apps/superadmin; preservar Principal hospedado. Usar3000 e
  Supabase produção somente com sintéticos autorizados. Sem SQL/Cloudflare novo
  neste recorte; gate PITR e SMTP seguem R13, não ficam resolvidos por divisão.
- Inspecionar/reproduzir cada item antes da correção; reutilizar tokens e
  componentes, sem dependências/abstrações novas. Testes focais; build conjunto
  somente quando código mudar e houver fatia suficiente para prova.

## Ordem e fatias revisáveis

### 1. R12-07 — Chamada: respiro do erro

Fonte: R12-apontamentos-owner.md, anexo7. Código:
`apps/superadmin/lib/features/attendance/attendance_pages.dart`,
`_AttendanceCommandErrorBanner` e usos de feedback no formulário/edição.
Já existe padding interno; reproduzir a falta de margem externa antes de
alterar tokens. Não transformar R12-08 (persistência/sentimento) em escopo oculto.

- [x] Abrir chamada normal e reproduzir estado de falha sintético; separar
  falha de salvar da apresentação do banner.
- [x] Corrigir somente o encaixe/respiro causal no contêiner canônico;
  preservar rascunho, mensagem, ação de recuperação e rodapé.
- [x] Executar os casos afetados de
  `test/features/attendance/attendance_pages_test.dart` e, se necessário,
  `attendance_touch_target_test.dart` a partir de apps/superadmin com
  `rtk proxy flutter test <arquivo> --plain-name <caso afetado> --no-pub`.
- [x] Provar desktop/mobile, texto200%, erro sem conteúdo colado/encoberto,
  edição preservada e teclado. Falha funcional de gravação fica no item R12-08, destinado à R13,
  com causa/prova, sem alegar CRUD corrigido por ajuste visual.

### 2. R12-41 — Formulários: Situação/Período

Fonte: R12-formularios-agenda-owner.md, anexos2–3. Código:
`apps/superadmin/lib/features/forms/presentation/directory/forms_directory_page.dart`.
Há seletor Situação e largura240 no trecho de filtros; comparar com componentes
canônicos e preservar seleção múltipla. Não incluir editor/renomeação/drag.

- [x] Reproduzir popup aberto/fechado e quebra Limpar/Aplicar na rota normal.
- [x] Ajustar composição/largura e gatilhos canônicos dos dois filtros, sem
  alterar semântica dos parâmetros enviados ao repository.
- [x] Cobrir selecionar múltiplos estados, aplicar, limpar, período, foco e
  compacto/texto ampliado nos testes existentes
  `test/features/forms/presentation/directory/forms_directory_page_test.dart`;
  revisar goldens afetados de `forms_directory_golden_test.dart` por imagem.
- [x] Provar resultado filtrado correto na UI, ausência de truncamento e
  rodapé do popup em uma composição acessível. Não inventar aprovação A.

### 3. R12-43 — Conversas: contorno do contêiner

Fonte: R12-chat-contorno-owner.md. Código:
`apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`.
Existe borda em um bloco, mas outra decoração não a declara: localizar o
contêiner visto no anexo antes de atribuir causa. R12-52 (mosaico/compositor)
segue R13, sem redesenho oportunista.

- [x] Reproduzir lista/conversa/paginação/compositor em desktop/compacto,
  claro/escuro, vazio e scroll; preservar limites e cantos da referência.
- [x] Corrigir borda/clipping causal por tokens existentes, sem envolver
  tudo em contêiner redundante e sem bordas novas nas bolhas por inferência.
- [x] Testar casos afetados em
  `test/features/chat/presentation/superadmin_chat_page_test.dart` e revisar
  renders pertinentes de `superadmin_chat_page_golden_test.dart`.
- [x] Confirmar navegação e leitura da conversa normal; não enviar mensagens
  a terceiros nem declarar anexos/entrega/backend concluídos por contorno.

## Fechamento obrigatório e transferência

- [x] Registrar por item FE/BE/E2E, evidência, testes únicos P/F/B/S/U, cota,
  SHA, runtime/build/deploy e primeiro gate; atualizar inventário/matrizes juntos.
- [x] Criar R12-fechamento.md com status encerrada e os resultados reais.
  Atualizar ownerItems vigentes antes de decidir quais foram concluídos.
- [x] Executar `rtk proxy python docs/reviews/etapa-2-operacao/next-round/transferir-abertos-r12-r13.py --preview`.
- [x] Executar o mesmo comando com `--apply`: transfere cada item selecionado
  ainda aberto para R13, mantendo ID, provas, candidato, camadas e bloqueio.
  Não transferir item concluído nem abrir R13 automaticamente.
- [x] Gate final após publicação: commit/push dev sem force; executar delivery_gate.py após push,
  reconciliar remoto/WIP e reportar a lista transferida. PASS parcial não é
  conclusão do produto. Falta de cota não autoriza omitir o fechamento.

Sem ganho funcional nesta divisão: FE175/231, BE159/224, E2E148/199. A cobertura
dos três apontamentos é separada desses denominadores de produto.

## Execução e fechamento

Plano executado no recorte07/41/43. Resultados, controles que permaneceram falhos e recibo formal em R12-fechamento.md; não interpretar o checklist preparatório como prova de execução ou reabrir esta rodada. R13 seguirá somente pelo release supervisionado.
