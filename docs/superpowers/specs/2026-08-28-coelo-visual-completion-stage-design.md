---
source: "Solicitação e 69 anexos visuais aprovados pelo Owner Coelo em 2026-08-28; docs/design/design-system.md; .agents/skills/coelo-ui/SKILL.md; docs/reviews/coelo-flutter-pendencias.md; specs e designs canônicos das superfícies citadas"
status: "approved-design"
generated_at: "2026-08-28"
updated_at: "2026-08-28"
---

# Etapa de conclusão visual do Coelo

## Decisão e ordem obrigatória

Esta é a **primeira entrega obrigatória** sempre que o Owner perguntar “o que
vamos fazer agora?” ou pedir a retomada geral do Flutter. Antes de revisão
profunda, componentização ampla, Supabase ou prova ponta a ponta, o trabalho deve
concluir esta etapa visual e de navegação local.

A ordem aprovada é:

1. corrigir visual, composição responsiva, navegação e interações locais deste
   documento;
2. executar inspeção visual humana e regressão proporcional;
3. revisar/componentizar profundamente somente os arquivos tocados e os padrões
   compartilhados que se mostrarem necessários;
4. integrar os contratos produtivos com Supabase, RLS, mídia e autorização;
5. executar prova remota e ponta a ponta.

Concluir uma onda não autoriza declarar Flutter, integração ou produto completos.

## Objetivo

Deixar as superfícies indicadas visualmente coerentes com o Coelo, navegáveis e
avaliáveis com dados locais seguros, usando os anexos como referência de
anatomia e comportamento, sem copiar marcas, componentes ou identidade visual
de terceiros.

O resultado deve:

- usar o contêiner direito amplo do shell e as baselines Coelo;
- funcionar em 375, 768, 1024 e 1440 px, light/dark e texto a 200%;
- preservar teclado, foco, semântica, alvos de toque e reduced motion;
- manter ações de arquivo visíveis quando relevantes, exibindo indisponibilidade
  honesta se o backend ainda não existir;
- usar fixtures locais coerentes para permitir inspeção da UI sem fingir
  persistência, upload, publicação ou autorização reais;
- não alterar migrations, RLS, Edge Functions, Storage/R2 ou contratos remotos.

## Recorte inicial

**Modalidade:** macrotema + telas específicas.

**Incluído:** 31 entregáveis visuais distribuídos em cinco ondas, descritos
abaixo. Inclui navegação local, estados interativos, dados fictícios e testes
Flutter proporcionais.

**Fora de escopo:** revisão arquitetural completa, componentização geral do
monorepo, backend/Supabase, autorização produtiva, envio real de arquivos,
publicação real de mídia, E2E remoto e decisões jurídicas. Saúde e Cuidado não
têm bloqueio para a UI local; a base legal continua relevante somente para a
integração produtiva.

**Critério de parada:** pausar somente em limite de tempo, conflito documental
real, regressão sem correção segura ou pedido do Owner. Ao pausar, atualizar este
documento e o rastreador Flutter com itens concluídos, em andamento, restantes,
evidências, tempo usado e nova estimativa.

## Regras globais aprovadas

### Navegação e shell

- Remover dos submenus laterais todas as entradas genéricas `Criar ...`.
- Manter `Nova chamada` dentro de Assiduidade.
- Manter as entradas `Publicar ...` próprias de Acontece, Momentos e Agora.
- O dashboard de Assiduidade não repete um segundo CTA de chamada: a entrada do
  menu é a ação autoritativa.
- Todo item visível deve abrir sua rota ou comunicar indisponibilidade; clique
  morto é regressão.
- A troca de rota mantém shell e geometria estáveis, alterando apenas o conteúdo
  direito.

### Arquivos e ações ainda não integradas

- Importar, exportar e baixar permanecem visíveis quando pertencem à tarefa do
  usuário.
- Sem implementação produtiva, a ação fica desabilitada ou abre explicação
  `Indisponível nesta etapa`, sem SnackBar de sucesso, arquivo inventado ou
  chamada remota.
- Essa decisão substitui a remoção visual anterior de ações `fail-closed`; a
  segurança continua fail-closed, mas a capacidade futura permanece
  compreensível na interface.

### Diretórios, cards e formulários

- Instituições é a baseline para diretórios, Cards/Tabela, filtros, criação e
  flyouts.
- Criar/Editar Instituição é a baseline de todos os wizards e rodapés de criar e
  editar, inclusive Unidade, Turma, Atividade, Pessoa, Perfil, Cardápio e demais
  entidades.
- Cards exibem informação operacional útil quando disponível; não devem ser
  caixas vazias nem duplicar toda a tela de detalhe.
- Calendário Coelo é obrigatório em datas. Campos de hora devem adotar um
  seletor Coelo análogo, nunca o picker Material cru.

### Referências externas

Os anexos de Instagram e as composições de referência de 375/768/1440 são
referências conceituais de proporção, hierarquia, imersão e responsividade. O
resultado usa Nunito Sans, laranja `#D63C00`, grafite `#3F4549`, tokens, ícones,
componentes e linguagem do Coelo. Nenhuma marca externa aparece no produto.

