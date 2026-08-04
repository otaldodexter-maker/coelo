---
title: "Coelo Design System Oficial v1"
source: "Coelo Design System Oficial v1.docx; docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md"
source_file: "Coelo Design System Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo Design System Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/Design/Coelo Design System Oficial v1.docx"
supplemental_source: "docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md; docs/superpowers/specs/2026-07-27-popup-surface-standard-design.md; docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md; docs/superpowers/specs/2026-07-28-superadmin-institution-sticky-pagination-design.md"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-07-29"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| DESIGN SYSTEM OFICIAL<br>Marca · Produto · Light & Dark · Acessibilidade · Componentes<br>Versão 1.0 \| 21/06/2026 \| coelo.me |
| --- |

| Simples como Airbnb<br>Uso intuitivo e sem ruído. | Visual como Instagram<br>Conteúdo humano e fácil de consumir. | Confiável como escola<br>Privacidade, clareza e governança. |
| --- | --- | --- |

Documento operacional para Figma, Flutter/Dart, Admin, Superadmin, App e comunicação da marca.

# 1. Decisões oficiais do Design System

Este documento transforma a identidade do Coelo em regras práticas para telas, componentes, conteúdo e desenvolvimento. O sistema preserva o laranja vivo da marca, usa o grafite como base de confiança e mantém a interface leve, familiar e adulta — infantil no acolhimento, nunca infantilizada na operação.

| Decisão | Padrão oficial v1 | Por quê |
| --- | --- | --- |
| Marca primária | #D63C00 — Coelo Orange | É vivo, memorável e alcança 4,66:1 com branco em botões e blocos sólidos. |
| Secundária (Coelo Peach) | #FFE0D5 | Traz respiro visual para containers, chips e superfícies tonais sem saturar a interface. |
| Terciária (Coelo Forest) | #2D8A4E | Cor de apoio para features especiais, sucesso contextual e destaques do ecossistema. |
| Neutro de marca | #3F4549 — Coelo Graphite | Traz confiança e reduz o aspecto “carnaval” quando combinado ao laranja. |
| Tipografia | Nunito Sans em todo o ecossistema | Uma família só reduz complexidade e combina legibilidade com personalidade acolhedora. |
| Tema | Light como padrão + Dark completo | O app pode respeitar o sistema do dispositivo e oferecer escolha manual. |
| Arquitetura de cor | Tokens por função, não HEX direto | Permite trocar light/dark e aumentar contraste sem quebrar componentes. |
| Acessibilidade | WCAG 2.2 AA como mínimo | Texto normal ≥ 4,5:1; componentes/foco ≥ 3:1; alvos interativos de 48 × 48. |
| Estilo visual | Superfícies limpas, poucos contornos e sombras discretas | Mantém a simplicidade de apps familiares e dá protagonismo ao conteúdo. |

| Resumo de bolso<br>Use laranja para ação e identidade; grafite para texto e estrutura; branco e neutros para respirar. Nunca use cores semânticas como decoração. Nunca use uma cor isolada para comunicar um estado. |
| --- |

## Como usar este documento

- Design: crie Variables/Styles no Figma com os nomes de tokens indicados e aplique componentes, não cores soltas.

- Flutter: centralize os tokens em ColorScheme, TextTheme e ThemeExtension; nenhuma tela deve declarar HEX diretamente.

- Produto e conteúdo: use os padrões de voz, feedback e hierarquia para manter consistência entre App, Admin e Superadmin.

- QA: valide light, dark, texto ampliado, teclado, leitor de tela, alto contraste e estados de erro/carregamento.

## Base interna utilizada

O sistema segue a Product Vision (“simples, familiar e confiável”), a história da marca (cuidado, escuta, proteção e comunicação) e os módulos oficiais Flow, Now e Moments. Também incorpora o princípio “privado por padrão” dos PRDs de App e LGPD.

# 2. Princípios de experiência

| Princípio | Tradução visual | Decisão prática |
| --- | --- | --- |
| Simplicidade radical | Poucos elementos por tela, hierarquia evidente e ações previsíveis. | Uma ação primária por contexto; ações secundárias ficam discretas. |
| Visual antes de burocrático | Fotos, rotina, agenda e mensagens são fáceis de escanear. | Cards com título curto, metadados leves e conteúdo em primeiro plano. |
| Privado por padrão | A interface transmite proteção sem parecer ameaçadora. | Contexto ativo sempre visível; audiência e permissões antes de publicar. |
| Familiar, não infantilizado | Formas arredondadas e tom humano, com acabamento profissional. | Evitar excesso de mascotes, arco-íris, confetes e diminutivos. |
| Confiança acima de volume | Menos alertas e mais clareza sobre o que exige atenção. | Sem badges vermelhos em tudo; separar informação, pendência e urgência. |
| Inclusão desde o início | Contraste, tamanho, foco e linguagem fazem parte do componente. | Acessibilidade não é camada final nem opção de tema. |

## Personalidade visual em quatro eixos

| Eixo | Mais Coelo | Evitar |
| --- | --- | --- |
| Acolhedor | Calor moderado, cantos suaves, mensagens claras. | Baby talk, excesso de ilustração infantil ou emojis. |
| Confiável | Grafite, espaçamento, confirmação, contexto e histórico. | Telas cheias, textos vagos ou ações irreversíveis escondidas. |
| Visual | Mídia bem enquadrada, cards leves e boa hierarquia. | Gradientes aleatórios, sombras pesadas e ornamentos sem função. |
| Ágil | Fluxos curtos, padrões conhecidos e feedback imediato. | Animações longas, modais em cascata e formulários intermináveis. |

# 3. Logo e aplicação da marca

A marca principal combina o símbolo laranja com o nome em grafite. O símbolo representa cuidado, escuta, proteção e o elo entre família, criança e instituição. A aplicação deve preservar essa simplicidade: espaço, contraste e nenhuma “maquiagem” desnecessária.

| Versão | Quando usar | Fundo recomendado | Não fazer |
| --- | --- | --- | --- |
| Principal colorida | Site, apresentações, cabeçalhos e telas institucionais. | Branco ou neutro 50. | Não alterar as proporções nem aproximar o slogan do símbolo. |
| Símbolo laranja | Ícone interno, avatar oficial, favicon e assinatura compacta. | Branco, transparente ou neutro 50. | Não usar em fundo de baixo contraste ou sobre foto sem placa. |
| Negativa branca | Splash, blocos de marca e fundos escuros/laranja. | #D63C00, #3F4549 ou #111416. | Não adicionar contorno, brilho ou sombra. |
| Monocromática grafite | Documentos e impressos sem cor. | Branco. | Não converter para cinzas diferentes dentro do mesmo símbolo. |

## Área de proteção e tamanho mínimo

- Área livre: mantenha ao redor da marca ao menos 50% da altura do rosto do coelho.

- Símbolo isolado: mínimo de 24 px em interfaces; recomendado 32 px ou 40 px em navegação.

- Assinatura completa: mínimo de 120 px de largura sem slogan; 220 px com slogan.

- App icon: use o coelho branco em campo laranja; não use a assinatura completa dentro do ícone.

| Regra de ouro da logo<br>A logo não muda de cor para indicar sucesso, erro, alerta ou plano. Marca é marca; estado de sistema usa tokens semânticos. |
| --- |

# 4. Sistema de cores: fundamentos

O Coelo usa uma arquitetura de cores por papéis semânticos. A paleta física (tons) existe para construir os temas; designers e desenvolvedores devem aplicar tokens como color.action.primary ou color.text.secondary, não selecionar tons diretamente.

## 4.1 Paleta primária Coelo Orange

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | orange.50 | #FFF3EE | Fundos muito suaves e destaques leves. | #742100 | 9.85:1 |
| ■ | orange.100 | #FFE0D5 | Containers, chips e estados selecionados suaves. | #742100 | 8.61:1 |
| ■ | orange.200 | #FFC2AD | Bordas decorativas e ilustrações leves. | #581900 | 8.73:1 |
| ■ | orange.300 | #FF9B78 | Primary no Dark Mode e destaques sobre fundos escuros. | #351000 | 8.33:1 |
| ■ | orange.400 | #F36A3A | Acento gráfico; não usar com texto branco pequeno. | #111416 | 6.11:1 |
| ■ | orange.500 / brand | #D63C00 | Botão primário, logo, seleção e ação principal no Light. | #FFFFFF | 4.66:1 |
| ■ | orange.600 | #B83300 | Links e ícones sobre fundos claros; hover do primário. | #FFFFFF | 5.98:1 |
| ■ | orange.700 | #942900 | Pressed, texto de destaque e alto contraste. | #FFFFFF | 8.15:1 |
| ■ | orange.800 | #742100 | Container primário no Dark Mode. | #FFE0D5 | 8.61:1 |
| ■ | orange.900 | #581900 | Apoio de contraste e sobreposições. | #FFFFFF | 13.51:1 |
| ■ | orange.950 | #351000 | Texto sobre laranjas claros no Dark Mode. | #FF9B78 | 8.33:1 |

| Atenção de contraste<br>O #D63C00 alcança 4,66:1 com branco, passando AA para texto normal. Sobre o fundo #F7F8F8, porém, ele cai para aproximadamente 4,38:1. Por isso, links e textos laranja sobre fundos claros usam #B83300; #D63C00 fica preferencialmente em botões, ícones maiores e superfícies brancas. |
| --- |

