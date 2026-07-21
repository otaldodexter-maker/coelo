---
title: "Protótipo refinado de arquivos, notificações, tema e tours do Superadmin"
source: "Solicitações aprovadas pelo usuário em 2026-07-21"
status: "review"
generated_at: "2026-07-21"
revised_at: "2026-07-21"
---

# Protótipo refinado de arquivos, notificações, tema e tours do Superadmin

## Objetivo

Validar, sem backend, a experiência de importar e exportar instituições, acompanhar trabalhos em segundo plano pelo sininho e refinar os controles de tema e onboarding do shell. O diretório de Instituições preserva sua estrutura, seus filtros, seus cards e sua tabela; a ação de arquivos passa a integrar discretamente a barra de filtros.

## Escopo

- Uma ação responsiva `Arquivos` no final da barra de filtros, próxima ao seletor de visualização, com submenu para `Importar`, `Exportar CSV` e `Exportar XLSX`.
- Importação demonstrativa em duas etapas com o arquivo fictício `instituicoes-julho.xlsx`, prévia, confirmação e progresso 0/25/55/80/100 a cada 600 ms.
- Resultado padrão `Parcial`: 24 registros importados e 2 rejeitados.
- Opção `Exportar modelo XLSX` dentro do modal de importação, apresentando o padrão esperado de colunas.
- Exportações e downloads continuam demonstrativos: nenhuma opção gera, salva ou transfere um arquivo real nesta fase.
- Central de notificações com importações, exportações e novidades; badge de concluídas não vistas.
- Data e hora local em cada atividade, aplicáveis a importações, exportações e anúncios.
- Status `Em andamento`, `Concluída`, `Parcial` e `Falhou`, com cor sempre acompanhada por texto/semântica.
- Seletor de tema com cenoura flat redesenhada, formato horizontal expandido e vertical recolhido.
- Ação `Fazer tour` com ovo flat e submenu demonstrativo para `Tour desta tela`, `Tour do menu` e `Tour completo`.
- Previews e testes em light/dark, larguras suportadas, texto ampliado e reduced motion.

## Fora de escopo

- Upload, parsing, download real ou persistência de arquivos.
- Jobs reais, Supabase, migrations, RLS, auditoria ou notificações remotas.
- Implementação dos três tours guiados; cada opção apresentará somente feedback demonstrativo específico.
- Mudanças nos filtros, cards, tabela, paginação ou hierarquia visual do diretório.

## Composição visual

- O menu `Arquivos`, o submenu de tours e as atividades do sininho seguem o padrão OC: superfície neutra, raio e elevação existentes, hover/foco em `primaryContainer`, conteúdo em `primary` e overlay transparente.
- O modal de importação preserva o overlay preto translúcido, mas troca a superfície laranja por uma superfície neutra clara no light e semântica escura no dark.
- `Exportar modelo XLSX` aparece como ação secundária junto à etapa de seleção do arquivo.
- A cenoura usa corpo laranja inclinado, três folhas verdes e detalhes internos claros, inspirada na referência anexada e redesenhada com os tokens Coelo.
- O ovo usa base pastel com faixas e pequenos pontos da paleta semântica Coelo, legíveis mesmo no formato compacto.
- O fundo do controle de aparência usa o mesmo raio interno e alinhamento visual dos itens do menu lateral.
- O indicador de status da atividade é um único círculo centralizado dentro de uma área interativa invisível de pelo menos 48 px; não haverá um círculo decorativo externo.
- A lista de atividades usa divisores finos recuados, hover/foco laranja e scrollbar visível somente quando houver conteúdo rolável.

## Comportamento e acessibilidade

- Confirmar a importação fecha o modal; a tela permanece utilizável enquanto o progresso aparece no sininho.
- O painel mede até 400 px por 520 px e reduz para a viewport menos 32 px em telas compactas.
- Abrir o painel marca as atividades existentes como vistas; conclusões enquanto aberto já são lidas.
- Cada atividade mostra data e hora local em formato curto e mantém tipo, entidade, arquivo, progresso, status e resumo.
- Clicar em uma atividade de importação ou exportação mostra uma confirmação de download simulado; anúncios permanecem apenas informativos.
- Overlays fecham com `Esc`, devolvem foco ao acionador e oferecem alvos de pelo menos 48 px.
- Fechar o sininho por `Esc` ou pelo botão fechar devolve foco ao sininho. Clicar em OC, Bug ou outro controle preserva o foco no controle clicado e não deixa o sininho visualmente ativo.
- A troca de tema usa uma única transição coordenada de 220 ms com curva cúbica `(0.2, 0, 0, 1)`, interpolando superfícies, bordas, texto, ícones e marcador sem saltos ou animações concorrentes; reduced motion torna a mudança instantânea.
- O ovo executa um ciclo de aproximadamente 900 ms com balanço direita/esquerda progressivamente menor e brilho sincronizado, repousa aproximadamente 3,5 segundos e repete; reduced motion o mantém estático.
- Hover nunca é a única indicação de uma ação: menus e atividades continuam acionáveis por toque e teclado.

## Critérios de aceite

- O protótipo completo pode ser demonstrado com dados fictícios sem bloquear a página.
- O badge chega a 1 após a importação parcial e volta a zero ao abrir a central.
- Desktop e compacto mostram uma única ação adaptativa `Arquivos`, sem ocupar o cabeçalho da página.
- O menu `Arquivos`, o submenu de tours e a lista de atividades reproduzem os estados de hover/foco do menu OC.
- O modal usa superfície neutra e oferece a exportação simulada do modelo XLSX.
- Todas as atividades mostram data e hora e atividades de arquivo respondem ao clique com feedback de download simulado.
- A central apresenta scrollbar somente quando necessário e não rouba foco de OC, Bug ou outros controles.
- A troca light/dark permanece visualmente contínua durante os 220 ms e não apresenta frames com geometrias ou cores incompatíveis.
- Nenhuma largura de 375, 768, 1024 ou 1440 px produz overflow em light ou dark.
- O shell continua válido sem controlador de atividades.
- Flutter mínimo passa a ser 3.38 para permitir `@Preview`.

## Testes exigidos

- Widget tests do menu `Arquivos`, submenu de tours, ação `Exportar modelo XLSX` e feedbacks demonstrativos.
- Widget tests do modal light/dark e da manutenção do overlay preto translúcido.
- Widget tests de data/hora, hover, separadores, scrollbar, clique em atividade e indicador de status centralizado.
- Regressão de foco reproduzindo a sequência sininho → OC e sininho → Bug antes da correção.
- Testes com relógio controlado para timestamp e ciclo periódico do ovo, incluindo cancelamento dos timers.
- Testes de tema durante o frame intermediário da animação e com reduced motion.
- Verificação responsiva em 375, 768, 1024 e 1440 px, light/dark e texto ampliado.