## Ondas e entregáveis

### V1 — Fundação e navegação — 5 entregáveis — 10–14 h

1. **Login:** remover hover cinza de `Manter sessão aberta`; clique no controle,
   rótulo ou linha alterna o checkbox; foco permanece visível.
2. **Conversas:** launcher e item lateral abrem Conversas sem falha, clique morto
   ou perda do shell.
3. **Menu lateral:** aplicar a regra global de remoção/manutenção de entradas e
   corrigir todos os itens visíveis que não respondem.
4. **Shell/conteúdo:** alinhar páginas ao contêiner direito grande, sem área
   estreita ou deslocamento entre rotas.
5. **Arquivos:** restaurar visualmente ações pertinentes de importar, exportar e
   baixar com estado indisponível honesto quando ainda não houver operação.

### V2 — Estrutura e operação escolar — 6 entregáveis — 18–28 h

6. **Turmas/Grupos:** cards mostram tipo, número de alunos, atividades e
   professores/responsáveis, com hierarquia equivalente ao diretório canônico.
7. **Rodapé universal:** aplicar o rodapé de Criar/Editar Instituição a todas as
   criações e edições atingidas por esta etapa.
8. **Atividade e modelo:** clicar em Atividade abre edição; duplicar modelo pede
   novo nome; criar modelo usa o wizard de Atividade sem a etapa de vínculos.
9. **Assiduidade:** alinhar dashboard/chamada aos anexos; remover CTA duplicado;
   cada aluno recebe ação Salvar e seletor de sentimento; fixtures demonstram
   vínculo com Rotina diária.
10. **Rotina diária:** enriquecer cards, alinhar contêiner, oferecer duplicação e
    criação a partir de modelo em fluxo local demonstrável.
11. **Acompanhamento do aluno:** garantir diretório/superfície visível e
    navegável com exemplos locais suficientes para inspeção.

### V3 — Acessos, cuidado e alimentação — 7 entregáveis — 18–28 h

12. **Segurança infantil:** alinhar diretório e wizard; todas as etapas avançam,
    voltam e preservam o rascunho local.
13. **Usuários internos:** edição abre; CPF usa máscara brasileira; nascimento
    usa o calendário Coelo.
14. **Perfis e modelos de acesso:** lista, criação, detalhe e edição ficam
    visíveis e navegáveis localmente, sem ampliar permissão no cliente.
15. **Perfis de cuidado:** criação e edição adotam o wizard e o rodapé canônicos.
16. **Medicação — diretório:** primeiro card cria plano; exemplos locais permitem
    abrir detalhe e editar o mesmo item.
17. **Medicação — wizard:** datas usam calendário Coelo e a composição elimina
    espaçamentos/agrupamentos divergentes.
18. **Cardápio/modelo:** horário fica logo abaixo do nome da refeição, abre o
    seletor de hora Coelo e inclui campo de detalhes.

### V4 — Formulários e comunicação administrativa — 5 entregáveis — 24–38 h

19. **Formulários — diretório:** Cards/Tabela canônicos e três a cinco exemplos
    locais representativos.
20. **Formulários — editor:** construtor completo conforme a spec aprovada:
    seções, tipos de pergunta, opções, mídia de apoio, obrigatoriedade,
    ramificação, agendamento, duplicar e copiar para outro contexto autorizado.
21. **Importações:** diretório e wizard seguem Instituições e Criar/Editar
    Instituição, mantendo operações remotas indisponíveis de forma explícita.
22. **Comunicações:** diretório, busca, filtros, categorias, lista/tabela e
    prévia seguem a anatomia Coelo indicada pelo anexo de referência.
23. **Circulares:** criar a superfície ausente de lista e criação, ligada ao
    Perfil e à projeção no Acontece conforme a spec canônica.

### V5 — Experiência Principal e mídia — 8 entregáveis — 24–38 h

24. **Acontece — estrutura:** remover o botão superior `Publicar no Acontece` e
    a barra interna redundante Acontece/Para você/Momentos/Perfil; inserir
    divisor sutil entre Agora e o feed.
25. **Agora no Acontece:** primeiro card vazio publica no Agora; remover `Ver
    tudo`; permitir arraste horizontal; abrir viewer em tela cheia escura, com
    leve transparência e logo Coelo branca.
26. **Galeria do Acontece:** mídia do post abre e permite navegar entre itens com
    contagem e ações acessíveis.
27. **Publicar no Acontece:** alinhar composer responsivo de 375/768/1440 à
    referência, preservando identidade e contratos Coelo.
28. **Para você:** corrigir composição, imagens, respiro e responsividade dentro
    do contêiner amplo, sem alterar os textos editoriais aprovados.
29. **Momentos:** viewer imersivo em tela cheia inspirado em Reels, com ações,
    navegação e comentários em composição própria do Coelo.
30. **Perfil do Principal:** enriquecer fixture e composição com capa, avatar
    maior, Acontece, Momentos, Circulares e Sobre.
31. **Publicar Momentos e Agora:** alinhar os dois composers responsivos às
    referências aprovadas, sem compartilhar domínio, repository ou ownership.