## 4.2 Paleta neutra Coelo Graphite

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | neutral.0 | #FFFFFF | Superfície principal e conteúdo elevado. | #1C2022 | 16.42:1 |
| ■ | neutral.50 | #F8F9FA | Background de app/admin e áreas de respiro. | #1C2022 | 15.58:1 |
| ■ | neutral.100 | #EEF0F1 | Superfície sutil, skeleton e controles desabilitados. | #3F4549 | 8.51:1 |
| ■ | neutral.200 | #DDE0E2 | Divisores e bordas padrão. | #3F4549 | 7.34:1 |
| ■ | neutral.300 | #C4C9CC | Bordas fortes e ícones desabilitados. | #1C2022 | 9.83:1 |
| ■ | neutral.400 | #9DA4A8 | Texto auxiliar apenas no Dark Mode; ícones secundários. | #111416 | 7.32:1 |
| ■ | neutral.500 | #737B80 | Placeholder e metadados grandes; não usar em texto pequeno sobre branco. | #FFFFFF | 4.31:1 |
| ■ | neutral.600 | #596166 | Texto secundário e metadados no Light. | #FFFFFF | 6.31:1 |
| ■ | neutral.700 / brand | #3F4549 | Marca, ícones e títulos. | #FFFFFF | 9.73:1 |
| ■ | neutral.800 | #2B3033 | Superfície elevada no Dark. | #F5F7F8 | 12.42:1 |
| ■ | neutral.900 | #1C2022 | Texto primário no Light. | #FFFFFF | 16.42:1 |
| ■ | neutral.950 | #111416 | Background base no Dark. | #F5F7F8 | 17.21:1 |

## 4.3 Paleta de apoio Coelo Peach

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | peach.50 | #FFF8F5 | Fundo muito suave para estados discretos e ilustrações leves. | #742100 | 10.43:1 |
| ■ | peach.100 | #FFE0D5 | Containers, chips, seleções suaves e elementos de apoio. | #742100 | 8.61:1 |
| ■ | peach.200 | #FFC8B8 | Destaques tonais, cards leves e micro-sinais visuais. | #581900 | 7.46:1 |
| ■ | peach.300 | #FFB59B | Apoio visual no Dark Mode e superfícies quentes de segundo plano. | #351000 | 10.07:1 |

| Regra de uso da peach<br>Use #FFE0D5 para containers, chips e superfícies secundárias. Ela é a principal alternativa quando o laranja puro ficar saturado demais em blocos maiores. |
| --- |

## 4.4 Paleta de apoio Coelo Forest

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | forest.50 | #F0F9F3 | Fundo muito suave para sucesso contextual e estados positivos discretos. | #0D5C32 | 10.18:1 |
| ■ | forest.100 | #D7F0E0 | Containers suaves, badges positivos e apoio visual leve. | #0D5C32 | 7.64:1 |
| ■ | forest.300 | #5DBB78 | Destaques de sucesso e variação visual em superfícies claras. | #062A18 | 7.23:1 |
| ■ | forest.500 | #2D8A4E | Terciária principal, features especiais e sucesso relacionado ao ecossistema. | #FFFFFF | 4.86:1 |
| ■ | forest.700 | #1F6A3B | Hover, texto de destaque e apoio mais profundo no Light Mode. | #FFFFFF | 7.33:1 |
| ■ | forest.900 | #0D5C32 | Texto e destaque sobre fundos muito claros. | #FFFFFF | 8.99:1 |

| Regra de uso da forest<br>Use a terciária com parcimônia. Ela deve apoiar, orientar e diferenciar features, nunca competir com a marca primária laranja. |
| --- |

# 5. Temas Light e Dark

- Em Light Mode, `peach.100` sustenta containers e chips secundários, enquanto `forest.500` entra como acento de sucesso ou variação visual pontual.

- Em Dark Mode, a peach deve migrar para tons mais profundos ou quentes de apoio, e a forest deve continuar legível com fundos escuros sem virar cor de interface dominante.

- O objetivo é manter a primária laranja como assinatura, a peach como respiro e a forest como diferenciação controlada.

O tema Light é o padrão inicial. O tema Dark deve respeitar a preferência do sistema e também poder ser escolhido nas configurações. As duas versões usam os mesmos nomes semânticos; apenas os valores mudam.

## 5.1 Tokens de tema — Light

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | color.background | #F7F8F8 | Canvas geral do app e painel. | #1C2022 | 15.43:1 |
| ■ | color.surface | #FFFFFF | Cards, formulários e barras. | #1C2022 | 16.42:1 |
| ■ | color.surface.subtle | #F1F3F4 | Blocos agrupados, skeleton e hover neutro. | #1C2022 | 14.75:1 |
| ■ | color.surface.raised | #FFFFFF | Modal, menu e card elevado. | #1C2022 | 16.42:1 |
| ■ | color.text.primary | #1C2022 | Títulos e texto principal. | #FFFFFF | 16.42:1 |
| ■ | color.text.secondary | #596166 | Metadados e descrição. | #FFFFFF | 6.31:1 |
| ■ | color.text.tertiary | #737B80 | Placeholder, timestamps e texto de baixa ênfase. | #FFFFFF | 4.31:1 em branco — usar ≥ 16 px ou peso 600; para 12–14 px prefira #596166. |
| ■ | color.border.subtle | #DDE0E2 | Divisores e bordas de cards. | #1C2022 | 12.38:1 |
| ■ | color.border.strong | #C4C9CC | Input, tabela e separação forte. | #1C2022 | 9.83:1 |
| ■ | color.action.primary | #D63C00 | Botão e seleção principal. | #FFFFFF | 4.66:1 |
| ■ | color.action.link | #B83300 | Links e texto de ação em fundo claro. | #FFFFFF | 5.98:1 |
| ■ | color.action.primaryContainer | #FFF3EE | Seleção suave, chips e estado ativo discreto. | #742100 | 9.85:1 |

## 5.2 Tokens de tema — Dark

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | color.background | #111416 | Canvas geral do app. | #F5F7F8 | 17.21:1 |
| ■ | color.surface | #181C1F | Cards e barras. | #F5F7F8 | 15.96:1 |
| ■ | color.surface.subtle | #202529 | Blocos agrupados e campos. | #F5F7F8 | 14.39:1 |
| ■ | color.surface.raised | #2B3033 | Modal, menu, sheet e card elevado. | #F5F7F8 | 12.42:1 |
| ■ | color.text.primary | #F5F7F8 | Títulos e texto principal. | #111416 | 17.21:1 |
| ■ | color.text.secondary | #C4C9CC | Descrição e metadados. | #111416 | 11.07:1 |
| ■ | color.text.tertiary | #9DA4A8 | Placeholder e baixa ênfase. | #111416 | 7.32:1 |
| ■ | color.border.subtle | #3F4549 | Divisores e bordas. | #F5F7F8 | 9.05:1 |
| ■ | color.border.strong | #596166 | Bordas de input e foco neutro. | #FFFFFF | 6.31:1 |
| ■ | color.action.primary | #FF9B78 | Botão e seleção principal no Dark. | #351000 | 8.33:1 |
| ■ | color.action.link | #FFB59B | Links e ações textuais. | #351000 | 10.07:1 |
| ■ | color.action.primaryContainer | #742100 | Seleção suave e chips ativos. | #FFE0D5 | 8.61:1 |

| Não use preto puro<br>O Dark Mode usa #111416, não #000000. Isso reduz contraste agressivo, preserva profundidade entre superfícies e combina com o grafite da marca. Em telas OLED, o ganho visual de preto absoluto não compensa a perda de hierarquia. |
| --- |

# 6. Cores semânticas e estados

Cores semânticas existem para comunicar significado. O mesmo verde deve representar sucesso em todos os produtos; o mesmo vermelho deve representar erro ou risco. Elas nunca substituem texto, ícone ou rótulo.

## 6.1 Status no Light Mode

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | success.base | #18864B | Conclusão, confirmação e estado saudável. | #FFFFFF | 4.61:1 |
| ■ | success.container | #E9F7EF | Banner e feedback positivo suave. | #0D5C32 | 7.33:1 |
| ■ | error.base | #B42318 | Erro, falha e ação destrutiva. | #FFFFFF | 6.57:1 |
| ■ | error.container | #FDECEA | Mensagem de erro e validação. | #7A1A12 | 9.26:1 |
| ■ | warning.base | #8A4F00 | Atenção, prazo e risco não crítico. | #FFFFFF | 6.56:1 |
| ■ | warning.container | #FFF3D6 | Banner de alerta e pendência. | #6A3A00 | 8.59:1 |
| ■ | info.base | #0B6E99 | Informação, ajuda e atualização. | #FFFFFF | 5.67:1 |
| ■ | info.container | #E6F4FA | Banner informativo e dica. | #064B69 | 8.42:1 |

## 6.2 Status no Dark Mode

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | success.base.dark | #62D394 | Sucesso e confirmação no Dark. | #062A18 | 8.33:1 |
| ■ | success.container.dark | #0B5A31 | Feedback positivo suave. | #B9F6D2 | 6.81:1 |
| ■ | error.base.dark | #FFB4AB | Erro e ação destrutiva no Dark. | #690005 | 7.72:1 |
| ■ | error.container.dark | #93000A | Feedback de erro suave. | #FFDAD6 | 7.24:1 |
| ■ | warning.base.dark | #FFB95C | Atenção e prazo no Dark. | #3E2700 | 8.26:1 |
| ■ | warning.container.dark | #6E4300 | Feedback de alerta suave. | #FFDEA5 | 6.59:1 |
| ■ | info.base.dark | #7DD0F2 | Informação e ajuda no Dark. | #003546 | 7.62:1 |
| ■ | info.container.dark | #00506C | Feedback informativo suave. | #BEE9FA | 6.86:1 |

## 6.3 Regras de uso

| Situação | Cor | Ícone/rótulo obrigatório | Exemplo |
| --- | --- | --- | --- |
| Operação concluída | Success | Check + mensagem concreta. | “Rotina publicada para 18 crianças.” |
| Campo inválido | Error | Ícone opcional + texto abaixo do campo. | “Informe um celular válido.” |
| Ação irreversível | Error | Verbo explícito + confirmação contextual. | “Excluir comunicado” — não apenas “Continuar”. |
| Prazo se aproximando | Warning | Relógio/alerta + data ou consequência. | “Autorização vence amanhã.” |
| Informação neutra | Info | Ícone de informação + conteúdo objetivo. | “A confirmação de leitura ficará registrada.” |
| Estado inativo | Neutral | Texto e forma; não simular erro. | “Conta suspensa” com chip neutro e motivo. |

# 7. Tipografia

A família oficial é Nunito Sans. Ela deve aparecer na logo, interfaces, site, materiais e documentos sempre que possível. Não é necessária uma segunda fonte: a variação de tamanho, peso e espaçamento já cria hierarquia suficiente.

