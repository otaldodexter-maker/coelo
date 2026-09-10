---
title: "Rodada noturna 09→10/09/2026 — relatório ao Owner"
source: "Coordenação e Integração — Claude; entregas dos oito grupos; inventario-etapa-2.json"
status: "em construção — fechado após o corte das 05:00 de 10/09"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Rodada noturna — relatório ao Owner

> Documento vivo. Os números são medidos, datados e reproduzíveis; onde falta
> medição, está escrito que falta.

## Como o trabalho foi verificado

Oito grupos trabalharam em worktrees isoladas a partir da base integrada
`d784462c1`. Todo lote entrou em `dev` por revisão de código mais verificação na
base conjunta, nunca por confiança no relato do autor. O padrão foi medir a mesma
seleção de testes **antes** e **depois** do merge, para separar falha
preexistente de regressão.

O método já evitou três enganos concretos:

- As falhas de golden que três frentes reportaram eram deriva da própria base.
  Reproduzi cada conjunto numa worktree destacada em `d784462c1` intocado e
  encontrei exatamente as mesmas falhas, com os lotes somando apenas casos que
  passam.
- Dois lotes adicionaram, cada um por sua conta, o mesmo parâmetro
  `principalCircularRepository` ao router, ao app, ao auth scope e ao `main`. O
  Git mesclou os dois lados limpo, porque as linhas não se sobrepõem, e só o
  analisador pegou os nove erros. **Merge limpo não é árvore que compila.**
- Três grupos escolheram independentemente o mesmo carimbo de migration, e um
  escolheu carimbos anteriores a migrations já existentes. Worktree separada não
  protege de colisão lógica; a ordem da fila é global e pertence ao integrador.

## Movimento medido da suíte

| Base | Hora | Resultado |
| --- | --- | --- |
| `ecc8eae2b` | 19:30 | 5707 PASS, 9 SKIP, 190 FAIL |
| `414b82b29` | 20:40 | 5871 PASS, 9 SKIP, 182 FAIL |

A rodada somou casos que passam e **reduziu 8 falhas**. Nenhum número soma
reexecuções. O catálogo das 182, por arquivo e por dono, está no
[catálogo de falhas](NOTURNA-catalogo-falhas.md).

O número que importa mais que o total: das 182, **144 são suítes de golden e
apenas 38 não são**. A metade de golden depende da sua decisão de rebaseline, não
de código. Dez das 38 foram recuperadas logo depois dessa medição, com uma linha
por construção de router numa flag que voltou a ser necessária desde
`b20a9c205`.

## Conclusão certificada

| Camada | Antes | Agora |
| --- | --- | --- |
| Front-end `verified` | 7/230 | 11/230 |
| Back-end `done` | 0/223 | 0/223 |
| Integração `verified-e2e` | 0/198 | 0/198 |

Backend e integração não se moveram, e isso é esperado: **nada foi aplicado em
ambiente remoto**. O projeto Supabase `coelo` e os buckets R2 são produção, e
você ficou indisponível a partir das 18:26, portanto nenhuma autorização nominal
pôde ser concedida. Nenhuma rota rodou contra Supabase autenticado, e prova local
não promove E2E.

O que avançou além dos quatro certificados foi a honestidade do resto. Os
bloqueios agora estão separados entre `blocked-decision`, onde falta uma decisão
sua, e `blocked-environment`, onde o pacote está revisável e só falta a aplicação
remota que esta rodada proibiu.

## O achado mais importante da rodada

Uma frente entregou 61 testes verdes de Suporte e reportou aceite funcional
exercitado. Depois voltou por conta própria, contra o próprio número e com o
delta já aplicado, para corrigir: **Suporte não tem camada de dados**. A pasta
tem apenas domain e presentation, sem data, sem repositório, sem sequer uma
interface, e nada em packages define SupportTicket. Em produção a rota nem abre:
nenhum ponto de composição injeta o controlador e o router devolve 503. Os 61
casos exercitavam um controlador de protótipo em memória.

Verde sobre protótipo não é verde sobre produção. A partir dessa correção, toda
promoção de estado passou a exigir três respostas por escrito: main.dart compõe o
caminho? o router monta a página produtiva? existe implementação de produção do
repositório, e não só a interface?

**Em menos de uma hora a mesma pergunta pegou mais três casos independentes**, e
é esse resultado que muda o significado do painel:

- `forms.respond`: a rota constrói a página sem api e descartando o
  `:occurrenceId` que o próprio path declara. A correção de limites numéricos
  está provada no widget e não é alcançável pela rota produtiva.