## Mapeamento dos anexos

| Grupo visual | Anexos fornecidos | Uso autorizado |
|---|---|---|
| Login, chat, menu e navegação | 1–3 | Correção direta da superfície Coelo. |
| Assiduidade e Rotina diária | 4–8 | Anatomia, cards e interações locais. |
| Usuários, perfis e cuidado | 9–19 | Diretórios, wizards, máscaras, calendário e cards. |
| Cardápio, Formulários, Importações e Comunicações | 20–54 e 69 | Composição administrativa e construtor. |
| Acontece e publicação | 55–58 | Feed, Agora, galeria e composer responsivo. |
| Para você | 59–60 | Composição responsiva dentro do Principal. |
| Momentos e comentários | 61–65 | Imersão, proporção e interação; sem copiar Instagram. |
| Perfil do Principal | 66 | Hierarquia de capa, identidade e seções. |
| Publicar Momentos/Agora | 67–68 | Composers responsivos com identidade Coelo. |

Se a numeração do cliente mudar, prevalece o conteúdo descrito neste documento,
não o número isolado do anexo.

## Auditoria de padrões `coelo-ui`

### Já existentes e obrigatórios

- `pattern.approved-superadmin-surfaces` para Login, Instituições, shell e
  Criar/Editar Instituição;
- `pattern.interaction-states` para hover/foco sem overlay cinza;
- `pattern.admin-directory`, Cards/Tabela e ações de arquivo;
- `SuperadminFormActionFooter` e contratos de wizard;
- calendários, campos de data, seleção, toggles, cards e flyouts canônicos.

### Gaps a promover antes do código correspondente

1. `pattern.form-question-builder`: seção, item ativo, catálogo fechado,
   reordenação acessível, ramificação e estados de autosave.
2. `pattern.coelo-time-picker`: seletor de hora pt-BR, teclado, confirmação,
   compact/wide, light/dark e texto a 200%.
3. `pattern.principal-social-viewer`: viewer imersivo de Agora/Momentos, mídia,
   navegação, ações, comentários, safe areas e identidade Coelo.
4. `pattern.principal-rich-profile`: capa, avatar, identidade, métricas e seções
   Acontece/Momentos/Circulares/Sobre sem importar `coelo_ui_admin`.

Cada gap exige referência pública na skill, entrada consultável no índice,
exemplo executável no catálogo quando reutilizável e teste/golden do estado
aprovado. A promoção ocorre no início da onda que o consome; não se programa o
componente antes de aprovar o contrato visual Coelo.

## Dados locais e comportamento

- Fixtures devem usar pessoas, instituições, unidades e turmas fictícias,
  claramente demonstrativas e sem PII real.
- Criar, duplicar, editar, salvar sentimento, navegar por mídia e avançar wizard
  devem funcionar localmente quando fazem parte do aceite acima.
- Recarregar pode reiniciar fixtures nesta etapa; a interface deve comunicar
  `Demonstração local` quando isso puder surpreender o usuário.
- Nenhuma ação local pode ser descrita como publicada, enviada, importada ou
  persistida no backend.

## Evidências por entregável

Um item visual só fecha quando possui:

1. teste comportamental RED→GREEN para a interação corrigida;
2. inspeção em 375, 768, 1024 e 1440 px;
3. light/dark e texto a 200%;
4. teclado, foco, Escape e semântica aplicáveis;
5. comparação visual com a baseline/anexo aprovado;
6. `dart analyze`, testes focados, validador visual e `git diff --check` verdes;
7. registro no rastreador com arquivos, resultado, tempo e pendências.

Goldens só são atualizados após inspeção humana confirmar que a nova imagem é a
verdade aprovada. Abrir a página, executar rota `/dev` ou passar teste isolado
não basta.

## Métricas e relatório obrigatório

Cada checkpoint e entrega ao Owner deve mostrar separadamente:

- **entrega visual atual:** `itens aceitos / itens da onda`;
- **programa visual:** `entregáveis aceitos / 31`;
- **Flutter geral:** ações `local-green` ou `verified` sobre 207, mantendo os
  dois estados separados no texto;
- **Supabase:** famílias `done / 37` e, separadamente, famílias apenas
  `local-green`;
- **integração:** ações `verified_e2e / 202`;
- **projeto estrito:** unidades `strict_done / 229`, explicado como conclusão
  ponta a ponta, nunca como negação do trabalho local já feito.

Não reutilizar `0/207 E2E` como “progresso Flutter”. Essa métrica pertence ao
rastreador integrado.

## Estimativa inicial

| Fatia | ETA |
|---|---:|
| V1 — Fundação e navegação | 10–14 h |
| V2 — Estrutura e operação escolar | 18–28 h |
| V3 — Acessos, cuidado e alimentação | 18–28 h |
| V4 — Formulários e comunicação | 24–38 h |
| V5 — Principal e mídia | 24–38 h |
| Regressão visual transversal e consolidação | 10–14 h |
| **Total inicial** | **104–160 h** |