| Stack recomendada<br>Nunito Sans, -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif. Em Flutter, empacotar a família ou usar o pacote oficial; nunca depender apenas da fonte instalada no dispositivo. |
| --- |

## 7.1 Pesos oficiais

| Peso | Uso | Evitar |
| --- | --- | --- |
| 400 Regular | Texto corrido, descrições e mensagens. | Textos muito pequenos com contraste baixo. |
| 500 Medium | Metadados importantes e controles discretos. | Usar como único recurso de hierarquia. |
| 600 SemiBold | Subtítulos, labels, navegação e destaques. | Aplicar em parágrafos longos. |
| 700 Bold | Botões, títulos e números-chave. | Todo o conteúdo em negrito. |
| 800 ExtraBold | Marketing, display e título de campanha. | Formulários e textos operacionais. |
| 300 / 900 | Não recomendados na UI v1. | Baixa leitura ou peso visual excessivo. |

## 7.2 Escala tipográfica responsiva

| Token | Desktop px | Peso | Uso | Mobile px |
| --- | --- | --- | --- | --- |
| Display L | 48 / 56 | 800 | Marketing e hero desktop | 40 / 48 |
| Display M | 40 / 48 | 800 | Landing e campanhas | 36 / 44 |
| Heading 1 | 32 / 40 | 800 | Título principal de página | 28 / 36 |
| Heading 2 | 28 / 36 | 700 | Seção principal | 24 / 32 |
| Heading 3 | 24 / 32 | 700 | Subseção e card destaque | 22 / 28 |
| Title L | 22 / 28 | 700 | Cabeçalho de tela/modal | 20 / 28 |
| Title M | 18 / 24 | 700 | Card, lista e formulário | 18 / 24 |
| Body L | 16 / 24 | 400 / 600 | Texto principal e mensagens | 16 / 24 |
| Body M | 14 / 20 | 400 / 600 | Descrição, tabela e metadado | 14 / 20 |
| Body S | 12 / 16 | 400 / 600 | Legenda e informação compacta | 12 / 16 |
| Label L | 14 / 20 | 700 | Botão, tab e campo | 14 / 20 |
| Label M | 12 / 16 | 700 | Chip, badge e tabela compacta | 12 / 16 |

## 7.3 Regras de legibilidade

- Texto principal do app: 16 px / 24 px. Não reduzir para “caber mais”.

- Textos operacionais mínimos: 12 px; preferir 14 px em campos, tabelas e mensagens.

- Comprimento de linha: 45–75 caracteres em leitura; feeds e formulários com largura controlada.

- Alinhamento à esquerda para textos longos. Centralizar apenas frases curtas, estados vazios e capas.

- Não usar CAIXA ALTA em frases. Reservar para micro-rótulos curtos, com espaçamento de letras moderado.

- Peso 700 em botões e labels; peso 400 no texto. Cor e peso não devem competir ao mesmo tempo.

# 8. Espaçamento, grid e layout adaptativo

O sistema usa unidade base de 4 px/dp e ritmo preferencial de 8. A escala evita valores aleatórios e facilita implementação em Flutter, web e Figma.

## 8.1 Escala de espaçamento

| Token | Valor | Uso típico |
| --- | --- | --- |
| space.0 | 0 | Sem espaço. |
| space.0.5 | 2 | Ajustes ópticos raros. |
| space.1 | 4 | Ícone + badge, microgap. |
| space.2 | 8 | Elementos relacionados. |
| space.3 | 12 | Conteúdo interno compacto. |
| space.4 | 16 | Padding padrão mobile e cards. |
| space.5 | 20 | Campos e blocos médios. |
| space.6 | 24 | Seções e tablet. |
| space.8 | 32 | Separação forte e desktop. |
| space.10 | 40 | Blocos de marketing. |
| space.12 | 48 | Seção ampla e alvo grande. |
| space.16 | 64 | Hero e grandes respiros. |
| space.20 | 80 | Landing page. |
| space.24 | 96 | Separação máxima. |

## 8.2 Breakpoints e colunas

| Classe | Largura | Colunas | Margem/gutter | Uso Coelo |
| --- | --- | --- | --- | --- |
| Compact | 0–599 | 4 | 16 / 16 | App mobile; navegação inferior; cards quase full-width. |
| Medium | 600–839 | 8 | 24 / 20 | Tablet; navegação lateral compacta; 1–2 painéis. |
| Expanded | 840–1199 | 12 | 32 / 24 | Admin pequeno e web app; rail/sidebar. |
| Large | 1200–1599 | 12 | 40 / 24 | Admin padrão; conteúdo até 1440 px. |
| Extra large | 1600+ | 12 | 48 / 32 | Admin amplo; 2–3 painéis sem esticar leitura. |

## 8.3 Larguras funcionais

| Contexto | Largura recomendada | Regra |
| --- | --- | --- |
| Flow / conteúdo social | 560–680 px | Não esticar posts no desktop; usar coluna lateral para contexto. |
| Formulário simples | 480–640 px | Uma coluna; labels acima dos campos. |
| Modal | 360–560 px | Tarefa curta; para fluxos longos usar página ou sheet. |
| Tabela administrativa | 960–1440 px | Permitir scroll horizontal apenas quando indispensável. |
| Texto institucional | 640–760 px | Facilita leitura e mantém aparência editorial. |

# 9. Forma, bordas e elevação

A geometria acompanha o coelho da marca: acolhedora e arredondada, mas sem transformar cada objeto em uma cápsula. A hierarquia vem primeiro do espaço e da superfície; sombras são o último recurso.

## 9.1 Escala de cantos

| Token | Raio | Aplicações |
| --- | --- | --- |
| radius.xs | 4 | Checkbox, progress e pequenos elementos. |
| radius.sm | 8 | Tooltip, badge, menu item e miniatura. |
| radius.md | 12 | Inputs, botões, chips e cards compactos. |
| radius.lg | 16 | Cards principais, posts e containers. |
| radius.xl | 24 | Modais, sheets e blocos de marketing. |
| radius.full | 999 | Avatar, pill e FAB circular. |

## 9.2 Bordas

| Token | Light | Dark | Uso |
| --- | --- | --- | --- |
| border.subtle | 1 px #DDE0E2 | 1 px #3F4549 | Cards, divisores e tabelas. |
| border.strong | 1 px #C4C9CC | 1 px #596166 | Inputs, dropdown e elementos selecionáveis. |
| border.focus | 3 px #D63C00 | 3 px #FF9B78 | Foco de teclado, com offset de 2 px. |
| border.error | 1–2 px #B42318 | 1–2 px #FFB4AB | Campos inválidos e áreas críticas. |

## 9.3 Elevação

| Nível | Light | Dark | Uso |
| --- | --- | --- | --- |
| 0 | Sem sombra | Mesmo tom da superfície | Conteúdo comum e cards de feed. |
| 1 | 0 1 2 rgba(17,20,22,.08) | Surface +1 tom | Barra, card interativo e dropdown simples. |
| 2 | 0 4 12 rgba(17,20,22,.12) | Surface +2 tons | Menu, tooltip e popover. |
| 3 | 0 12 32 rgba(17,20,22,.18) | Surface +3 tons | Modal e sheet. |

| Estilo Airbnb/Instagram sem copiar<br>Use superfícies claras, tipografia firme, mídia em destaque e ações familiares. Evite reproduzir gradientes, ícones ou layouts proprietários. A inspiração é a simplicidade de uso, não a aparência literal. |
| --- |

| Sem gradientes<br>Gradientes não são usados nas superfícies visuais do Coelo. Estados, hierarquia e marca devem usar tokens semânticos, cor sólida, borda, forma, texto e elevação. |
| --- |

# 10. Ícones, avatares, fotos e ilustrações

## 10.1 Iconografia

Biblioteca recomendada: Material Symbols Rounded, estilo outlined, peso visual consistente. A forma arredondada conversa com a marca e possui ampla cobertura para Flutter e web.

| Propriedade | Padrão |
| --- | --- |
| Tamanho | 20 px compacto; 24 px padrão; 28–32 px destaque. |
| Stroke/weight | Regular; não misturar outlined, sharp e filled na mesma navegação. |
| Filled | Somente estado selecionado ou ação muito importante. |
| Cor | Text secondary por padrão; primary para ativo; semantic para status real. |
| Área de toque | Mínimo 48 × 48, mesmo quando o ícone visual tiver 20–24 px. |
| Rótulo | Ícone sem texto apenas quando o significado for universal e houver tooltip/semântica. |

## 10.2 Avatares

| Tipo | Formato | Fallback |
| --- | --- | --- |
| Pessoa adulta | Círculo 32 / 40 / 48 / 64 | Iniciais em container neutro; nunca expor contato. |
| Criança | Círculo com controle de privacidade | Iniciais ou ícone protegido; respeitar autorização de imagem. |
| Instituição/unidade/grupo | Quadrado arredondado 12–16 | Símbolo ou iniciais da instituição. |
| Coelo oficial | Símbolo da marca | Coelho laranja ou negativo oficial. |

Na caixa `Conversas`, instituição, unidade, turma e atividade podem usar avatar
circular. Essa variante é contextual e não substitui o formato institucional
padrão em outras superfícies.

## 10.3 Fotografia e mídia

- Preferir imagens reais, espontâneas, bem iluminadas e com contexto de cuidado; evitar poses publicitárias artificiais.

- Proporções: 1:1 para avatar/post; 4:3 para rotina; 16:9 para cards; 9:16 para Now e Moments.

- Recorte deve preservar rostos e atividade. Nunca inserir texto importante dentro de imagem sem alternativa acessível.

- Fotos infantis são privadas por padrão; publicação, audiência e download seguem autorização e políticas da instituição.

- Overlays em mídia usam scrim preto de 24–56% conforme legibilidade; nunca aplicar laranja translúcido sobre pele.

# 11. Botões e ações

Cada tela deve ter uma ação primária clara. O uso excessivo de botões preenchidos transforma tudo em prioridade e enfraquece a orientação.

