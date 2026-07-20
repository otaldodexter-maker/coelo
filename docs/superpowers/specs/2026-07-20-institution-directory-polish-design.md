---
title: "Institution Directory Interaction and Brand Polish"
source: "Ajustes aprovados pelo usuario em 2026-07-20"
status: "approved-design"
generated_at: "2026-07-20"
---

# Institution Directory Interaction and Brand Polish

## Objetivo

Refinar interacoes e marca da shell do Superadmin e tornar pesquisaveis os filtros geograficos do Diretorio de Instituicoes, preservando o layout flutuante aprovado, os tokens Coelo e a arquitetura existente.

## Escopo

- Remover qualquer pelicula cinza dos estados hover dos itens Perfil, Configuracoes e Sair.
- Usar o hover laranja semantico em Perfil e Configuracoes.
- Exibir texto e icone de Sair com a cor semantica de erro e hover baseado em `errorContainer`.
- Usar a logo oficial branca dentro de circulo laranja no tema claro.
- Usar a logo oficial laranja dentro de circulo branco no tema escuro.
- Adicionar pesquisa local, sem diferenciar caixa ou acentos, dentro dos menus de UF, Municipio e Bairro.
- Preservar a dependencia atual: Municipio aparece apos selecionar UF; Bairro aparece apos selecionar Municipio.
- Registrar a futura legenda clicavel de status como decisao pendente, sem criar a legenda nesta entrega.

## Fora de escopo

- Definir significados, cores finais ou transicoes dos status institucionais.
- Alterar o schema Supabase, pois as opcoes geograficas ja sao retornadas pelas consultas existentes.
- Transformar os filtros em campos de autocomplete externos ou alterar a ordem aprovada da toolbar.
- Alterar os arquivos oficiais de marca mantidos na raiz do monorepo.

## Design e componentes

### Menu do usuario

Os tres itens continuam usando `MenuItemButton`. Os estilos controlarao explicitamente `backgroundColor`, `foregroundColor`, `iconColor` e `overlayColor`. O overlay sera transparente para impedir que o Material componha cinza sobre os fundos semanticos. Perfil e Configuracoes usam `primaryContainer`/`primary`; Sair usa `errorContainer`/`error`.

### Filtros geograficos

`_DirectoryFilterMenu` recebera uma opcao `searchable`. Quando ativa, o menu exibira no topo um campo arredondado com o placeholder coerente com o filtro. O texto filtrara apenas as opcoes ja carregadas, por rotulo, com normalizacao de caixa e diacriticos. Abrir, fechar ou selecionar uma opcao limpa a busca sem alterar o valor aplicado.

Somente UF, Municipio e Bairro serao pesquisaveis. Tipo e Status permanecem como menus simples.

### Marca por tema

O Superadmin passara a empacotar copias dos SVGs oficiais necessarios e renderiza-los com `flutter_svg`:

- tema claro: `logo Coelo branco.svg` sobre `colorScheme.primary`;
- tema escuro: `logo Coelo Laranja.svg` sobre a cor semantica branca do tema.

O container da marca sera um circulo perfeito, preservando o alvo e o alinhamento atuais nos menus expandido e recolhido. Nenhum HEX sera criado na shell.

## Estados e acessibilidade

- Hover, foco e pressionado terao feedback sem pelicula intermediaria.
- Campos de pesquisa terao rotulo/placeholder acessivel e foco por teclado.
- A pesquisa vazia restaura todas as opcoes.
- Nenhum resultado exibe mensagem segura dentro do menu.
- Os alvos continuam respeitando o minimo de toque do design system.

## Testes

- Widget test para foreground e `iconColor` vermelhos do item Sair.
- Widget test para overlay transparente e fundos semanticos dos tres itens.
- Widget tests de pesquisa de UF, Municipio e Bairro, incluindo caixa e acentos.
- Widget test para limpar a pesquisa apos selecao/reabertura.
- Widget test para asset e fundo corretos nos temas claro e escuro.
- Analise estatica, suite Flutter completa e build web.

## Riscos e mitigacoes

- A adicao de `flutter_svg` aumenta uma dependencia: limitar o uso aos assets oficiais e manter as copias dentro do pacote Flutter.
- Menus pesquisaveis podem perder estado entre overlays: manter o estado no widget do filtro e limpar a consulta em transicoes explicitas.
- Assets oficiais possuem alteracoes locais do usuario: nao sobrescrever nem incluir mudancas alheias no commit.

## Criterios de aceite

- Nenhum item do menu do usuario apresenta camada cinza durante hover ou foco.
- Sair apresenta texto e icone vermelhos e hover vermelho semantico.
- UF, Municipio e Bairro podem ser pesquisados por texto dentro dos respectivos menus.
- A logo segue a combinacao branco/laranja aprovada em ambos os temas e permanece circular.
- A futura legenda clicavel de status fica documentada sem UI prematura.