A faixa considera código existente reutilizável, ausência de backend e revisão
visual humana entre ondas. Após V1, recalcular as demais faixas com o custo real
observado. Uma janela de 10 h cobre V1 parcialmente ou integralmente; não cobre
os 31 entregáveis.

## O que acontece depois da entrega visual

1. inventário de arquivos grandes, duplicações e componentes locais nas
   superfícies tocadas;
2. planos pequenos de componentização, um subsistema por vez, com TDD e revisão;
3. reconciliação das specs produtivas e perguntas abertas de cada domínio;
4. implementação Supabase por dependência: Auth/capabilities, dados, RLS/RPC,
   arquivos/mídia e auditoria;
5. integração Flutter–Supabase, negativas cross-tenant e read-after-write;
6. regressão completa, goldens aprovados e fechamento ponta a ponta.

## Riscos e decisões preservadas

- O construtor de Formulários e os viewers sociais são entregas grandes, apesar
  de pertencerem à fase visual; não devem ser comprimidos em patches cosméticos.
- Exibir uma ação futura indisponível não autoriza callback vazio ou sucesso
  falso.
- Fixtures ricas não podem vazar para rotas produtivas nem ocultar estados de
  erro/sem permissão.
- A referência externa pode conter padrões incompatíveis com acessibilidade,
  privacidade infantil ou identidade Coelo; nesses casos, prevalecem os
  contratos canônicos do projeto.
- Trabalho concorrente ou não commitado em Avaliações deve permanecer intocado.

## Aprovação e retomada

O conteúdo desta spec reflete a direção aprovada pelo Owner em 2026-08-28. Antes
de iniciar código, apresentar V1 como primeiro pacote, sua ETA e os critérios de
aceite. Se o Owner pedir pausa, atualizar esta spec e o checkpoint correspondente
no mesmo turno. O plano de implementação detalhado só deve ser escrito depois da
revisão desta spec pelo Owner.

## Checkpoint de execução V1 — 2026-08-28 11:21 BRT

| Campo | Registro |
|---|---|
| Status | `in-progress` — 0/5 entregáveis V1 `local-green` ou `accepted` (0,00%). |
| Recorte | Login → Conversas → Menu lateral → Shell/contêiner → Arquivos, nesta ordem. |
| Rotas iniciais | Login; `/communication/conversations`; shell persistente; diretórios administrativos com ações de arquivo pertinentes. |
| Programa autorizado | V1–V5, 31 entregáveis, rigorosamente em ordem. V2 começa assim que V1 ficar `local-green`; a janela inicial de 10 h é checkpoint, não encerramento das ondas seguintes. |
| Fora do recorte V1 | Durante V1: revisão arquitetural profunda, componentização ampla, Supabase, migrations, RLS, RPCs, Edge Functions, Storage/R2, persistência/publicação/download reais e os quatro arquivos dirty de Avaliações. V2–V5 permanecem no programa, apenas aguardam a conclusão sequencial da V1. |
| Evidência inicial | Baseline focado com 96/96 testes verdes; novos REDs são obrigatórios porque o baseline não cobre todos os comportamentos solicitados. |
| Inspeções exigidas | 375/768/1024/1440 px, texto a 200%, light/dark, teclado, foco, Escape, semântica, alvos de toque e reduced motion. |
| Tempo usado | 0 h de execução no início deste checkpoint. |
| Orçamento e ETA | 10 h autorizadas; V1 estimada em 10–14 h. Parar em checkpoint seguro se a janela terminar. |
| Bloqueios | Nenhum no início. Alterações concorrentes de Avaliações permanecem intocadas. |
| Próximo item exato | Criar REDs do Login para hover, clique por controle/rótulo/linha e foco/teclado; então aplicar a correção mínima local. |

Percentuais de abertura: programa visual 0/31 `accepted` (0,00%); Flutter
`local-green` 84/207 (40,58%); Flutter `verified` 0/207 (0,00%);
Supabase `local-green` 3/37 (8,11%); Supabase `done` 0/37 (0,00%);
integração `verified_e2e` 0/202 (0,00%); projeto `strict_done` 0/229
(0,00%). As duas últimas métricas medem conclusão integral e não anulam a
evidência local já obtida.

### V1.1 Login — checkpoint local-green — 2026-08-28 11:29 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; 1/5 entregáveis V1 (20,00%). `accepted` depende de aprovação visual humana. |
| Tela e rota | Login do Superadmin. |
| Arquivos alterados | `superadmin_login_form.dart`; `superadmin_login_screen_test.dart`; spec e rastreador. |
| Correções | “Manter sessão aberta” virou uma única superfície sem overlay cinza; controle, rótulo e linha alternam o valor; Space/Enter, semântica de checkbox, foco primário visível e alvo mínimo de 48 px foram preservados. |
| Testes | RED reproduzido em três cenários; GREEN 18/18. Analyzer focado sem issues; formatter e `git diff --check` verdes. |
| Responsividade | 375/768/1024/1440 px, light/dark e texto a 200%; sem overflow. |
| Bloqueios | Inspeção visual humana e aceite permanecem pendentes; nenhum bloqueio de código local. |
| Tempo usado | 0 h 07 min. |
| Estimativa restante | 9 h 53 min da janela autorizada; 9 h 53 min–13 h 53 min pela faixa original da V1. |
| Próximo item exato | Conversas: escrever REDs para launcher/item lateral, saída de Conversas para destino antes não mapeado e ausência de launcher visível sem callback. |