| Variante | Light | Dark | Quando usar |
| --- | --- | --- | --- |
| Primary | Fundo #D63C00 · texto branco | Fundo #FF9B78 · texto #351000 | Ação principal: publicar, salvar, confirmar. |
| Secondary / tonal | Fundo #FFF3EE · texto #742100 | Fundo #742100 · texto #FFE0D5 | Ação importante, mas não dominante. |
| Outlined | Transparente · borda #C4C9CC · texto #3F4549 | Transparente · borda #596166 · texto #F5F7F8 | Cancelar, filtrar, alternar. |
| Text | Sem fundo · texto #B83300 | Sem fundo · texto #FFB59B | Ação contextual de baixa ênfase. |
| Danger | Fundo #B42318 · texto branco | Fundo #FFB4AB · texto #690005 | Excluir, revogar ou encerrar. |

### Hierarquia operacional

- Primary é o botão laranja preenchido e representa o único compromisso
  dominante do contexto: criar, salvar, continuar, aplicar ou confirmar.
- Outlined é a ação secundária. O fundo percebido é `colorScheme.surface`
  — nunca branco literal — com contorno leve; usar para anterior, voltar,
  cancelar relevante, filtrar ou alternar.
- Text é a ação terciária: `surface` sem contorno, para cancelar discreto,
  limpar, editar, ver mais ou apoio contextual.
- Não escolher Filled, Outlined ou Text pela quantidade de espaço disponível.
  A variante expressa prioridade. Ação negativa habilitada sempre usa a
  hierarquia `error`/`errorContainer`.
- Em rodapé de tela medium ou maior, terciária/cancelar ocupa o extremo
  esquerdo; secundárias e a única primária formam o grupo no extremo direito.
  Em compact, a primária ocupa 100% e precede as demais.

## Especificação

| Item | Padrão |
| --- | --- |
| Altura | 48 px padrão; 40 px compacto apenas em tabelas desktop; 56 px em CTA principal. |
| Padding | 16–24 px horizontal; gap de 8 px entre ícone e label. |
| Raio | 12 px padrão; full apenas para chips e FAB. |
| Tipografia | Label L: 14/20, peso 700. |
| Ícone | 20 px; posição inicial para ação, final para progressão quando fizer sentido. |
| Loading | Manter largura; substituir ícone por spinner e label por verbo no gerúndio: “Salvando…”. |
| Disabled | Não depender apenas de opacidade; remover ação do foco e explicar bloqueio quando necessário. |
| Foco | Outline 3 px com offset 2 px, visível em teclado. |

## Estados do Primary — Light

| Estado | Fundo | Texto | Observação |
| --- | --- | --- | --- |
| Default | #D63C00 | #FFFFFF | Contraste 4,66:1. |
| Hover | #B83300 | #FFFFFF | Desktop/web. |
| Pressed | #942900 | #FFFFFF | Resposta imediata e curta. |
| Focus | #D63C00 | #FFFFFF | Ring #D63C00 ou #FF9B78 fora do componente. |
| Disabled | #EEF0F1 | #737B80 | Sem sombra; cursor/semântica desabilitados. |

### Preservação da marca nos estados interativos

- Ações primárias não recebem overlay branco ou cinza. Hover, foco e pressed
  permanecem na paleta primária aprovada, com overlay adicional transparente.
- Ações tonais, chips acionáveis e sugestões preservam
  `colorScheme.primaryContainer` e `colorScheme.onPrimaryContainer` no hover e
  foco, sem camada neutra adicional.
- Disabled permanece neutro por padrão. Uma ação primária antecipada que
  continua visível, como enviar antes de existir conteúdo, pode usar
  `primaryContainer` e `onPrimaryContainer` somente com `onPressed: null`, sem
  hover e com semântica de indisponibilidade.
- Botões de ícone mantêm alvo mínimo `CoeloSize.touchMin`. Glifos assimétricos
  usam uma caixa quadrada `CoeloSize.iconMd` centralizada; não aplicar
  deslocamento manual sem decisão visual aprovada.

# 12. Formulários e entradas

Formulários devem parecer simples mesmo quando o domínio é complexo. O usuário vê uma decisão por vez; campos relacionados podem ser agrupados, mas não escondidos em lógica imprevisível.

| Elemento | Especificação |
| --- | --- |
| Text field | Altura 52 px; radius 12; borda strong; label acima; placeholder não substitui label. |
| Textarea | Altura mínima 112 px; contador somente quando houver limite real. |
| Select | Mesmo visual do text field; menu com opção atual marcada e busca quando > 8 itens. |
| Checkbox | 20–24 px visual dentro de alvo 48 px; label clicável. |
| Radio | Usar para 2–6 opções mutuamente exclusivas visíveis. |
| Switch | Somente ação imediata on/off; não usar para “escolher uma opção” em formulário. |
| Date/time | Usar formato local pt-BR; exibir timezone quando relevante. |
| Upload | Mostrar tipo, tamanho, progresso, erro e política de privacidade. |

## Padrão de formulário de cadastro e edição

- Criar/Editar Instituição é a baseline automática e a verdade visual para
  qualquer tela do Superadmin que crie ou edite uma entidade, incluindo
  refatoração, correção e novos widgets/seções. O domínio pode mudar conteúdo,
  etapas e validações; não muda sozinho a identidade visual.
- Antes de implementar, consultar o código real de `InstitutionFormPage`,
  `InstitutionFormNavigation`, `SuperadminFormActionFooter`, testes funcionais
  e os goldens aprovados mobile light e desktop dark. Reutilizar os componentes
  compartilhados e preservar a anatomia dos widgets específicos de domínio.
- Se uma necessidade real não couber nessa baseline, parar antes do código,
  apresentar comparação e proposta de nova identidade visual ao Owner e
  aguardar aprovação explícita. Sem aprovação, não criar variante, componente,
  golden ou exceção de allowlist divergente.
- Usar `CoeloFormTextField` para entrada textual em autenticação, cadastro e
  edição. O componente preserva label flutuante, ícone inicial, hint
  contextual, hover, foco, erro e disabled sem estilos locais concorrentes.
- Em largura compacta, usar uma coluna. A partir de `breakpoint.medium`, usar
  até duas colunas, com `spacing.3` (12 px) horizontal e `spacing.4` (16 px)
  vertical. Grupos e cabeçalhos usam `spacing.5` (20 px). Esses valores
  pertencem à escala oficial e reproduzem a densidade dos campos de login sem
  colar bordas ou controles.
- Rodapé de fluxo usa `spacing.3` interno, `radius.lg`, borda
  `outlineVariant` e `surface`. Em compact, a ação primária ocupa a
  largura e precede cancelar/anterior; em medium ou maior, cancelar fica à
  esquerda e navegação/continuidade à direita.
- Diálogo administrativo usa `CoeloAdminDialogShell`, derivado do popup de bug,
  com cabeçalho dividido, fechar acessível, corpo rolável e rodapé persistente.
  Uma ação ocupa toda a largura útil; duas ações dividem a largura igualmente,
  com `spacing.3` entre elas.
- Single-select administrativo usa `CoeloAdminSingleSelectField`: opções
  contínuas de pelo menos 48 px, superfície neutra, e
  `primaryContainer`/`primary` para seleção, hover e foco. Não usar o menu
  cinza nativo como composição final. O painel acompanha exatamente a largura
  do campo, abre `spacing.1` abaixo, mostra no máximo seis opções e reduz a
  altura para caber abaixo do gatilho. Busca permanece fixa e somente a lista
  rola; não usar check ou checkbox.
- Popup, dialog, menu e overlay usam `color.surface` sem tint. Laranja aparece
  em ação, foco, seleção ou aviso contextual, nunca como fundo-base da
  superfície. O popup de bug, o submenu do sino e a importação de arquivo são
  referências canônicas.
- Formulários não usam faixas `surfaceContainer` ou cinza apenas para preencher
  espaço. Agrupamento vem de espaçamento, borda e hierarquia; aviso informativo
  pode usar `primaryContainer` quando seu significado justificar o destaque.
- Foto de perfil institucional aceita PNG, JPG ou WebP quadrado de até 2 MB.
  O quadrado evita recorte ambíguo no avatar circular; 2 MB preserva qualidade
  para exibição em alta densidade sem transferência excessiva. Rejeitar antes
  do upload e explicar formato, proporção e limite junto ao controle.
- Cor institucional aceita hexadecimal `#RRGGBB` e seleção visual por área
  bidimensional de saturação/valor com controle de matiz, amostras atual e
  nova e edição HSV e RGB. A amostra nunca substitui o valor textual, para
  manter precisão e acessibilidade.
- A identidade institucional apresenta primeiro sua prévia compacta e separa
  cores de superfície, marca e texto. Em desktop, marca e texto ocupam três
  colunas; em larguras menores, a grade colapsa sem perda de ordem, rótulo ou
  foco.
- Bio limitada conta grafemas. Um botão de ícone com tooltip e semântica abre a
  seleção compacta de emojis; a escolha entra no cursor e não substitui o
  teclado nativo.
- O avatar opcional do administrador pertence ao cadastro e à edição do
  administrador. Usa o recorte circular padrão de perfil; a confirmação do
  recorte apresenta `Cancelar` e `Aplicar` em ações 50/50, e o reset é uma ação
  circular por ícone com tooltip, semântica e alvo mínimo.
- Sincronizações entre representante e administrador devem nomear a direção:
  `Copiar dados do representante` para representante → administrador e
  `Copiar dados para o representante` para administrador → representante.
- Ícones de campo representam o significado específico, evitando repetir um
  símbolo genérico em todo o grupo. Ação contextual que opera sobre o valor,
  como `Buscar CEP`, fica no próprio campo com tooltip, semântica e alvo mínimo.
- Instituições no Superadmin é a referência canônica de cadastro e edição;
  autenticação é a referência do campo-base. Validar 375, 768, 1024 e 1440 px,
  light/dark e texto a 200%, com golden mínimo em mobile light e desktop dark.

## Anatomia do campo

| Parte | Token / regra |
| --- | --- |
| Label | 14/20 SemiBold; text.primary. |
| Campo | Surface; border.strong; 12 px radius; padding 14–16 px. |
| Valor | 16/24 Regular; text.primary. |
| Placeholder | text.secondary; não usar text.tertiary pequeno. |
| Helper | 12/16; text.secondary; instrução antes do erro. |
| Erro | 12/16 SemiBold; error.base; mensagem específica. |
| Foco | Border primary + ring 3 px; não remover outline do navegador sem substituto. |

