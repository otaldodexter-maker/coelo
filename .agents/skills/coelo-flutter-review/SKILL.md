---
name: coelo-frontend
description: Use when a Coelo task reviews, audits, corrects, implements, estimates, or verifies front-end behavior in Flutter/Dart apps or the Astro site, including screens, routes, states, responsiveness, accessibility, architecture, tests, and app-specific completion.
metadata:
  source: "AGENTS.md; docs/reviews/coelo-flutter-pendencias.md; specs/050-principal-ui-ux-closure.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Front-end

> O caminho `coelo-flutter-review/` foi mantido para compatibilidade. O nome e
> o contrato canônicos são **Coelo Front-end** (`coelo-frontend`).

## Chamada padrão: resolver pendências

Invocar `$coelo-frontend` para trabalhar no projeto significa **executar a
resolução das pendências Front-end da Etapa 2**, conforme o
[ciclo de resolução](../coelo-flutter-supabase-review/references/review-scope.md#ciclo-de-resolução-de-pendências).
Usar o recorte informado; sem recorte novo, retomar a subtela pendente do último
checkpoint ou selecionar a próxima ação local executável do inventário.
Informar a escolha e prosseguir sem perguntar novamente se pode corrigir.
Conduzir até o aceite Front-end ou um bloqueio demonstrado, preservando os
limites de autorização. Pedido explícito de explicação, diagnóstico/review
somente leitura ou manutenção da própria skill segue esse pedido.

A entrega deve trazer correção e prova, ou a prova de um aceite já atendido.
Atualizar documentação/percentuais, produzir plano ou abrir uma tela não resolve
por si só a pendência. Ausência de backend não impede fechar os aceites próprios
do cliente; a dependência E2E permanece identificada.

## Princípio e superfícies

Concluir somente o que pertence ao cliente, sem confundir UI visível, rota
aberta, fixture ou teste isolado com ação Front-end concluída.

- `apps/superadmin`, `apps/admin` e `apps/principal`: Flutter/Dart.
- `apps/site`: Astro quando o site entrar em um recorte autorizado.
- Packages compartilhados podem ser alterados apenas quando o contrato listar
  consumidores e regressões. Compartilhamento não autoriza tocar outro app.

Todo contrato nomeia os apps incluídos. Na Etapa 2 atual, o único app é
`apps/superadmin`; “Coelo (Principal)” é o menu dentro dele. `apps/admin`,
`apps/principal` e `apps/site` permanecem fora.

Em abertura, checkpoint e entrega, identificar **Etapa 2 → apps/superadmin →
menu → tela → subtela/estado → action_id**. Para cada subtela trabalhada,
mostrar avanço Front-end e a conclusão E2E conhecida, com base e data; uma
subtela não herda o percentual da tela. Aplicar o
[contrato de métricas e testes](../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md).

## Dependências por recorte

Confirmar a base integrada e o handoff antes de reutilizar estado local; seguir
a retomada entre worktrees e o limite de repetição de testes do contrato comum.
Ler `AGENTS.md` e o [contrato de recorte](../coelo-flutter-supabase-review/references/review-scope.md).
Usar `docs/reviews/coelo-flutter-pendencias.md` conforme a profundidade do pedido:
ação localizada usa cabeçalho, linhas afetadas e dependências; auditoria ou
conclusão ampla exige leitura integral.

- `coelo-ui` para composição e interação: distinguir família administrativa,
  Principal hospedado no Superadmin e Site. Não impor Instituições a todo app.
  Abrir os manifestos de anexos indicados nas referências dessa skill e o item
  da tela. Correções do Owner e sua integração têm prioridade no recorte;
  preservação do anexo não comprova implementação nem aceite.
- `rtk` para comandos; `coelo-knowledge` para conhecimento durável.
- Em Flutter/Dart, revisão de código carrega `flutter-dart-code-review`;
  mudanças de layout carregam `flutter-build-responsive-layout`.
- Em Astro, carregar `astro` e ferramentas web pertinentes.
- Defeito funcional usa teste que reproduz a causa antes da correção e
  verificação final. Mudança documental/visual simples usa checks proporcionais.
- Usar `coelo-frontend-backend` quando contrato, alteração ou conclusão
  atravessarem cliente e backend. Ajustar um rótulo numa tela de Auth não
  inaugura auditoria Supabase. Registrar dependências conhecidas sem certificá-las.
- Chat (administrativo e Principal hospedado no Superadmin), desde a Rodada
  4: `SupabaseChatRepository` é o único caminho produtivo; a composição real
  (`superadmin_auth_scope.dart`) injeta o repositório com sessão e
  `UnavailableChatRepository` é só o padrão do construtor. As 12 RPCs
  `superadmin_chat_*_v2` estão em produção com o contrato de
  `comunicacao/realm-interno.json`; a assinatura não muda sem pacote novo do
  backend. Criar grupo (`ChatCreateGroupCommand`) exige uma instituição e
  `personIds` do realm de pessoas (profissional com vínculo ativo ou
  responsável com criança ativa nela); grupo entre instituições não existe
  no modelo. `CHAT_MEMBER_INVALID` (422) é validação
  (`ChatMemberInvalidException`), nunca perda de sessão; `CHAT_READ_ONLY`,
  `CHAT_EDIT_WINDOW_CLOSED` e `CHAT_ALREADY_REVOKED` são conflito de estado.
  Recibo só renderiza quando o servidor projeta `receipt`; bandeira
  desconhecida vira `none`. Pendências: `chat.create-group` pela UI não
  fechou na retomada da R04 (diálogo fechou sem grupo novo após reload);
  `chat.attach` fica visível e inerte até o gateway de mídia comum.

## Progresso e limite de `verified`

Medir Front-end até o fim do cliente: rota e composition root normais, UI,
loading/empty/error/unauthorized/processing/expired, validação, navegação,
foco/teclado/toque, responsividade, acessibilidade, tema, arquitetura,
contrato do repository/gateway e regressão.

`local-green` indica uma fatia local ainda incompleta. `verified` indica que a
ação chegou ao fim do Front-end; pode usar double fiel no teste, mas runtime
normal não pode cair em fake/fixture. A falta do backend não rebaixa um
`verified`; fica aberta no rastreador integrado.

Régua do MVP (ADR 0034): `verified` exige rota normal abrindo sem fixture nem
fail-closed, formulário salvando pelo repository produtivo e reload mantendo o
estado. Golden divergente, prova de teclado por estado e varredura de
acessibilidade por tela ficam registrados, mas não bloqueiam `verified` no MVP;
entram na revisão profunda. Chaves de composição fechadas
(`structureMutationsEnabled`, adapters `available: false`) devem ser ligadas
assim que o SQL correspondente estiver aplicado, não deixadas em indisponível.

Obter o denominador atual do inventário e rastreador da camada. Não manter
contagens fixas na skill. `pending-verification` exige conferir evidências e
não significa que a implementação inexiste. Quando Astro entrar em escopo, criar
denominador explícito por app ou ampliar o rastreador de forma reconciliada;
nunca somar apps diferentes silenciosamente.

Em trabalho de entrega, reportar o recorte por tela/subtela e o geral conhecido
da Etapa 2 separadamente, com base de IDs, evidência e horário. Consulta de uma
camada reutiliza o snapshot integrado datado; não inicia auditoria das demais.
Se faltarem dados, indicar o dado necessário, sem inventar zero nem percentual.
Tempo usado é medido; se faltar, escrever `não calculável ainda`.

Checkpoint curto, no máximo quatro linhas:

```text
Etapa 2 | apps/superadmin | menu > tela > subtela | action_ids
Feito: telas ligadas/corrigidas ...; testes P/F; verified C/N.
Aberto: ... (o que falta e quem desbloqueia).
Próximo passo: ...
```

Não montar manifestos com hash de arquivo, recibos de recibo nem contagens
P/F/B/S/U por lote: o commit no Git e a saída do `flutter test` são a evidência.

## Contrato de abertura

Registrar o recorte já solicitado, pendências, apps, família visual, ações,
ordem, parada, evidências e estimativa do delta real. Não perguntar tempo por
padrão nem aplicar faixas fixas por tela. Distinguir implementação faltante,
verificação faltante e espera externa, reaproveitando código e testes existentes.

## Contratos Front-end de mídia e arquivos

- O cliente chama apenas o Media Gateway; nunca recebe credencial permanente R2, Stream,
  secret key ou `service_role`. URLs curtas de upload/playback/download podem
  ser consumidas em runtime após reautorização pelo gateway, sem embutir em
  código/assets, persistir como acesso permanente ou registrar em logs.
- Agora prefere Stream pronto e usa MP4 temporário do R2 ou estado de
  processamento enquanto codifica; expiração não vira download nem tela presa.
- Momentos e Acontece reproduzem R2 progressivamente; Stream é seletivo.
- Chat usa R2 para anexos.
- Formulários exibem exportação XLSX com as respostas do formulário. Demais
  import/export mantêm botão acessível com indisponibilidade honesta.

## Execução e checkpoint

Aplicar a verificação proporcional do contrato de recorte. Por `action_id`
em escopo, provar listar, criar, detalhe, editar,
publicar/ativar, excluir/revogar, arquivos, estados e reload visual quando
aplicáveis. Validar mobile/desktop, light/dark, texto 200%, teclado, toque e
foco. Atualizar o rastreador após correção, regressão, bloqueio ou ETA novo.

No checkpoint, informar app, tela/subtela/action, evidência, estado Front-end,
dependência externa, primeiro gate aberto e ETA. Diferenciar atividade
concluída, ação Front-end `verified` e produto pendente.
Ao corrigir, avançar a subtela até o próximo aceite verificável do recorte;
reabrir provas anteriores somente por mudança relevante, regressão ou evidência
insuficiente identificada. Não repetir auditoria ampla a cada retomada.

Regras medidas na Rodada 5 (tarde de 11/09/2026):

- **Célula de tabela é alinhada pelo composto** (`CoeloAdminResizableTable`,
  G-SUP aprovado pelo Owner): a feature não envolve célula com `Align`; o
  composto alinha à esquerda e centraliza na linha. Mudança no composto altera
  goldens de todos os diretórios com célula crua (Perfis, Formulários, Rotina,
  Importações): quem muda o composto regrava os goldens afetados de todas as
  famílias num único commit, depois de conferir nas imagens de falha que a
  diferença é só o alinhamento.
- **Calendário da Agenda (P33, referência iOS):** grade sem contêiner por
  célula, linhas finas entre semanas, número menor no canto superior esquerdo
  com respiro, hoje em círculo cheio, pastilhas com ícone + título (clip, não
  reticências), cancelado hachurado com `CANCELADO:` e hora, toggle
  Calendário/Lista em 50/50 centralizado, botão Hoje no rodapé.
- **Detalhe usa o mesmo rodapé de formulário (P34):**
  `SuperadminFormActionFooter` sobre a superfície do tema, destrutivo à
  esquerda e ação primária à direita; conteúdo em `SingleChildScrollView` +
  `Column` com respiro `space10` sob o rodapé.
- **Rota de mutação cuja família tem SQL na baseline** segue o repositório
  composto em `hasAuthoritativeMutationCapability` (Planos como Pessoas e
  Cuidado); carga de dados operacionais no router só com sessão (o router
  chamava `support_list`/`account_profile_get` antes do login e devolvia 401).
- **Envelopes de RPC:** save de perfil devolve `{domain, profile, version}`;
  o cliente desembrulha antes do `fromJson`. `institutions.edit` faz duas
  chamadas encadeadas (`edit_core_v2` e `superadmin_institution_contacts_edit_v1`)
  com o mesmo `expected_version` encadeado.
- **Rota real no build release:** texto entra por `enter_text` do driver
  (`window.$flutterDriver`, com `set_frame_sync false` antes de qualquer
  `tap`) após clique por CDP; `Input.insertText` do CDP não chega ao campo;
  a sessão pode ser injetada no `localStorage`
  (`coelo.superadmin.auth.session`); RPCs são conferidas por
  `performance.getEntriesByType('resource')` com `responseStatus`. Cada
  frente serve o build numa porta própria (3000, 3014, 3020) e a porta entra
  em `COELO_ALLOWED_ORIGINS` das Edge Functions.
- **Sair na rota real derruba as outras frentes:** o botão Sair e as provas de
  `account.logout`/`account.sessions` revogam todas as sessões do
  `qa-r03`; fechar a aba em vez de Sair e deixar essas provas para o fim.
- **Testes de estados remotos do detalhe** precisam simular as chamadas
  adicionais (`superadmin_agenda_contexts`), senão o `MockClient` devolve
  corpo nulo e o teste falha por cast.
- **Goldens de Atividades (9 casos de `activity_golden_test`)** já falhavam em
  `origin/dev` antes da R05; ficam registrados para a frente estrutura
  regravar após a observação.

Regras medidas na Rodada 4 (noite de 10→11/09/2026):

- Rota normal em produção com a sessão `qa-r03@coelo.me`: o único
  entrypoint de driver é `apps/superadmin/test_driver/qa_main.dart`
  (`flutter run -d chrome -t test_driver/qa_main.dart`; `qa_drive.dart`
  dirige pelo CDP). Três frentes criaram entrypoints iguais e o `pubspec`
  chegou com `flutter_driver` triplicado, o que quebra `pub get`; ninguém
  toca o `pubspec` sem avisar o coordenador.
- Memória da máquina: no máximo dois Chrome/`flutter run` por conversa, um
  `flutter test` por vez, fechar Chromes e `dart` ao fim de cada prova. Em
  11/09 às 00:27 a máquina reiniciou por esgotamento e todas as conversas
  caíram.
- Estado vazio (decisão do Owner, ADR 0034 Decisão 13): busca, filtros com
  rótulo honesto, toggle grade/lista, Arquivos, abas de estado e o card Criar
  aparecem sempre no composto `CoeloAdminDirectory`, inclusive com zero
  registros; corrigir no composto, não na tela.
- Launcher do chat (Decisão 7): o balão "Mensagens" respeita
  `showChatLauncher=false` da tela; não aparece em criar/editar/publicar, Agora
  aberto e Momentos aberto, e nunca cobre o rodapé do formulário.
- Golden só é regravado depois de aplicar a observação do Owner e no SDK
  registrado; goldens de formulário em 375 que congelam o cabeçalho mobile
  ficam retidos enquanto MENU-M estiver aberto.

Regra do @ (Owner, 11/09/2026, ADR 0034 Decisão 16): o campo Identificador de
Instituições, Unidades, Turmas e Atividades é o campo do @ público, mantém o
ícone @, vem preenchido com o padrão hierárquico gerado pelo servidor
(`turma.unidade`, `unidade.instituicao`) e é editável com verificação de
disponibilidade enquanto digita; troca limitada a uma a cada 30 dias, com
mensagem honesta quando bloqueada. Pessoas (funcionários, responsáveis e
crianças) também têm @, mesmo sem perfil de acesso; a tela de Pessoas e a de
Alunos mostram o @ e permitem editar a quem responde pela pessoa. Não
perguntar de novo ao Owner sobre "slug versus handle".

Regras medidas pelo grupo estrutura na Rodada 4:

- Filtro que depende de opções remotas degrada, não derruba a tela (P5):
  quando `fetchFilterOptions` falha, o diretório lista, o view model expõe
  `filterOptionsUnavailable` e o rótulo do filtro ganha " (indisponível)"
  (`GroupDirectoryViewModel`); a seleção atual não é podada sem opções.
- Respiro no fim do conteúdo (P15): o scroll do `SuperadminFormFrame`
  termina com `CoeloSpacing.space10` para a última linha nunca ficar sob o
  rodapé ancorado; vale para os dezenove formulários do frame e o golden
  mobile de cada um muda por consequência (regra em
  `coelo-ui/references/form-layout-contracts.md`).
- Importar/exportar adiado (P6) remove o widget morto (seletor de arquivo,
  prévia de linhas, texto de job) em vez de escondê-lo; fica só o botão com
  a indisponibilidade honesta.
- Antes de atribuir uma falha de teste ao delta, medir a mesma suíte numa
  worktree limpa de `origin/dev` (`git worktree add --detach`): na R04, 11
  falhas de `test/shared` (`superadmin_underline_tabs_test`,
  `superadmin_form_action_footer_adoption_test`) e 7 goldens de formulário
  eram pré-existentes; os goldens divergiam só pelas regras transversais
  (Pesquisar no menu, sem chat em editar, rodapé, texto sem "prévia") e por
  isso foram regravados.
- A chave de composição (`structureMutationsEnabled`) esconde o card Criar e
  as rotas de escrita: sem ela ligada a rota real prova só leitura. Ligar a
  chave é do coordenador; o classificador do modo automático pode bloquear
  essa edição e toques do driver na conversa da frente: registrar no JSON e
  seguir no independente, não contornar.
- Rota real em debug (`flutter run -d chrome`): `tap` e `enter_text` do
  driver funcionam para login e navegação; a credencial entra por
  `enter_text` via VM Service a partir de script que lê o `.env`, nunca pelo
  chat. O renderer do Chrome travou ao avançar o assistente de Instituições
  (Continuar depois de Perfil), causa não isolada; para escrita usar o
  caminho por CDP da skill integrada.
- Locais: `LocationDirectoryPanel` tem o slot `trailing` (conteúdo rolando
  depois dos grupos) e `LocationGroupHeading` vive em
  `location_read_widgets.dart`, preparados para os cards das unidades na tela
  da instituição (pendência da R03; provado 64/64, seção ainda não ligada).
- D3, não existe prévia: nenhum texto de produção diz "prévia" ou
  "experiência completa". Ação sem destino real fica visível e inerte, ou
  responde "ainda não está disponível"; o Catálogo local não se chama
  preview. Testes que procuravam o texto antigo passam a procurar o novo.
- Ao acrescentar um método a uma interface de repositório (caso de
  `ChatRepository.createGroup`), `flutter analyze test` lista todos os fakes
  de teste a completar (27 no chat); completar no mesmo commit. O
  `UnavailableXRepository` devolve a exceção de falha da família para a tela
  responder com a mensagem honesta.
- Principal dentro do Superadmin preserva a composição aprovada por largura:
  Momentos é tela cheia até 768, moldura vertical centrada sobre preto que
  preenche a largura a partir de 840 (`expanded`) e aside "Em alta na escola"
  com Enviar momento a partir de 1200 (`large`); mídia real com
  `BoxFit.contain` sobre preto (IMG). Goldens 1024/1440 são a referência.
- Diálogo cuja altura depende de dados de produção (Criar grupo lista as
  instituições e pessoas reais) não pode ser dirigido por coordenadas na
  rota real: o clique cai fora do campo quando a lista muda. Dirigir por
  semântica ou `Key`, e conferir a captura antes de concluir que a ação
  falhou.

Decisões visuais do Owner de 11/09/2026 (respostas à Rodada 4; detalhe por
tela em `coelo-ui/references/approved-superadmin-visual-baselines.md`, seção
"Respostas do Owner de 2026-09-11"):

- **Aprovado regravar (A):** erro 409 clara e escura (P26), editor de
  Formulários em 1440 (G-FORM, 5 goldens).
- **Regravar só depois da observação (A+):** Suporte no composto (G-SUP): a
  tabela de Suporte e a de Em implantação ainda têm colunas desalinhadas
  (ex.: Origem no canto superior esquerdo); alinhar à esquerda igual à tabela
  de Instituições, no composto. Detalhe do evento da Agenda (P34): sem fundo
  cinza, ações de cancelar/excluir à esquerda e salvar/continuar à direita,
  rodapé igual ao de criar/editar Instituição.
- **Manter a referência e corrigir o render (R):** Perfil do Principal (P28)
  e calendário da Agenda (P33); as correções pedidas estão na referência da
  skill `coelo-ui` e são pendências das frentes principal-chat e publicações.
- Regra geral reafirmada: cancelar/excluir fica à esquerda e salvar/continuar
  à direita em todo rodapé de formulário; nenhum fundo cinza fora dos tokens
  do Design System.

## Regras da Rodada 6 (11/09/2026, noite)

- **Rota real pelo Flutter Driver web + CDP:** o build de
  `test_driver/qa_main.dart` expõe `window.$flutterDriver(json)`; mandar
  `set_frame_sync` com `enabled` falso logo após abrir a página; `enter_text`
  vai para o campo focado (dar `tap` no campo e esperar ~1 s); botões
  preenchidos e o Aplicar do `CoeloDateRangePicker` só respondem a clique CDP
  com `mouseMoved` ~300 ms antes e press de ~250 ms (a "falha do seletor de
  data" da R05 era do harness); `tap` por `ByText` em rótulo trava o driver:
  clicar por coordenada. Um Chrome por conversa com `--user-data-dir`
  próprio; servidor estático como tarefa em segundo plano (processo com `&`
  morre com a chamada).
- **Família Publicação vive uma vez** em
  `apps/superadmin/lib/shared/presentation/widgets/publication_surface.dart`
  (`PublicationSurface`, `PublicationLabel`, `PublicationTextField`,
  `PublicationCard`, `PublicationRow`, `PublicationChip`,
  `PublicationToggle`) e nos `Principal*Publication*` de `principal_shared`;
  Circular, Evento, Acontece, Agora e Momentos já usam; Lançar chamada ainda
  não (pendência da G3). Golden novo compara com
  `evidence/etapa-2/referencias/publicacao/aprovadas-20260911/`.
- **Regra do @ no cliente (Decisão 16):** Unidades, Turmas e Atividades usam
  `StructureHandleSetter` sobre `superadmin_structure_handle_set_v1`;
  mensagens de `SAI_HANDLE_COOLDOWN`/`TAKEN`/`INVALID_ARGUMENT`/
  `CONCURRENT_CHANGE` em `StructureHandleChange.message`; Pessoas, Alunos e
  Usuários internos reutilizam `PersonHandleSection` (usuário interno pela
  pessoa de serviço, RPC `superadmin_internal_user_service_person_v1`).
- **Sentinela novo × edição nunca é `expectedVersion == 0`:** produção
  devolve `management_version 0` para agregados recém-criados; o id vazio
  decide criação (Rotina duplicava com 23505).
- **Capacidade composta que não chega ao host é gate silencioso:** conferir
  que o router passa o repositório ao host (caso `SupabaseCircularMediaRepository`).
- **Decisão 7 por rota:** shells de módulo ganham `showChatLauncher`; criar e
  editar passam falso.
- **Estado vazio e V-15:** card Criar em todas as abas de diretório com abas
  por tipo, em cards e tabela, mesmo com dados; tipo derivado abre seletor de
  origem; tabela repete as ações do card como ícones com tooltip.
- **Cardápios (P47):** o cliente não injeta tenant; o servidor valida
  (`scopeRules` como objeto, lote 55).
- Detalhe por frente em `docs/reviews/evidence/etapa-2/r06-*/skills-deltas*.md`.