Percentuais: programa visual 0/31 `accepted` (0,00%); Flutter `local-green`
84/207 (40,58%); Flutter `verified` 0/207; Supabase `local-green` 3/37
(8,11%); Supabase `done` 0/37; integração 0/202; projeto estrito 0/229.
E2E e estrito medem conclusão integral e não anulam este GREEN local.

### V1.2 Conversas — checkpoint local-green — 2026-08-28 11:36 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; 2/5 entregáveis V1 (40,00%). `accepted` depende de aprovação visual humana. |
| Tela e rota | Launcher e item lateral → `/communication/conversations` e `/dev/communication/conversations`; saída para Atividades. |
| Arquivos alterados | `superadmin_router.dart`; `superadmin_shell.dart`; `chat_routes_test.dart`; `superadmin_shell_test.dart`; spec e rastreador. |
| Correções | Conversas usa os mapeadores centrais produtivo e `/dev`; launcher e item lateral preservam o shell; launcher sem capability não é renderizado, eliminando callback vazio. |
| Testes | RED do launcher morto reproduzido; GREEN conjunto 70/70. Analyzer focado sem issues; formatter verde. |
| Responsividade | A suíte do shell cobre 375/768/1024/1440 px, light/dark, texto ampliado e reduced motion; rota também foi exercitada no shell persistente. |
| Bloqueios | Inspeção visual humana e aceite pendentes; conteúdo remoto do chat continua fora do recorte. |
| Tempo usado | 0 h 07 min neste entregável; 0 h 14 min acumulados. |
| Estimativa restante | 9 h 46 min da janela autorizada; 9 h 46 min–13 h 46 min pela faixa original. |
| Próximo item exato | Menu lateral: RED para ausência de rótulos `Criar ...`, preservação de `Nova chamada` e dos três `Publicar ...`, mantendo capabilities das mutações restantes. |

Percentuais: programa visual 0/31 `accepted`; Flutter `local-green` 84/207
(40,58%); Flutter `verified` 0/207; Supabase `local-green` 3/37 (8,11%);
Supabase `done` 0/37; integração 0/202; projeto estrito 0/229. E2E e
estrito medem conclusão integral e não anulam este GREEN local.

### V1.5 Arquivos — checkpoint RED — 2026-08-28 11:48 BRT

| Campo | Registro |
|---|---|
| Status | `in-progress`; 4/5 entregáveis V1 (80,00%). `accepted` continua reservado à aprovação visual humana. |
| Telas e rotas | Instituições, Turmas/Grupos, Pessoas, Cuidado/Medicação, Segurança, Atividades, Rotina diária, Suporte e Pessoas da Unidade. |
| Arquivos alterados | Testes focados das nove superfícies; spec e rastreador. Nenhum arquivo de produção alterado neste checkpoint. |
| REDs confirmados | Ações pertinentes estavam escondidas sem callback em sete superfícies; Suporte anunciava exportação preparada sem arquivo; Pessoas da Unidade não expunha exportação. Os testes agora exigem ações visíveis e a mensagem exata `Indisponível nesta etapa`, sem atividade, URL, arquivo, chamada remota ou persistência falsa. |
| Regressões encontradas | Testes antigos de Cuidado e Atividades ainda esperavam launcher mesmo sem capability de navegação; serão alinhados ao contrato V1.2 injetando callback quando o launcher for parte do cenário. O golden de Segurança divergiu 9,84% antes da correção de produção; não será atualizado automaticamente. |
| Testes | RED conjunto executado e falhas esperadas observadas nas nove superfícies. A execução ampla foi interrompida depois de capturar os REDs e a divergência do golden; GREEN focado e regressão não-golden permanecem pendentes. |
| Bloqueios | Golden de Segurança requer inspeção/aceite visual humano para qualquer atualização. Não bloqueia as correções locais não-golden. Avaliações permanecem intocadas. |
| Tempo usado | 0 h 27 min acumulados. |
| Estimativa restante | 9 h 33 min da janela inicial; programa V1–V5 permanece estimado em 104–160 h e seguirá por checkpoints. |
| Próximo item exato | Implementar primeiro o fallback canônico de Instituições; depois Turmas/Grupos, Pessoas, Cuidado/Segurança, Atividades/Rotina, Suporte e Pessoas da Unidade. Concluída V1, iniciar V2.6 Turmas/Grupos. |

Percentuais: programa visual 0/31 `accepted` (0,00%); Flutter
`local-green` 84/207 (40,58%); Flutter `verified` 0/207; Supabase
`local-green` 3/37 (8,11%); Supabase `done` 0/37; integração 0/202;
projeto estrito 0/229. E2E e estrito medem conclusão integral e não anulam
o progresso Flutter local.

