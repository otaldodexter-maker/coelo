---
title: "Paridade visual de Pessoas com Instituições"
source: "pedido aprovado do usuário em 2026-07-29; tela e goldens aprovados de Instituições; contrato Coelo UI de formulários e superfícies"
status: "approved-design"
generated_at: "2026-07-29"
---

# Paridade visual de Pessoas com Instituições

## Objetivo

Alinhar a listagem, Criar pessoa e Editar pessoa à composição visual e
interativa aprovada de Instituições. Este incremento é exclusivamente de UI/UX:
não cria fluxo real de upload, download, Supabase ou MFA.

## Autoridade visual

A implementação deve copiar a anatomia, os tokens e o comportamento já
existentes em:

- toolbar, toggle, ação Arquivos, cards, tabela e paginação de Instituições;
- Criar instituição e Editar instituição;
- modal de importação e flyout de arquivos de Instituições;
- popup de Bug e flyouts do perfil e do tour para superfícies, elevação,
  hover, foco e fechamento.

Não serão copiados campos, cores de marca, capa ou regras exclusivas de
Instituições.

## Arquivos

Ao lado direito do toggle cards/tabela, com o mesmo gap e responsividade de
Instituições, haverá um único `CoeloAdminFileActions`:

- `Importar`, com `Icons.upload_file_outlined`;
- `Exportar CSV`, com `Icons.table_rows_outlined`;
- `Exportar XLSX`, com `Icons.grid_on_outlined`.

No modo compacto o gatilho será o botão de pasta de 48 px com tooltip
`Arquivos`. No desktop será o botão outlined com ícone e texto.

Importar abrirá o modal visual de duas etapas usado em Instituições, adaptando
somente textos e nomes de arquivo para Pessoas:

1. escolher arquivo ou exportar o modelo demonstrativo;
2. revisar linhas válidas e linhas com erro.

As três operações produzirão apenas feedback e atividade demonstrativos. Não
haverá seleção, upload, geração ou download real de arquivo.

## Criar e Editar pessoa

O formulário manterá três etapas de domínio:

1. `Identidade`;
2. `Vínculos contextuais`;
3. `Revisão`.

Sua composição será a mesma de Instituições:

- navegação lateral de 248 px no desktop;
- navegação superior no compacto;
- insets `space10`, `space6` e `space4` conforme breakpoint;
- conteúdo central com largura máxima de 880 px;
- cabeçalho `headlineSmall`, descrição `bodyMedium` e gaps `space1/space5`;
- transição Fade + Slide, removida quando reduced motion estiver ativo;
- estados de etapa atual, completa, incompleta e com erro;
- conteúdo rolável e rodapé fora do scroll.

### Identidade

A etapa começará pelo card de foto de perfil de Instituições, adaptado para
Pessoa e usando `CoeloAvatar`:

- criação: `Escolher foto`;
- edição com prévia: `Trocar foto` e `Remover`.

Essas ações são demonstrativas e não enviam mídia. Não haverá foto de capa,
cores de marca ou preview institucional.

Depois do avatar, o grid 2→1 manterá somente os campos de Pessoa já existentes:
tipo, primeiro nome, sobrenome, nome de exibição e nome legal.

### Vínculos e revisão

Os vínculos contextuais e seus resumos continuarão sendo conteúdo de domínio
de Pessoa, mas dentro da mesma superfície neutra, grid, espaçamentos e
hierarquia de Instituições. A revisão mostrará o que foi preenchido sem
introduzir novos dados pessoais.

Pessoas de serviço continuarão somente leitura e usarão o rodapé canônico com
uma única ação `Voltar`.

## Rodapé e saída

O rodapé copiará integralmente a árvore responsiva de Instituições:

- criação termina em `Criar pessoa`;
- edição termina em `Salvar alterações`;
- durante etapas intermediárias da edição, `Continuar` é outlined e
  `Salvar alterações` é filled;
- no compacto, a ação principal ocupa a largura útil e
  `Cancelar`/`Anterior` ficam na linha inferior;
- sair com alterações abre a confirmação administrativa já aprovada.

## Componentes e fronteiras

Serão reutilizados `CoeloAdminFileActions`, `CoeloFormTextField`,
`CoeloAdminSingleSelectField`, `CoeloAvatar`, `CoeloAdminDialogShell`,
`SuperadminShell` e tokens existentes. Nenhum componente, variante, token ou
Design System paralelo será criado.

A composição específica de Pessoa permanecerá em
`apps/superadmin/lib/features/people`.

## Verificação

Aplicar RED/GREEN e validar:

- presença e ordem das três ações de arquivo;
- modal de importação em duas etapas, sem I/O real;
- clique em Criar e em pessoa editável;
- serviço somente leitura;
- navegação e rodapé equivalentes a Instituições;
- hover, foco, teclado, Escape, restauração de foco e semântica;
- light/dark, texto a 200% e reduced motion;
- 375, 768, 1024 e 1440 px;
- goldens de cards, tabela, criar e editar, inspecionados antes de atualização;
- formatação dos Dart afetados, análise estática, widget tests, gates do índice
  e catálogo, conhecimento e `git diff --check`.

## Fora de escopo

- upload, importação, exportação ou download real;
- alteração de Supabase, RPCs, migrations, RLS, MFA ou autorização;
- novos campos pessoais ou sensíveis;
- mudanças no modelo de dados;
- capa, paleta de marca ou campos exclusivos de Instituições.
