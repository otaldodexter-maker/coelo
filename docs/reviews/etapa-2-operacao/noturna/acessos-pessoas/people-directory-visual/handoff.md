---
source: "coordenacao r12 GOLDEN-REBASELINE-CRITERIO; censo noturno; historico Git"
status: "local-green; sem certificacao FE/BE/E2E"
generated_at: "2026-09-09"
---

# Diretorio de Pessoas

`apps/superadmin -> Acessos -> Pessoas -> cards claro / tabela escura -> people.list`.
Um teste conhecido vermelho no censo, oito comparacoes:375/768/1024/1440.
Referencia antiga7a16e625c, base materializada d784462c1 e HEAD de inicio c76a0eb23.

Os oito pares foram abertos integralmente antes de qualquer substituicao.
Arquivos `*-before.png` e `*-inspected.png` preservam a inspecao. Somente as oito referencias listadas em manifest.json foram substituidas por copias exatas dos renders inspecionados. Nenhum codigo alterado neste lote.

| Diferenca | Causa integrada |
| --- | --- |
| Card/banner Criar ausente sem callback; cards e linhas restantes informativos | 2c0dbe84b, removidos callbacks vazios e criacao condicionada a onCreate |
| Busca/filtros em colunas de largura igual; Auth ocupa linha compacta inteira;768 usa duas linhas | f546561d4, _EqualWidthControlGrid em CoeloAdminListingToolbar |
| Fundo compacto usa surface em ambos os temas; icone Arquivos usa primary | d8800300d, Scaffold explicito e CoeloAdminFileActions |
| Marca Coelo/chevron e altura64 compacta | d9232a94d |
| Pagina375 usa setas e pagina atual, liberando altura de conteudo | bd476af8d, CoeloAdminPagination |
| Busca lateral, espacamento e cores de selecao hierarquica | 7f918d72a |
| Bug report ausente sem callback | ad558c6f9 |

Todas as causas sao ancestrais da base integrada; checks nominais no manifest.
375: sem criacao ficticia, primeiro card e linhas reais da fixture tornam-se visiveis; footer compacto.768: grade de filtros reduz uma linha, cards redistribuidos, tabela sobe sem banner.1024/1440: sidebar atual, filtros distribuidos e conteudo sobe/redistribui sem criacao. As geometrias e cores internas de cards/tabela nao receberam redesign. Escuro compacto tem causa explicita de surface; nao foi aceito drift generico de tema. Dados sao fixtures sinteticas.

`person_golden_test.dart --plain-name 'matches people cards light and table dark at supported widths'`: RED1F, oito comparacoes divergentes; apos substituicao nominal, comparador sem update1P/0F, exit0. Logs red.txt/green.txt. N1 unico; nao somar oito imagens como oito testes nem RED/rerun. Formulario e teste200% nao repetidos.

people.list permanece pending-verification: contrato interno de diretorio/filtro e runtime com persona ainda pendentes. Nao certificar diretorio por reader de detalhe. Politica de arquivos/MFA e bloqueios de escrita preservados. Nenhuma mutacao remota ou nova decisao de produto; nenhuma projecao de conhecimento criada por atividade.