### V1.5 Arquivos — checkpoint local-green — 2026-08-28 12:00 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; 5/5 entregáveis V1 (100,00%). `accepted` depende de aprovação visual humana. |
| Telas e rotas | Instituições, Turmas/Grupos, Pessoas, Cuidado/Medicação, Segurança, Atividades, Rotina diária, Suporte e Pessoas da Unidade; produção e `/dev` de Atividades. |
| Arquivos alterados | Widgets/páginas das nove superfícies; router e repository `/dev` de Atividades; testes focados; spec e rastreador. |
| Correções | `CoeloAdminFileActions` permanece visível quando pertinente; callbacks reais continuam operacionais; ausência de capability retorna exatamente `Indisponível nesta etapa`. Suporte deixou de anunciar exportação preparada, Pessoas da Unidade deixou de abrir prévia fictícia e a exportação `/dev` de Atividades deixou de produzir `dev.invalid`. Nenhuma operação cria atividade concluída, arquivo, URL, chamada remota ou persistência falsa. |
| Testes | REDs observados antes do código. GREEN: 17/17 Instituições+Pessoas+Grupos; 86/86 Cuidado+Suporte+Atividades+Rotina+Unidade; 5/5 repository `/dev`; 3/3 gates não-golden de Segurança; 2/2 gates do flyout, incluindo Escape e retorno de foco. Total relevante: 113 testes verdes. Analyzer focado e `git diff --check` sem issues. |
| Responsividade e acessibilidade | Cobertura existente e focada em 375/768/1024/1440, light/dark e texto 200%; alvos canônicos; flyout por teclado, Escape e retorno de foco verdes. |
| Bloqueios | Golden legado de Segurança divergiu 9,84% antes do GREEN e não foi atualizado automaticamente; requer inspeção/aceite visual humano. Avaliações continuam intocadas. |
| Tempo usado | 0 h 39 min acumulados. |
| Estimativa restante | 9 h 21 min da janela inicial; programa restante V2–V5 mantém ordem e será recalculado após os gates. |
| Próximo item exato | Gates finais V1 e commit seguro; em seguida V2.6 Turmas/Grupos: cards com tipo, alunos, atividades e professores/responsáveis. |
| Conhecimento | `no-op`: foram aplicadas regras duráveis já aprovadas (`admin.file-actions` e indisponibilidade honesta). |

Gate adicional às 12:06 BRT: o validador administrativo inicialmente falhou
porque o Login ainda continha `InkWell` cru e uma exceção obsoleta de
`CheckboxListTile`. A interação foi migrada para primitives focáveis sem overlay,
a allowlist obsoleta foi removida, Login voltou a 18/18 e o validador ficou
GREEN. A suíte final de Shell, Navegação, Conversas, rotas persistentes e rotas
de Atividades passou 106/106. O comportamento e os percentuais não mudaram;
tempo acumulado: 0 h 45 min.

### V2.6 Turmas/Grupos — abertura — 2026-08-28 12:06 BRT

| Campo | Registro |
|---|---|
| Status | `in-progress`; V1 terminou 5/5 `local-green`; V2 inicia 0/6 `local-green` ou `accepted` (0,00%). |
| Tela e rota | Diretório de Turmas/Grupos em produção e `/dev`, visão Cards como primeiro recorte. |
| Contrato visual consultado | `pattern.admin-directory`, `admin.interactive-card`, `pattern.institution-card-status`, `pattern.compact-directory-cards`, `pattern.responsive-directory-filters` e `pattern.stable-route-content-transition`; Instituições permanece baseline. |
| Correção pretendida | Cada card deve mostrar tipo, quantidade de alunos, quantidade de atividades e professores/responsáveis com fixtures locais seguras, sem copiar identidade externa ou introduzir backend. |
| RED esperado | O teste atual prova que Atividades, Responsáveis e Crianças/Alunos não aparecem no card; será invertido para exigir a anatomia aprovada e dados locais explícitos. |
| Responsividade | Revalidar 375/768/1024/1440, texto 200%, light/dark, foco, teclado, alvo e reduced motion do card canônico. |
| Bloqueios | Nenhum de código no início; `accepted` continua dependente de inspeção visual humana. Assessments permanece intocado. |
| Tempo usado | 0 h 45 min acumulados. |
| Estimativa | 1–2 h para V2.6; 9 h 15 min restam na janela inicial. |
| Próximo item exato | Alterar o teste do primeiro card para exigir tipo, alunos, atividades e professores/responsáveis; executar RED antes do código. |

Percentuais: entrega V2 0/6 (0,00%); programa visual 0/31 `accepted`
(0,00%); Flutter `local-green` 84/207 (40,58%); Flutter `verified` 0/207;
Supabase `local-green` 3/37 (8,11%); Supabase `done` 0/37; integração 0/202;
projeto estrito 0/229. E2E e estrito medem conclusão integral e não anulam a
V1 localmente concluída.