| Mensagens de validação<br>Explique o que aconteceu e como corrigir. Bom: “A senha precisa ter pelo menos 8 caracteres.” Ruim: “Campo inválido”, “Erro 422” ou apenas uma borda vermelha. |
| --- |

# 13. Navegação e estrutura

| Componente | Compact | Expanded |
| --- | --- | --- |
| Top app bar | 56–64 px; título e ações essenciais. | 64–72 px; breadcrumb/contexto quando necessário. |
| Bottom navigation | 4–5 destinos; ícone + label; 64–80 px. | Substituir por rail/sidebar. |
| Navigation rail | Opcional em tablet. | 72–88 px, com label e indicador ativo. |
| Sidebar Admin | Drawer temporário. | 240–280 px; grupos claros e recolhimento opcional. |
| Tabs | Scroll horizontal quando necessário. | Até 5 tabs visíveis; underline/indicator primary. |
| Breadcrumb | Evitar no app mobile. | Admin e fluxos hierárquicos profundos. |

## Tabs lineares de diretório

- Use para três ou mais categorias irmãs que filtram o mesmo diretório sem
  trocar toolbar, cards/tabela ou contexto de página. `Acessos > Pessoas` é a
  baseline aprovada.
- A faixa permanece sobre `surface`, sem cápsula: linha-base de 1 px em
  `outlineVariant`; tab selecionada com label `primary` em peso 700 e underline
  `primary` de 2 px; inativas usam `onSurfaceVariant` em peso 400.
- Cada tab preserva alvo mínimo de 48 px e padding horizontal `space4`. Use
  `space4` entre toolbar e tabs e novamente entre tabs e conteúdo.
- Hover/foco usam realce `primaryContainer` sutil, sem cinza; seleção continua
  evidente por texto e underline. Em compact, usar rolagem horizontal.
- Não confundir com o toggle segmentado Cards/Tabela, com filtros/chips ou com
  navegação entre páginas independentes.

## Navegação principal do App

| Destino | Conteúdo | Ícone sugerido |
| --- | --- | --- |
| Flow | Posts, comunicados, Now e entrada para Moments. | home / dynamic_feed |
| Rotina | Diário e histórico por criança. | event_note / checklist |
| Chat | Conversas e canais autorizados. | chat_bubble_outline |
| Agenda | Eventos, respostas e autorizações. | calendar_month |
| Perfil / contexto | Conta, crianças, instituições e papel ativo. | account_circle |

## Contexto ativo

- Exibir instituição e papel atual de forma persistente ou acessível em um toque.

- Ao trocar o contexto, atualizar dados, navegação e permissões imediatamente; nunca misturar “pai” e “professor”.

- Usar avatar/identidade da instituição e texto claro; não depender apenas de cor para indicar o contexto.

# 14. Componentes do produto: Flow, Now e Moments

## 14.1 Flow

| Parte | Regra visual |
| --- | --- |
| Post | Surface; radius 16; sem sombra no mobile; borda sutil no desktop. |
| Cabeçalho | Avatar 40; perfil, contexto e tempo; menu de 48 × 48. |
| Texto | Body L; limitar preview e oferecer “ver mais” sem cortar informação crítica. |
| Mídia | 1:1, 4:3 ou carrossel; indicador de páginas discreto. |
| Comunicado | Ícone e label; confirmação de leitura em container separado. |
| Reações | Chips leves; não transformar em competição ou ranking. |
| Audiência | Sempre visível para autor/admin; linguagem simples: “Turma Girassol”. |

## 14.2 Now

| Elemento | Padrão |
| --- | --- |
| Ring não visto | Duas linhas discretas: #D63C00 + #FF9B78; sem arco-íris. |
| Ring visto | Neutral 300 no Light; neutral 600 no Dark. |
| Avatar | 56–64 px; label de 12 px em até 2 linhas. |
| Viewer | Fundo #111416; progress branco; controles com alvo 48 px. |
| Texto sobre mídia | Branco com scrim; sombra de texto apenas como apoio. |
| Expiração | Comunicar 24 h quando relevante; não usar contagem ansiosa. |

## 14.3 Moments

| Elemento | Padrão |
| --- | --- |
| Tela | Imersiva e escura; vídeo em primeiro plano. |
| Controles | Branco / neutral 200; ícones de 24 px em alvos de 48 px. |
| Legenda | Body M; máximo de linhas antes de expandir. |
| Interação | Reações simples; comentários desativados no MVP. |
| Privacidade | Audiência e perfil claros; download bloqueado por padrão. |
| Movimento | Autoplay sem som; respeitar reduced motion e controles do sistema. |

# 15. Chat, rotina e agenda

## 15.1 Chat

| Elemento | Light | Dark |
| --- | --- | --- |
| Bubble recebida | #F1F3F4 + texto #1C2022 | #202529 + texto #F5F7F8 |
| Bubble enviada | #FFF3EE + texto #3F4549 | #742100 + texto #FFE0D5 |
| Timestamp | #596166 | #C4C9CC |
| Status de envio | Ícone + texto acessível | Ícone + texto acessível |
| Composer | Surface, border strong, radius 16 | Surface subtle, border strong, radius 16 |

- Não usar laranja sólido em todas as mensagens enviadas; isso cria grandes áreas saturadas e reduz conforto.

- Separar claramente mensagens institucionais, internas e relacionadas a uma criança.

- Anexos mostram tipo, tamanho, origem e disponibilidade; falha de upload deve ser recuperável.

### Caixa De Conversas E Estado Do Avatar

- `Conversas` é uma única caixa de entrada visual; `Todas` é a visão padrão.
- `Instituições e unidades`, `Turmas` e `Atividades` são filtros opcionais.
- O filtro de criança pertence a um nível separado do filtro de tipo.
- Cada item representa uma conversa independente e contextual; filtros não
  sugerem canal ou autorização compartilhada.
- O ponto de presença sobre o avatar representa disponibilidade do serviço ou
  da equipe em contextos coletivos, não a presença de todas as pessoas.
- Presença nunca pode ser comunicada apenas por cor: exige texto acessível,
  rótulo/ícone quando visível e nome, papel e estado na semântica.
- O anel ao redor do avatar representa estado de publicação do Now. Ele não é
  indicador de presença e deve ter alternativa semântica.
- Nenhum avatar, anel de Now, ponto de presença ou superfície da caixa usa
  gradiente.

## 15.2 Diário de rotina

| Componente | Regra |
| --- | --- |
| Resumo do dia | Card por criança, com status e pendências. |
| Categorias | Ícone + texto; cor apenas como apoio, preferindo containers neutros. |
| Registro em lote | Seleção clara, contador de crianças e etapa de revisão. |
| Ajuste individual | Destaque da criança e aviso de diferença em relação ao lote. |
| Publicado | Success + timestamp + autor; edição posterior auditável. |
| Saúde/ocorrência | Área sensível, acesso restrito e texto sem estigmatização. |

## 15.3 Agenda

| Estado | Tratamento |
| --- | --- |
| Hoje | Primary container + marcador textual “Hoje”. |
| Confirmado | Success icon + “Confirmado”. |
| Pendente | Warning icon + prazo explícito. |
| Recusado | Neutral ou error conforme consequência; texto “Não participará”. |
| Cancelado | Texto riscado apenas como apoio; chip “Cancelado” obrigatório. |
| Evento crítico | Banner de informação; não usar vermelho se não houver erro/risco. |

# 16. Feedback, notificações e estados vazios

| Componente | Uso | Duração/ação |
| --- | --- | --- |
| Toast / snackbar | Confirmação curta após ação reversível. | 4–6 s; ação “Desfazer” quando aplicável. |
| Banner | Informação persistente na tela. | Até ser resolvido ou dispensado. |
| Inline message | Erro, ajuda ou status junto do componente. | Persistente enquanto relevante. |
| Dialog | Decisão crítica ou confirmação. | Exige ação explícita; evitar cascata. |
| Bottom sheet | Ações contextuais no mobile. | Fechável; foco e leitura controlados. |
| Progress | Operação mensurável. | Barra com porcentagem/etapa. |
| Skeleton | Carregamento previsível. | Sem shimmer agressivo; respeitar motion. |

## Notificações

- Badges indicam quantidade útil, não ansiedade. Exibir “9+” em vez de números intermináveis.

- Urgente é exceção. Vermelho só quando houver risco real, falha ou ação crítica.

- Push deve usar payload mínimo; conteúdo sensível só aparece após autenticação.

- Agrupar notificações por instituição e criança quando isso reduzir ruído.

## Estados vazios

| Parte | Regra |
| --- | --- |
| Título | Explicar o estado: “Ainda não há eventos”. |
| Descrição | Dizer o que acontece depois ou como começar. |
| Ação | Uma CTA direta quando o usuário puder resolver. |
| Ilustração | Opcional, simples e pequena; nunca maior que a mensagem. |
| Tom | Calmo e útil; não culpar o usuário. |

## Páginas fullscreen de erro

Páginas globais de erro interrompem a navegação e não são substitutas de
`CoeloStatePanel`. O painel continua sendo usado para loading, vazio, bloqueio
ou falha dentro de uma superfície existente; a página fullscreen é reservada
para falhas de rota, permissão ou disponibilidade que ocupam toda a janela.

| Parte | Padrão canônico |
| --- | --- |
| Códigos | 403, 404, 500 e 503. O 401 redireciona para autenticação e o 429 permanece contextual. |
| Superfície | Tela limpa, sem shell, menu ou cabeçalho, em `colorScheme.primaryContainer` com conteúdo em `onPrimaryContainer`. Não usar vermelho como fundo: o erro é comunicado também por código e texto. |
| Anatomia | Código, divisor e mensagem centralizados, seguidos por uma única ação contextual. Não adicionar ilustração, logo ou ícone sem nova aprovação. |
| Conteúdo | 403: “Você não tem permissão para acessar esta área.”; 404: “Não encontramos a página que você procura.”; 500: “Não foi possível concluir esta ação.”; 503: “O Coelo está temporariamente indisponível.” |
| Ação | “Voltar ao início” em 403/404; “Tentar novamente” em 500/503. O destino ou retry é delegado ao app. |
| Responsividade | Em janela ampla, código, divisor e mensagem ficam em linha. Em compact ou com texto ampliado, passam para coluna. Usar `LayoutBuilder`, `SafeArea`, scroll vertical, padding horizontal adaptativo de `spacing.10` (40 px) em amplo e `spacing.4` (16 px) em compact, padding vertical `spacing.8` (32 px) e largura máxima de leitura de 720 px. |
| Acessibilidade | Anunciar “Erro {código}. {mensagem}” como uma única informação, sem duplicar os filhos. A ação mantém foco visível, teclado e alvo mínimo do tema. |
| QA | Validar 375, 768, 1024 e 1440 px, light/dark, texto a 200%, ausência de overflow e goldens das quatro variantes. |

