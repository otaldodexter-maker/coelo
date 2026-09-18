---
source: "Solicitação aprovada em 2026-07-28 para reduzir a tabela de Instituições a 8 linhas e manter a paginação no rodapé"
status: "approved"
generated_at: "2026-07-28"
updated_at: "2026-07-29"
revised_at: "2026-08-03"
---

# Paginação fixa do diretório de Instituições

## Objetivo e problema

Manter a paginação do diretório de Instituições sempre acessível no limite
inferior da área útil, tanto em cards quanto em tabela, sem encobrir o último
item e sem deixar o controle visualmente solto quando o conteúdo for curto.

A tabela passa de 9 para 8 instituições por página para liberar a altura
necessária ao rodapé e preservar uma composição equilibrada no viewport de
referência.

## Escopo

- Fixar a paginação na parte inferior da área de conteúdo de Instituições.
- Preservar a paginação centralizada nos modos cards e tabela.
- Aplicar ao rodapé uma superfície `glass` local, sem divisor superior, com
  blur e cor semântica translúcida.
- Reservar no conteúdo rolável uma área inferior equivalente ao rodapé mais o
  espaçamento de segurança, para que cards, linhas e scrollbars não fiquem
  ocultos.
- Usar 8 itens por página na tabela e oferecer `8, 20, 50, 100` no seletor.
- Preservar 11 itens por página nos cards e oferecer `11, 20, 50, 100`.
- Preservar o comportamento atual de troca de página, tamanho de página,
  filtros, ordenação e modos de visualização.

## Fora de escopo

- Alterar a API pública ou o visual interno de `CoeloAdminPagination` em escala
  de texto normal.
- Criar componente, variante ou token global para rodapés com blur.
- Alterar cards, colunas, dados exibidos, filtros ou regras de ordenação.
- Alterar paginação inline de Suporte, quando ela não for sticky/glass.
- Mudar consultas, policies, RLS ou contratos de banco além do valor
  `pageSize` já aceito pelo diretório.

### Exceção acessível confirmada na verificação

O teste obrigatório com texto a 200% revelou overflow no seletor compartilhado.
Fica aprovada a correção interna mínima de permitir quebra do rótulo e ampliar
o gatilho somente em escala de texto elevada. A API pública, os tokens e a
aparência em escala normal permanecem inalterados; esta exceção não transforma
o rodapé `glass` de Instituições em padrão global.

## Superfícies afetadas

- `InstitutionDirectoryPage`, nos modos cards e tabela.
- Consulta paginada do diretório somente quanto ao tamanho inicial da tabela.
- Testes de widget e referências visuais do diretório de Instituições.
- Memória interna do comportamento do diretório.

## Composição e comportamento

`InstitutionDirectoryPage` mantém uma única instância de
`InstitutionDirectoryPagination`. A tela organiza conteúdo rolável e rodapé em
uma composição local:

1. toolbar, estados e resultados continuam roláveis;
2. a paginação permanece posicionada no limite inferior da área útil;
3. a rolagem recebe um inset inferior calculado a partir da altura real do
   rodapé, acrescido de `CoeloSpacing.space4`;
4. quando o conteúdo chega ao fim ou é menor que o viewport, o rodapé continua
   alinhado ao fim da área disponível, sem salto ou troca de posição;
5. mudanças de largura que façam `CoeloAdminPagination` quebrar em mais linhas
   atualizam o inset reservado.

O rodapé usa `ClipRect` e `BackdropFilter`, com blur baseado em
`CoeloSpacing.space3`. A superfície usa `colorScheme.surface` translúcida, com
opacidade local de `0.84` no tema claro e `0.88` no escuro, sem borda ou linha
superior. O conteúdo recebe padding vertical por tokens, `SafeArea` e o mesmo
alinhamento horizontal já aprovado para a paginação.

O tratamento permanece privado ao app Superadmin e é reutilizado por seus
diretórios sticky de Instituições, Unidades, Grupos, Atividades, Pessoas,
Usuários Internos e Perfis e Permissões. Ele não cria variante pública em
`coelo_ui_admin`.

## Estados de UX

- **Carregando:** a superfície fixa pode permanecer ausente até existir
  paginação válida; o indicador de carregamento continua no conteúdo rolável.
- **Sucesso em cards:** paginação fixa com 11 itens por página.
- **Sucesso em tabela:** paginação fixa com 8 itens por página.
- **Conteúdo longo:** resultados rolam por trás da faixa translúcida, mas o
  inset impede ocultação do último item.
- **Conteúdo curto:** a paginação fica no limite inferior da área útil.
- **Quebra compacta:** o `Wrap` compartilhado pode ocupar mais linhas; a altura
  reservada acompanha a composição real.
- **Light e dark:** a faixa usa apenas cores semânticas do tema.
- **Menu de itens por página aberto:** continua ancorado ao gatilho e deve
  permanecer visível sobre a faixa.

## Entidades, dados e permissões

Nenhuma entidade, dado pessoal ou autorização muda. O valor `pageSize` continua
fluindo por `InstitutionDirectoryQuery` e pelos repositórios existentes. O
isolamento por tenant, as policies e as permissões do Superadmin permanecem
inalterados.

## Eventos, logs e notificações

Não são criados eventos, logs, auditorias ou notificações. A alteração é apenas
de apresentação e tamanho de página.

## Acessibilidade e responsividade

- Os controles preservam os rótulos semânticos, foco, teclado e alvos mínimos
  já fornecidos por `CoeloAdminPagination`.
- O blur não pode reduzir o contraste do texto e dos controles.
- O último item deve permanecer totalmente alcançável por rolagem.
- O rodapé respeita `SafeArea` e não pode sobrepor o launcher de chat.
- As larguras 375, 768, 1024 e 1440 px devem permanecer sem overflow nos temas
  claro e escuro.

## Critérios de aceite

- A tabela solicita e apresenta 8 instituições por página ao entrar nesse modo.
- O seletor da tabela oferece `8, 20, 50, 100`; cards preservam
  `11, 20, 50, 100`.
- A paginação permanece visível no limite inferior durante a rolagem em cards e
  tabela.
- Conteúdo curto mantém a paginação alinhada ao fim da área disponível.
- O último card e a última linha ficam totalmente visíveis e não são encobertos
  pelo rodapé.
- A superfície fixa apresenta blur, fundo semântico translúcido e espaçamento
  coerentes em light e dark, sem linha superior.
- O menu de tamanho de página abre acima da faixa e continua interativo.
- Não existe mudança na API pública de `CoeloAdminPagination`.

## Testes exigidos

- Teste de domínio/view model para o tamanho de página da tabela igual a 8.
- Teste de widget para as opções `8, 20, 50, 100` na tabela.
- Testes de widget para posição inferior persistente em cards e tabela.
- Teste de widget que role até o fim e confirme que o último item não está
  encoberto.
- Teste de widget em largura compacta para atualização da altura reservada.
- Golden focado do rodapé em light e dark, incluindo a convivência com o
  launcher de chat.
- Formatação, análise estática e suíte focada de Instituições.

## Riscos e perguntas abertas

- O blur pode ter custo de rasterização. A área filtrada deve ficar restrita à
  faixa do rodapé.
- A altura da paginação varia conforme a largura. O inset não deve usar altura
  fixa; deve acompanhar o tamanho renderizado.
- Não há pergunta de produto aberta. A reutilização aprovada permanece privada
  ao Superadmin; uma promoção para API pública exige proposta separada.