- `health-care` e `medication`: a rota produtiva monta o controlador com
  `UnavailableHealthCareRepository`, e o escopo autenticado injeta
  `UnavailableMedicationPlanRepository`. Não existe implementação Supabase de
  nenhum dos dois. Os 182 PASS de um e os 39 do outro são verdes sobre fixture.
- `daily_routine`: `RoutineRepository` só tem implementação Development e
  Unavailable.

E um caso pior que o de Suporte: em `attendance` a camada de dados **existe em
Dart, está ligada, e chama funções que não existem no servidor**. As RPCs
`superadmin_attendance_*` não aparecem em nenhuma das 173 migrations vivas, só em
`.recovery-archives`. Só não quebra porque a rota está fechada.

## Decisões que dependem de você

1. **Goldens: são duas populações, não uma.** O censo mediu 49 suítes sobre
   `d784462c1`: 226 PASS, 6 SKIP, 151 FAIL em 27 features. Eu vinha tratando o
   conjunto como deriva de ambiente, e a medição de magnitude desmontou isso. Em
   28 comparações medidas, **21 estão acima de 8%, 12 acima de 15% e a maior é
   43,94%**; existe uma cauda de sete entre 0,16% e 4,08%, essa sim compatível
   com renderização de fonte. As duas populações pedem decisões diferentes: a
   cauda pequena é reaprovar referência; a grande **só pode ser mudança visual
   real nunca reaprovada**, e a decisão é descobrir o que mudou na tela e se
   aquilo foi aprovado alguma vez. Foi medida magnitude, não natureza — nenhuma
   imagem de diferença foi aberta. A consequência, se a leitura se confirmar, é
   maior que qualquer pendência do painel: o produto mudou de aparência sem
   passar por aprovação visual em algum ponto. Nenhuma imagem foi regravada fora
   do critério acordado.
1b. **Pinar o SDK antes de regravar qualquer golden.** Uma frente foi atrás da
   causa e eu confirmei por conta própria no código: as suítes de golden carregam
   `MaterialIcons` do SDK **local**, por caminho relativo a
   `Platform.resolvedExecutable`, enquanto a Nunito Sans vem do repositório. E o
   `pubspec.yaml` declara só um piso, `flutter: ">=3.38.0"`, sem `.fvmrc`, sem
   `.flutter-version` e sem nenhum registro de qual SDK gravou as baselines. As
   referências estão presas a um SDK que o repositório não registra, então
   qualquer máquina em outro Flutter falha em bloco sem que feature nenhuma tenha
   causado nada. **Regravar sem pinar só transfere a deriva para a próxima
   máquina.** A ressalva do autor, que eu mantenho: vendorizar a fonte de ícones
   remove uma das duas variáveis, não as duas — o fantasma aparece também no
   texto em Nunito Sans, que já vem do repositório, então o rasterizador do
   engine também difere. Ambiente desta rodada: Flutter 3.44.2 stable, framework
   c9a6c48423, engine 04efd7c093, Dart 3.12.2, Windows.
2. **Baseline visual de `errors.409`**, que nunca existiu.
3. **Visibilidade do leitor Principal no Sobre.** Não existe token de leitura em
   `profiles.about.*`, apenas manage, publish e update_official_data.
4. **Contraste do chip DESTAQUE em Para Você:** 3,75:1 contra o mínimo AA de
   4,5:1 para 11 px. Corrigir altera composição aprovada e move 20 goldens.
5. **Contrato visual de Editar perfil.**
6. **Contrato de UX de Lançamentos** (`daily-routine.publish`): o comando existe,
   a tela não, e a spec 021 não cobre Lançamentos.
7. **Rota Testar de Formulários** como superfície de leitura autorizada: hoje é
   mantida sem leitura por um contrato de teste verde e deliberado.
8. **Navegação no editor de Rotina:** habilitar a guarda de saída pela barra
   lateral faz o shell desenhar sua navegação e move seis goldens. É decisão
   visual, não de fiação.
9. **Suporte entra no MVP?** Hoje não existe backend nenhum.
10. **Preflight de leitura em produção** para confirmar se as RPCs internas
    existem. A baseline `20260901101500` insere permissão sem os rótulos que
    passaram a ser NOT NULL: ou ela nunca aplicou, e o realm interno inteiro
    falha fechado contra gateway inexistente, ou alguém a ajustou fora do
    repositório. Não é distinguível sem acesso de leitura autorizado.
11. **Autorizações remotas nominais** para os pacotes preparados nesta rodada.

## Pacotes remotos preparados e não aplicados

Ver [fila SQL serializada](NOTURNA-fila-sql-serializada.md), com a ordem
atribuída, os carimbos originais que os manifests dos grupos ainda citam, e o
hash que prova que só o nome mudou.