A primeira referência implementada é o Superadmin, documentada em
`docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md`. Admin e
Principal só adotam a composição quando suas specs consumidoras confirmarem
destino, navegação e contexto; não compartilhar telas entre apps.

# 17. Admin, Superadmin, tabelas e dados

Os painéis administrativos devem ser mais densos que o App, mas não mais confusos. Densidade vem de tipografia e layout, não de reduzir alvos ou esconder labels.

## 17.1 Tabelas

Para listas administrativas amplas, reutilizar `CoeloAdminResizableTable`, cuja
referência de composição é a tabela de Instituições. Não substituir por uma
`DataTable` genérica nem criar uma tabela paralela sem aprovação explícita.

| Elemento | Padrão canônico |
| --- | --- |
| Superfície | Card em `colorScheme.surface`, borda `colorScheme.outlineVariant`, raio do card e clip anti-alias. O conteúdo não deve vazar pelos cantos. |
| Cabeçalho | `colorScheme.surfaceContainer`, 12–14 px SemiBold e rótulos acessíveis; manter a mesma geometria das colunas de dados. |
| Linha | 64 px mais divisor de 1 px `colorScheme.outlineVariant`; linhas contínuas, sem zebra, raio ou espaçamento entre si. Hover, foco e seleção usam `colorScheme.primaryContainer`. |
| Coluna fixa | A primeira coluna é uma coluna fixa visual durante o scroll horizontal; a duplicação visual não pode duplicar a semântica no leitor de tela. |
| Overflow | Exibir scrollbar horizontal visível quando necessário, permitir mouse, toque, caneta e trackpad e preservar o clip do card. |
| Redimensionamento | Cada coluna redimensionável oferece redimensionamento por mouse e teclado, cursor de coluna, foco visível e rótulo semântico para aumentar ou reduzir a largura. |
| Texto longo | Usar truncamento sem quebra (`ellipsis`), sem wrap; tooltip somente para informação não crítica. |
| Status | Status semântico usa chip: texto sempre acompanha cor e ícone opcional. |
| Ações | Usar ações compactas: no máximo duas ações rápidas ou menu contextual; separar ações sensíveis. |
| Números | Alinhar à direita; usar tabular figures quando disponível. |
| Responsividade | Priorizar colunas; no compact, usar cards quando necessário. Se a tabela continuar, manter scroll horizontal em vez de ocultar informação crítica. |

## 17.2 Paginação administrativa

Reutilizar `CoeloAdminPagination` em listagens administrativas paginadas. O
controle mantém todas as quebras centralizadas, ações anterior/próxima,
indicador e páginas numeradas, além do seletor compacto opcional de itens por
página. O gatilho e o menu usam superfície neutra; seleção, hover e foco usam
`primaryContainer` e `primary`, sem check ou checkbox. O consumidor define os
tamanhos permitidos e deve validar teclado, foco, semântica, compactação e texto
a 200%.

Instituições é a referência aprovada. Seus tamanhos de página e o rodapé sticky
com blur são governados pela spec da superfície; não são variante nem
responsabilidade do componente público. Com texto ampliado, rótulo e gatilho do
seletor podem quebrar internamente e o gatilho pode expandir sem alterar a API.

## 17.3 Paleta para gráficos — uso exclusivo de dados

| Cor | Token / nome | HEX | Uso principal | Texto sobre a cor | Contraste |
| --- | --- | --- | --- | --- | --- |
| ■ | data.1 | #D63C00 | Série principal / Coelo. | #FFFFFF | 4.66:1 |
| ■ | data.2 | #2B6CB0 | Comparação azul. | #FFFFFF | 5.42:1 |
| ■ | data.3 | #287D78 | Comparação teal. | #FFFFFF | 4.89:1 |
| ■ | data.4 | #6B5AA6 | Comparação roxa. | #FFFFFF | 5.77:1 |
| ■ | data.5 | #2F7A4F | Comparação verde. | #FFFFFF | 5.23:1 |
| ■ | data.6 | #8A5B00 | Comparação dourada. | #FFFFFF | 5.87:1 |

- Sempre exibir label, valor, legenda ou padrão; a cor nunca é o único identificador.

- Em dark mode, clarear séries ou usar outline de 1 px para manter 3:1 contra o background.

- Evitar gráficos 3D, arco-íris, pizza com muitas categorias e dashboards “Natalinos”.

- Para status binário, use semântica; para séries analíticas, use data.1–6.

## 17.4 Contratos de superfícies e interação

Esta seção operacional formaliza a decisão aprovada em
`docs/superpowers/specs/2026-07-27-popup-surface-standard-design.md`. Ela
complementa a fonte oficial deste documento para popups, estados de hover,
fechamento e filtros; não cria componente público nem altera fluxos de domínio.

### Popups, modais, diálogos e painéis

- A superfície-base usa `colorScheme.surface` em light e dark. É proibido usar
  `colorScheme.primaryContainer`, laranja-claro ou outra tonalidade de marca
  como fundo-base do contêiner.
- A anatomia contém barreira preta translúcida, contêiner de superfície, conteúdo
  contextual, ação primária quando aplicável e ação de fechamento. A barreira
  deve preservar o contraste do conteúdo.
- Painéis de filtro usam `colorScheme.surface`, `CoeloRadius.lg`, borda
  `colorScheme.outlineVariant`, elevação e distância de 4 px do gatilho.
- O diálogo de reporte de bug do Superadmin é a referência canônica de
  composição de overlay, sem promover seu conteúdo de domínio a componente
  genérico.

### Hover, foco e exceções de linhas contínuas

- Não existe um “hover padrão Coelo” aplicado indistintamente. Antes de
  implementar, classificar a superfície como ação primária, ação tonal, item
  discreto, linha contínua, card interativo, item destrutivo ou toggle
  segmentado. Cinza/HEX local e o hover genérico do Material não são contratos.
- Itens discretos de navegação, menus, submenus e listas de ações usam
  `colorScheme.primaryContainer` no hover e foco visível, conteúdo destacado em
  `colorScheme.primary`, `CoeloRadius.md` e margem vertical
  `CoeloSpacing.spaceHalf` entre itens consecutivos.
- O overlay ou splash adicional é transparente: não adicionar camada cinza sobre
  o estado destacado. O estado desabilitado não recebe hover.
- Opções de filtro e linhas de tabelas densas são a exceção: permanecem linhas
  contínuas, sem raio ou espaçamento entre linhas, embora usem
  `colorScheme.primaryContainer` no hover e foco.
- O menu lateral do Superadmin é a referência canônica para itens discretos; a
  tabela administrativa é a referência para a exceção de linha contínua.
- Card interativo mantém `colorScheme.surface`; hover e foco enfatizam a borda
  com `colorScheme.primary` translúcido e a sombra primária sutil, preservando
  `CoeloRadius.lg`. Não preencher o card inteiro com `primaryContainer`.
- Item destrutivo usa `colorScheme.errorContainer` no fundo e
  `colorScheme.error` no conteúdo, em grupo separado por divisor. O flyout de
  Perfil, com `Sair` abaixo do divisor, é a referência.
- Toggle segmentado usa contêiner pill em `surface`, borda/divisória
  `outlineVariant` e segmento selecionado, hovered ou focado na hierarquia
  `primaryContainer`/`primary`.

### Diretórios administrativos e flyouts

- Instituições é a referência canônica de diretório: toolbar; busca e filtros;
  toggle cards/tabela; arquivos; conteúdo; paginação sticky.
- Card administrativo clicável usa `CoeloAdminInteractiveCard`. Ele preserva
  `surface` e `radius.lg`; hover/foco enfatizam somente borda e sombra na
  hierarquia primária. Não compor `Card` + `InkWell` local nem aceitar overlay
  Material cinza ou hover retangular.
- A baseline de Instituições é obrigatória para todo card de diretório
  administrativo; usar `CoeloAdminInteractiveCard`. Quando houver status
  semântico, usar `CoeloAdminExpandableStatusIndicator`: o indicador começa circular
  em 24 × 24 e sem texto; hover, foco por teclado ou toque no indicador o
  expande para revelar o rótulo. A cor segue o token semântico do status e o
  texto impede dependência exclusiva de cor. Com reduced motion, a expansão
  acontece sem animação não essencial. Não usar chip sempre aberto como
  substituição silenciosa desse padrão.
- Flyout de ações usa `CoeloAdminFlyout`. Itens comuns usam o hover discreto
  arredondado; itens terminais/destrutivos usam
  `CoeloAdminFlyoutTone.negative`, `error` em repouso e `errorContainer` no
  hover/foco, com divisor antes do grupo.
- Entre toolbar e conteúdo usar `CoeloSpacing.space4`.
- Cards usam `CoeloSpacing.space6` nos dois eixos, largura de referência mínima
  de 340 px, altura mínima de 216 px e padding horizontal `space6`/vertical
  `space4`.
- No modo tabela, compor `CoeloAdminCreateAction.banner`,
  `CoeloSpacing.space4` e `CoeloAdminResizableTable`, nessa ordem.
- `CoeloAdminFileActions` agrupa importação e exportações. Seu flyout usa
  `surface`, sem tint, e hover de item discreto.
- Flyouts de Tour e Perfil são as referências de menu ancorado: `surface`, sem
  tint, `radius.lg`, borda, elevação e padding `space2`. Ações destrutivas como
  sair, excluir e deletar ficam abaixo de divisor, com respiro `space1`.