### V2.6 Turmas/Grupos — checkpoint local-green — 2026-08-28 12:13 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; V2 = 1/6 (16,67%). `accepted` depende de aprovação visual humana. |
| Tela e rota | Diretório de Turmas/Grupos, visão Cards, produção e `/dev`. |
| Arquivos alterados | `group_directory.dart`; `fake_group_directory_repository.dart`; `group_directory_page.dart`; `group_directory_page_test.dart`; spec e tracker. |
| Correções | Cards canônicos agora mostram tipo da turma, alunos, atividades e professores/responsáveis; fixtures locais fornecem contagens e nomes seguros; produção sem dados exibe valores honestos via defaults, sem backend simulado. Alturas responsivas preservam alinhamento entre card e tile de criação. |
| Testes | RED de campos ausentes reproduzido. GREEN: 19/19 Grupos e 8/8 card/status compartilhados; analyzer focado, validador administrativo e diff-check verdes. |
| Responsividade | Testes cobrem 375/768/1024/1440 e texto 200%; goldens foram comparados em quatro larguras, light/dark. Inspeção das saídas light 375/768/1440 confirmou leitura e ausência de corte interno. Foco, teclado, alvo e reduced motion vêm do card/status canônicos e passaram 8/8. |
| Goldens e bloqueios | 16 referências antigas de Cards/Tabela divergem 22,53%–40,14% pelas mudanças deliberadas de V2.6 e Arquivos V1. Não foram atualizadas automaticamente; exigem aprovação visual humana. Isso impede `accepted`, não o GREEN comportamental local. |
| Tempo usado | 0 h 07 min no item; 0 h 52 min acumulados. |
| Estimativa restante | 9 h 08 min da janela inicial; V2.7 estimada em 1–2 h após inventário. |
| Próximo item exato | V2.7: inventariar criação/edição administrativa e escrever RED para adoção universal de `SuperadminFormActionFooter`, usando Criar/Editar Instituição como baseline. |
| Conhecimento | `no-op`: aplicação do contrato visual e comportamento já aprovados. |

Percentuais: entrega V2 1/6 `local-green` ou `accepted` (16,67%); programa
visual 0/31 `accepted` (0,00%); Flutter `local-green` 84/207 (40,58%);
Flutter `verified` 0/207; Supabase `local-green` 3/37 (8,11%); Supabase `done`
0/37; integração 0/202; projeto estrito 0/229. E2E e estrito medem conclusão
integral e não anulam a V1 nem o V2.6 locais.

### V2.7 Rodapé universal — abertura — 2026-08-28 12:13 BRT

| Campo | Registro |
|---|---|
| Status | `in-progress`; V2 permanece 1/6 (16,67%). |
| Superfícies | Criação, edição, editor e wizard administrativos do Superadmin; dialogs e páginas somente leitura ficam fora por contrato. |
| Baseline e índice | Criar/Editar Instituição, `pattern.form-controls`, `superadmin.form-action-footer`, `pattern.form-frame-geometry` e `pattern.action-hierarchy`. |
| Inventário inicial | Todos os arquivos reais nomeados `form_page`, `form_pages` ou `wizard_page` já consomem `SuperadminFormActionFooter`; wrappers e páginas de resposta/diretório não são formulários de criação/edição. Nenhuma correção de produção foi demonstrada até aqui. |
| Evidência planejada | Gate de adoção explícito para as superfícies atuais, suíte do footer em 375/1024 e texto 200%, mais amostra de formulários/wizards em 375/768/1024/1440. |
| Bloqueios | Nenhum; se o gate não encontrar infrator real, o item será `local-green` por evidência, sem reescrita artificial. |
| Tempo usado | 0 h 52 min acumulados. |
| Estimativa | 0 h 30–1 h após o inventário; 9 h 08 min restam na janela. |
| Próximo item exato | Adicionar e executar o gate de adoção do footer canônico, preservando as exclusões semânticas de páginas que não criam/editam. |

Percentuais: entrega V2 1/6 (16,67%); programa visual 0/31 `accepted`;
Flutter `local-green` 84/207 (40,58%); Flutter `verified` 0/207; Supabase
`local-green` 3/37 (8,11%); Supabase `done` 0/37; integração 0/202; projeto
estrito 0/229. E2E e estrito medem conclusão integral e não anulam o trabalho
local.

### V2.7 Rodapé universal — checkpoint local-green — 2026-08-28 12:17 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; V2 = 2/6 (33,33%). `accepted` depende de aprovação visual humana. |
| Superfícies | 23 consumidores atuais de criação/edição/editor/wizard do Superadmin; Assessments apenas lido pelo gate, sem alteração. |
| Arquivos alterados | Novo `superadmin_form_action_footer_adoption_test.dart`; spec e tracker. Nenhum código de produção. |
| Resultado | O inventário não encontrou formulário administrativo real reconstruindo o footer localmente. Seis páginas sem o componente são diretórios, respostas, testes ou wrappers que delegam ao formulário canônico. |
| Testes | Gate de adoção 2/2; componente 5/5; matrizes focadas de Turmas e Unidades 2/2; total 9/9. Analyzer focado e diff-check verdes. |
| Responsividade | Componente validado em compacto, constraints intermediárias, 1024 e texto 200%; consumidores de Turmas/Unidades cobrem 375/768/1024/1440, light/dark e 200%. |
| Bloqueios | Nenhum local; `accepted` visual humano pendente. Assessment dirty não foi modificado, formatado ou staged. |
| Tempo usado | 0 h 04 min no item; 0 h 56 min acumulados. |
| Estimativa restante | 9 h 04 min da janela; V2.8 estimada em 1–2 h após o RED. |
| Próximo item exato | V2.8 Atividades/Modelos: provar abrir edição, duplicar solicitando novo nome e criar modelo pelo wizard sem vínculos. |
| Conhecimento | `no-op`: o gate torna executável um contrato já aprovado. |