## Achados transversais distribuídos

- **Idempotência de escrita:** 13 sítios geram a chave inline, então o cliente
  perde a capacidade de repetir a mesma intenção. Publicação e criação são os
  casos graves, porque não há revisão esperada barrando a repetição.
- **Catálogo:** 16 divergências, contra 14 registradas. A ferramenta usa o mesmo
  caminho como entrada e saída, então regenerar o relatório versionado não
  subnotifica: **apaga o aviso** e deixa o catálogo verde no app com as 16
  divergências intactas no código.
- **Badge de não lidas:** medido, sem efeito observável em nenhuma rota de
  produção. Sai da fila um refactor de 44 arquivos.
- **Captura estreita de exceções:** repositórios que só capturavam
  `PostgrestException` deixavam falha de transporte escapar crua até a UI.
- **Guarda de mutação:** o risco real não é a chamada sem argumento, é alguém
  **adicionar** um ramo `/attendance` por simetria com invites, notices e
  circulars. O repositório injetado é real, então o ramo abriria as rotas contra
  RPCs que não existem.

## Duas decisões de componente e uma de segurança

**Tabela administrativa redimensionável.** O `SingleChildScrollView` de
`CoeloAdminResizableTable._tableBody` rola apenas na horizontal, então a coluna
que empilha cabeçalho e linhas não tem para onde rolar na vertical. A aritmética
fecha exatamente com o overflow relatado: 56 de cabeçalho mais 25 linhas de 65
dá 1681, contra 612 de altura disponível, o que produz os 1069 pixels. **As
linhas abaixo do corte não estão clipadas, estão inalcançáveis.** Não corrigi e
proibi a alternativa barata de limitar as linhas da tela de Importações: fechar a
suíte escondendo um defeito de acessibilidade real seria pior que a suíte
vermelha. A correção verdadeira exige sincronizar dois eixos entre corpo e coluna
fixada num Stack com posicionamento absoluto, atinge todos os diretórios
administrativos e é autoridade de `coelo-ui`. É decisão sua.

**Exposição de bucket e chave (severidade baixa, mas contraria a ADR 0032).**
`public.authorize_circular_media_read` está no grant para `authenticated` e
devolve `bucket_id` e `object_key`. Precisa ser chamável pelo usuário porque a
Edge Function usa o cliente dele para autorizar antes de assinar. Não concede
acesso — o bucket é privado e sem assinatura nada se lê — mas a ADR 0032 diz
para nunca expor bucket, chave ou provedor ao cliente. A correção seria devolver
um identificador opaco, o que muda o contrato entre a RPC e a Edge Function e
entra na fila SQL com autorização nominal. Nada foi aplicado.

**Redação corrigida no rastreador.** O inventário registrava
`save_circular_response_draft`, `submit_circular_response` e `delete_circular`
como ausentes no gateway. É verdade para o gateway administrativo v2 e falso
para o caminho Principal: as nove RPCs que os repositórios do Principal chamam
estão definidas em `20260821190000_circulars_production.sql`, com `revoke all`
seguido de grant a `authenticated`, 28 funções `security definer` e 29 com
`search_path` vazio. Isso prova **definição local, não aplicação remota** — a
lacuna muda de redação, não de estado.

## Verificações positivas registradas

O registro do que **não** é problema evita que o próximo revisor gaste o mesmo
tempo:

- O `file_picker` com leitura de bytes reais existe no assistente de importação,
  o que pareceria contrariar a política de importação adiada. Não contraria: a
  rota só monta o assistente sob a guarda de capacidade e a composição produtiva
  injeta o repositório indisponível nos dois pontos. Fail-closed em duas camadas,
  e o picker só vive em `/dev`.
- Acontece e Agora foram verificados contra o mesmo padrão de perda que atingiu
  Momentos, e já têm embedded e mediaPicker convivendo.
- `attendance.correct` e `attendance.finish` não têm lacuna de cliente: o
  conflito de versão tem exceção tipada, tratamento e dois testes.

## Higiene e preservação

- Os 90 artefatos de WIP ignorados na raiz do checkout integrador estão
  preservados por caminho e SHA256 em [manifesto](NOTURNA-wip-raiz-manifest.txt).
  Nada foi apagado.
- Os PNGs sob `test/**/failures/` ficam fora do índice: são diffs regenerados a
  cada execução e, rastreados, fazem qualquer frente aparecer no fechamento com
  alterações que não são trabalho.

## O que ainda falta

Preenchido no fechamento, após o corte das 05:00.