- O toggle cards/tabela é um controle segmentado único, não dois botões soltos.
  Cada segmento preserva alvo mínimo de 48 px e nome acessível.
- Clicar diretamente em Tabela abre a visão `Agrupado`. Quando o diretório
  possui detalhes hierárquicos, hover ou foco nesse segmento abre um flyout
  `surface`, sem tint, com borda, raio e elevação Coelo; toque e teclado devem
  oferecer o mesmo caminho, sem depender apenas de hover.
- O rodapé sticky de paginação é composição privada reutilizável nos diretórios
  do Superadmin. Usa `surface` translúcida a 84% no tema claro e 88% no escuro,
  blur `CoeloSpacing.space3`, sem borda ou linha superior e com altura medida
  para não cobrir conteúdo ou launcher. Cards oferecem `11, 20, 50, 100`;
  tabela oferece `8, 20, 50, 100`. Paginação inline não sticky fica fora desse
  contrato.

#### Gate de criação administrativa

Toda criação ou alteração visual em `apps/superadmin/lib/features` executa,
a partir de `apps/catalog`:

```text
rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json
```

O gate bloqueia novas composições Material brutas de card, flyout, dropdown,
radio, checkbox e seletor de intervalo de datas. A
allowlist registra somente legado existente, com caminho, símbolo, contagem
máxima e justificativa; ela não pode crescer para acomodar código novo.

### Baselines visuais aprovadas do Superadmin

As superfícies abaixo foram aprovadas em conjunto pelo Owner Coelo em
2026-07-29. A matriz operacional completa e os caminhos dos goldens ficam em
`.agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md`.
Ela é obrigatória ao criar, refazer, refatorar, corrigir ou revisar qualquer
UI do Superadmin. A referência se aplica em quatro escalas: estado interativo,
componente/widget, composição de seção e arquitetura da página inteira. Mesmo
quando não há widget idêntico para reutilizar, o conceito repetitivo e a
hierarquia da família aprovada continuam obrigatórios.

Quando uma solicitação nomear uma tela como referência, consultar sua
implementação, componentes compartilhados, testes e golden antes do código.
“Basear-se em Instituições” inclui de fato toolbar, busca, filtros, toggle,
Arquivos, flyouts, cards, status, tabela, gaps e paginação; não autoriza uma
aproximação local com widgets Material semelhantes.

| Família | Baseline aprovada |
| --- | --- |
| Login | campos default/foco, checkbox, ação principal default/hover, recuperação e aviso restrito |
| Instituições | baseline obrigatória de cards de diretório; toolbar, filtros, toggle, arquivos, cards/default/hover sem cinza, status 24 × 24 progressivo, tabela, gaps e paginação |
| Home | conversas, orientação central, sugestões e compositor inferior |
| Navegação | menu expandido, rail compacto, seleção por nível e flyouts |
| Conta | flyout, Perfil, ajuste de foto e Configurações |
| Overlays | popup de Bug como anatomia modal; X sempre negativo |
| Criar/Editar Instituição | baseline automática de toda criação/edição: formulário ou wizard, conteúdo, campos, uploads, responsividade e rodapé de tela com ações nos extremos |

Os goldens aprovados são evidência visual, não licença para copiar números
locais. Componentes e tokens continuam sendo a implementação canônica. Arquivos
em diretórios `failures/` são diagnósticos transitórios e nunca baseline.

### Padrões visuais rejeitados

Os 14 anexos rejeitados pelo Owner Coelo estão formalizados em
`.agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md` e no
catálogo como `pattern.rejected-visual-patterns`. Toda mudança deve comparar a
proposta com essa matriz antes do código.

- Hover, foco ou seleção não usam faixa/fundo cinza genérico.
- `DropdownButton`, `DropdownButtonFormField`, `RadioListTile`,
  `CheckboxListTile` e `showDateRangePicker` não entram diretamente em feature
  nova; usar componente Coelo indexado ou proposta aprovada.
- Rodapé de página segue Criar/Editar instituição: saída/cancelar à esquerda e
  continuidade à direita no amplo; composição empilhada no compacto.
- Uma identidade diferente em tela de criação/edição interrompe o fluxo antes
  do código e exige comparação e aprovação explícita do Owner.
- Dialog segue Popup de Bug/Ajustar foto, inclusive ações proporcionais e `X`
  negativo; `OK` genérico e título truncado são regressões.
- Cards e seções independentes preservam gaps/paddings `CoeloSpacing`; bordas
  encostadas e zero gap não são densidade, são falha de hierarquia.
- Se nenhuma baseline aprovada atender, a implementação para e abre proposta.
  Default Material e aumento de allowlist não são alternativas.

### Ações negativas

- `X`, sair, desligar, encerrar, fechar, remover, deletar e excluir pertencem à
  hierarquia negativa enquanto habilitados. Não usar `primary`, grafite ou
  cinza para esses verbos.
- Fechar/dispensar por ícone usa `Icons.close_rounded`, `error` no repouso,
  fundo transparente circular e `errorContainer` no hover/foco.
- Item terminal ou destrutivo em menu usa ícone e texto `error` no repouso,
  `errorContainer` no hover/foco e fica em grupo inferior separado por divisor.
- Botão textual ou outlined negativo usa conteúdo e borda em `error`, com
  `errorContainer` no hover/foco. Confirmação destrutiva principal pode usar
  fundo `error` e conteúdo contrastante; cancelar permanece neutro.
- Disabled segue o contrato disabled do componente, sem hover. A hierarquia
  visual compartilhada não elimina regras específicas de confirmação,
  autorização, auditoria ou retorno de foco.

### Ações em popups e dialogs

- Uma ação ocupa 100% da largura útil.
- Duas ações dividem a linha em 50/50; três ações dividem em terços. Usar
  `CoeloSpacing.space3` entre ações e `Expanded` para igualdade real.
- A prioridade vem do estilo: neutra/cancelar, secundária e
  primária/destrutiva. Não comunicar prioridade fazendo um botão maior.
- Quando constraints reais ou texto a 200% não comportarem a linha, empilhar
  todas as ações com 100% da largura e gap vertical `space2` ou `space3`.
- É proibida a quebra acidental 2+1, larguras intrínsecas diferentes, alinhamento
  irregular ou um botão solto abaixo dos demais.
- `CoeloAdminDialogShell` é a referência para uma e duas ações. Três ações
  permanecem composição documentada até existir evidência para ampliar sua API
  pública.

### Fechar e dispensar

- Todo “X” que fecha ou dispensa uma superfície usa `Icons.close_rounded`,
  ícone `colorScheme.error` em repouso, fundo transparente e forma circular.
- Hover e foco visível usam `colorScheme.errorContainer`, mantendo o ícone em
  `colorScheme.error` e overlay ou splash adicional transparente.
- A ação possui alvo mínimo de 48 px, tooltip contextual e semântica de
  fechamento; não reutilizar este contrato para exclusão de dados ou outra ação
  destrutiva.
- `Esc` fecha overlays quando permitido, descarta rascunhos não aplicados de
  filtros e devolve o foco ao gatilho ou à origem. Mouse, teclado e toque devem
  alcançar os mesmos estados e ações.

### Filtros

- A toolbar apresenta busca, filtros e ações no extremo direito. Busca e
  gatilhos têm altura mínima de 48 px, forma pill com `CoeloRadius.full`,
  superfície neutra e borda `colorScheme.outlineVariant`; foco ou menu aberto
  usa borda `colorScheme.primary` de 2 px.
- O gatilho aberto usa `colorScheme.primaryContainer`; texto e seta ativos usam
  `colorScheme.primary`. As opções têm altura mínima de 48 px, são linhas
  contínuas e usam hover/foco sem camada adicional cinza.
- Multi-select mantém alterações em rascunho até `Aplicar`, busca interna com
  estado vazio e rodapé persistente com `Limpar` e `Aplicar`; a busca interna é
  limpa ao reabrir. No estado selecionado, texto e checkbox usam
  `colorScheme.primary`, mantendo fundo transparente até hover ou foco. O
  checkbox não recebe hover, splash ou fundo próprio.
- Single-select não usa checkbox; seleção, hover e foco usam
  `colorScheme.primaryContainer` no fundo e `colorScheme.primary` no conteúdo.
- `CoeloAdminMultiSelectFilter` é a referência de implementação para o
  multi-select administrativo; a tela de Instituições é a referência canônica
  de comportamento e o popup de Bug é a referência do single-select.

### Acessibilidade e referências canônicas

- Resolver cores por tokens semânticos em ambos os temas, sem HEX ou branco
  literal local. Validar contraste, foco visível, leitor de tela, tooltip,
  teclado, alvo mínimo e retorno de foco.
- Referências canônicas: diálogo de reporte de bug e modal de importação do
  Superadmin para fechamento; menu lateral do Superadmin para hover discreto;
  Instituições para multi-select; popup de Bug para single-select.

# 18. Movimento e transições

Movimento deve explicar continuidade, confirmar ações e preservar orientação. O Coelo não usa animação como decoração permanente.

| Token | Duração | Uso |
| --- | --- | --- |
| motion.instant | 0 ms | Reduced motion e mudança sem transição. |
| motion.fast | 100 ms | Hover, press e microfeedback. |
| motion.short | 180 ms | Saída, fechamento e troca simples. |
| motion.standard | 220 ms | Estado de componente e navegação curta. |
| motion.enter | 280 ms | Modal, sheet e elemento entrando. |
| motion.emphasized | 360 ms | Transição de contexto importante, com parcimônia. |

## Curvas e comportamento

- Padrão: cubic-bezier(0.2, 0, 0, 1). Entradas desaceleram; saídas são ligeiramente mais rápidas.

- Preferir fade, container transform e pequenos deslocamentos. Evitar zooms grandes, bounce e parallax intenso.

- Loading contínuo deve ser discreto e oferecer texto quando a espera passar de alguns segundos.

- Respeitar “reduzir movimento” do sistema; substituir movimento não essencial por mudança instantânea ou fade curto.

# 19. Acessibilidade e inclusão