Percentuais: entrega V2 2/6 (33,33%); programa visual 0/31 `accepted`;
Flutter `local-green` 84/207 (40,58%); Flutter `verified` 0/207; Supabase
`local-green` 3/37 (8,11%); Supabase `done` 0/37; integração 0/202; projeto
estrito 0/229. E2E e estrito medem conclusão integral e não anulam os GREENs
locais.

Percentuais de fechamento local da onda: entrega atual 5/5 `local-green` ou
`accepted` (100,00%); programa visual 0/31 `accepted` (0,00%); Flutter
`local-green` 84/207 (40,58%); Flutter `verified` 0/207; Supabase
`local-green` 3/37 (8,11%); Supabase `done` 0/37; integração 0/202; projeto
estrito 0/229. E2E e estrito medem conclusão integral e não anulam o trabalho
Flutter local.

### V1.4 Shell e contêiner — checkpoint local-green — 2026-08-28 11:42 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; 4/5 entregáveis V1 (80,00%). `accepted` depende de aprovação visual humana. |
| Tela e rota | `/dev/institutions` → `/dev/communication/conversations` → `/dev/access/people` no host persistente. |
| Arquivos alterados | `persistent_shell_routes_test.dart`; spec e rastreador. Nenhum código de produção precisou mudar. |
| Validação | Mesma instância do shell e mesma geometria do contêiner entre rotas; em 1024/1440 o conteúdo direito ocupa mais de 55% da largura e termina no gutter canônico. |
| Testes | Novo cenário focado 1/1 e suíte integral de rotas persistentes 15/15; analyzer focado sem issues; formatter verde. |
| Responsividade | 375/768/1024/1440 px com texto 200%; light/dark e reduced motion permanecem verdes na suíte conjunta do shell do checkpoint anterior. |
| Bloqueios | Inspeção visual humana e aceite pendentes; nenhum bloqueio local ou correção segura adicional encontrada. |
| Tempo usado | 0 h 03 min neste entregável; 0 h 21 min acumulados. |
| Estimativa restante | 9 h 39 min da janela autorizada; 9 h 39 min–13 h 39 min pela faixa original. |
| Próximo item exato | Arquivos: REDs em Instituições, Turmas/Grupos e Pessoas para manter ações visíveis e retornar exatamente `Indisponível nesta etapa`, sem atividade, arquivo, URL ou sucesso falso. |

Percentuais: programa visual 0/31 `accepted`; Flutter `local-green` 84/207
(40,58%); Flutter `verified` 0/207; Supabase `local-green` 3/37 (8,11%);
Supabase `done` 0/37; integração 0/202; projeto estrito 0/229. E2E e
estrito medem conclusão integral e não anulam este GREEN local.

### V1.3 Menu lateral — checkpoint local-green — 2026-08-28 11:39 BRT

| Campo | Registro |
|---|---|
| Status | `local-green`; 3/5 entregáveis V1 (60,00%). `accepted` depende de aprovação visual humana. |
| Tela e rota | Árvore lateral, busca inline e busca recolhida; CTAs próprios das telas mantêm as rotas de criação fora do menu. |
| Arquivos alterados | `superadmin_navigation.dart`; `superadmin_navigation_test.dart`; spec e rastreador. |
| Correções | Removidas 18 entradas genéricas `Criar ...`; preservadas `Nova chamada`, `Publicar no Acontece`, `Publicar em Momentos` e `Publicar no Agora`; rotas de criação não foram removidas do router. |
| Testes | RED reproduziu IDs/rótulos e buscas antigos; GREEN navegação 15/15 e conjunto Navegação+Chat 20/20. Analyzer focado sem issues; formatter verde. |
| Interação | Busca, breadcrumbs, teclado, foco e Escape foram exercitados; callbacks centrais do lote anterior cobrem os destinos visíveis preservados. |
| Bloqueios | Inspeção visual humana e aceite pendentes; nenhum bloqueio local. |
| Tempo usado | 0 h 04 min neste entregável; 0 h 18 min acumulados. |
| Estimativa restante | 9 h 42 min da janela autorizada; 9 h 42 min–13 h 42 min pela faixa original. |
| Próximo item exato | Shell/contêiner: validar Instituições → Conversas → outro diretório na mesma instância e medir a superfície direita em 375/768/1024/1440 com texto 200%. |

Percentuais: programa visual 0/31 `accepted`; Flutter `local-green` 84/207
(40,58%); Flutter `verified` 0/207; Supabase `local-green` 3/37 (8,11%);
Supabase `done` 0/37; integração 0/202; projeto estrito 0/229. E2E e
estrito medem conclusão integral e não anulam este GREEN local.