Meta oficial: WCAG 2.2 nível AA para web e aplicação mobile, usando também as orientações de acessibilidade das plataformas. Em conteúdo crítico e texto pequeno, buscar 7:1 quando viável.

| Critério | Padrão Coelo |
| --- | --- |
| Texto normal | Contraste mínimo 4,5:1. |
| Texto grande | Mínimo 3:1; não usar tamanho como desculpa para baixa legibilidade. |
| Componentes e ícones | Partes essenciais e estados com mínimo 3:1. |
| Foco | Visível, 3 px, offset 2 px; não encoberto por barras. |
| Alvo de toque | 48 × 48 px/dp; atende conforto mobile e supera o mínimo WCAG. |
| Texto ampliado | Layout deve suportar 200% no web e escalas grandes do sistema. |
| Leitor de tela | Nome, papel, estado, valor e erro de cada componente. |
| Teclado | Ordem lógica; Enter/Espaço; Esc fecha overlays; foco retorna à origem. |
| Cor | Nunca comunicar estado somente por cor. |
| Mídia | Alt text quando informativa; legenda/transcrição quando aplicável. |

## Checklist rápido de tela

- Consigo entender a tela em escala de cinza?

- O foco de teclado aparece em todos os controles?

- Texto e controles continuam utilizáveis com fonte ampliada?

- Erros explicam como corrigir e são anunciados pelo leitor de tela?

- A ordem visual é a mesma ordem semântica?

- Dark mode mantém contraste e não inverte significados?

- Animações não essenciais desaparecem com reduced motion?

# 20. Voz, microcopy e conteúdo

A voz do Coelo é humana, tranquila, clara e respeitosa. Fala com adultos responsáveis por crianças; por isso, acolhe sem infantilizar e orienta sem burocratizar.

| Princípio | Faça | Evite |
| --- | --- | --- |
| Direto | “Publicar rotina” | “Prosseguir com o processo de publicação” |
| Concreto | “3 responsáveis ainda não confirmaram” | “Existem pendências” |
| Calmo | “Não foi possível enviar. Tente novamente.” | “Ops! Deu ruim 😢” |
| Responsável | “A foto será vista pela Turma Girassol.” | “Compartilhar com todos” sem contexto |
| Inclusivo | “Responsável”, “criança”, “equipe” | Assumir apenas pai/mãe ou gênero |
| Não estigmatizante | “A criança pareceu sensível hoje” | Rótulos permanentes sobre comportamento |

## Padrões de rótulo

| Tipo | Padrão | Exemplo |
| --- | --- | --- |
| Botão | Verbo no infinitivo ou ação curta. | Salvar, Publicar, Confirmar presença. |
| Título de tela | Substantivo curto e específico. | Agenda, Rotina de Maria. |
| Erro | Problema + correção. | O arquivo excede 20 MB. Selecione um arquivo menor. |
| Sucesso | Resultado concreto. | Comunicado publicado para 4 turmas. |
| Confirmação destrutiva | Objeto + consequência + ação. | Excluir este grupo? Os vínculos serão encerrados. |

# 21. Design tokens e implementação

A nomenclatura separa três camadas: primitive (valor físico), semantic (função) e component (decisão local). O padrão é compatível com a lógica da especificação estável de Design Tokens e facilita Figma, Flutter, web e futuras plataformas.

## 21.1 Convenção

| Camada | Exemplo | Regra |
| --- | --- | --- |
| Primitive | color.orange.500 = #D63C00 | Nunca usar diretamente em tela. |
| Semantic | color.action.primary = {color.orange.500} | Muda conforme tema/contraste. |
| Component | button.primary.background = {color.action.primary} | Somente quando o componente precisar especializar. |
| State | button.primary.hover | Estado explícito e testável. |
| Mode | theme.light / theme.dark / contrast.high | Mesmo token, valores diferentes. |

## 21.2 Tokens essenciais

| Grupo | Tokens mínimos |
| --- | --- |
| Color | background, surface, surfaceSubtle, surfaceRaised, textPrimary, textSecondary, borderSubtle, borderStrong, actionPrimary, actionLink, success, warning, error, info. |
| Typography | displayL/M, heading1/2/3, titleL/M, bodyL/M/S, labelL/M. |
| Spacing | 0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96. |
| Radius | xs, sm, md, lg, xl, full. |
| Elevation | 0, 1, 2, 3. |
| Motion | instant, fast, short, standard, enter, emphasized. |
| Size | touchMin 48, iconSm 20, iconMd 24, avatarSm 32, avatarMd 40, avatarLg 48. |

## 21.3 Flutter/Dart

- Mapear cores principais em ColorScheme; criar ThemeExtension para success, warning, info, chat bubbles e superfícies específicas.

- Mapear a escala em TextTheme e nomes internos estáveis; não declarar TextStyle dentro das telas.

- Criar componentes próprios CoeloButton, CoeloTextField, CoeloCard, CoeloChip e CoeloStatus, todos com estados e semântica.

- ThemeMode.system como padrão, com light/dark manual e persistência da preferência.

- Usar testes golden para componentes em light, dark, texto grande e estados críticos.

## 21.4 Figma

- Collections: Primitives, Semantic Colors, Typography, Spacing/Shape e Components.

- Modes: Light, Dark e futuramente High Contrast.

- Variants: size, hierarchy, state, icon, loading e destructive.

- Documentar anatomia, conteúdo, comportamento responsivo e acessibilidade no próprio componente.

# 22. Governança, handoff e evolução

| Etapa | Responsável | Saída obrigatória |
| --- | --- | --- |
| Proposta | Produto + Design | Problema, evidência, componente afetado e impacto. |
| Revisão | Design + Engenharia + Acessibilidade | Tokens, estados, responsividade e viabilidade. |
| Implementação | Engenharia | Componente reutilizável, testes e documentação. |
| QA | Design + Produto + Segurança quando aplicável | Light/dark, acessibilidade, conteúdo e privacidade. |
| Release | Owner do Design System | Changelog, versão e migração. |

## Definition of Done de componente

- Possui anatomia, variantes, estados e conteúdo definidos.

- Funciona em Light e Dark sem valores HEX locais.

- Atende contraste, foco, teclado, leitor de tela e alvo mínimo.

- Possui comportamento compact, medium e expanded quando necessário.

- Inclui loading, empty, error, disabled e permissão negada quando aplicável.

- Está publicado no Figma e implementado na biblioteca Flutter com a mesma versão.

- Tem exemplos de “usar” e “não usar”.

| Versão recomendada<br>Publicar este documento como Design System Oficial v1.0. Após o protótipo das telas principais, criar v1.1 com ajustes reais de componentes; após o piloto, v2.0 com métricas, acessibilidade validada e componentes estabilizados. |
| --- |

# 23. Checklist operacional de uma nova tela

| Pergunta | Sim/Não |
| --- | --- |
| A mudança declarou qual das sete famílias aprovadas é a baseline principal? | □ |
| Se cria ou edita uma entidade, adotou Criar/Editar Instituição automaticamente? | □ |
| Qualquer divergência visual foi proposta e aprovada antes do código? | □ |
| A comparação cobre estado, widget, seção e página inteira? | □ |
| Os 14 padrões rejeitados foram verificados e estão ausentes? | □ |
| Existe uma única ação primária claramente identificada? | □ |
| O contexto ativo (instituição, papel, criança/grupo) está claro? | □ |
| A tela usa tokens semânticos e componentes oficiais? | □ |
| Texto principal usa 16/24 e labels são legíveis? | □ |
| Contraste foi validado em Light e Dark? | □ |
| Todos os controles têm alvo de 48 × 48 e foco visível? | □ |
| Loading, vazio, erro, offline e permissão negada foram desenhados? | □ |
| A interface continua compreensível sem cor? | □ |
| Dados e mídia infantil estão minimizados e com audiência clara? | □ |
| A tela funciona em compact, medium e expanded? | □ |
| Microcopy explica resultado, consequência e próxima ação? | □ |
| Eventos de analytics e auditoria necessários foram especificados? | □ |

# 24. Fontes e referências

Pesquisa realizada em 21/06/2026. As fontes externas abaixo servem como base normativa e técnica; as decisões de marca e produto permanecem específicas do Coelo.

1. W3C — Web Content Accessibility Guidelines (WCAG) 2.2 — Contraste, foco, tamanho de alvo, movimento e critérios AA.

2. W3C — Guidance on Applying WCAG 2.2 to Mobile Applications — Aplicação das diretrizes a apps nativos e híbridos.

3. W3C WAI — Understanding Contrast Minimum — Relações mínimas de contraste.

4. W3C WAI — Non-text Contrast — Contraste de componentes, ícones e estados.

5. W3C WAI — Focus Appearance — Visibilidade e área do indicador de foco.

6. Material Design 3 — Color system and roles — Papéis de cor, temas Light/Dark e uso de tokens.

7. Material Design 3 — Typography — Papéis e escala tipográfica.

8. Material Design 3 — Shape — Escala de cantos e expressão de marca.

9. Material Design 3 — Adaptive layout and breakpoints — Layouts adaptativos e classes de janela.

10. Material Design 3 — Motion — Princípios de movimento e continuidade.

11. Apple Human Interface Guidelines — Accessibility — Contraste, legibilidade e acessibilidade em plataformas Apple.

12. Apple Human Interface Guidelines — Buttons — Região mínima de interação de 44 × 44 pt.

13. Google Fonts — Nunito Sans — Família tipográfica e disponibilidade.

14. W3C Design Tokens Community Group — Specification 2025.10 — Formato interoperável e estável para design tokens.

## Documentos internos Coelo

- Product Vision Oficial v1 — Coelo

- História da Logo e Marca Oficial v1 — Coelo

- PRD Master Oficial v1 — Coelo

- PRD App Oficial v1 — Coelo

- PRD LGPD, Segurança e Mídia Oficial v1 — Coelo

- PRD Auth, Multi-tenant e Permissões Oficial v1 — Coelo

- PRD Superadmin Oficial v1 — Coelo

- PRD Admin Oficial v1 — Coelo

- PRD Modelo de Dados Master Oficial v1 — Coelo

COELO

Acompanhe a rotina. Centralize a comunicação. Conecte família e instituição.

Design System Oficial v1.0 · coelo.me
