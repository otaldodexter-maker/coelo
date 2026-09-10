---
title: "O contrato RPC entre cliente e banco não é verificado por nenhum teste de tela"
knowledge_id: "client-database-rpc-contract"
source: "docs/reviews/etapa-2-operacao/reports/E2-noturna-contrato-rpc-20260910.md"
status: "draft"
generated_at: "2026-09-10"
updated_at: "2026-09-10"
audience: "team"
surfaces: [frontend, backend, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# O contrato RPC entre cliente e banco não é verificado por nenhum teste de tela

Todo teste de repositório dos apps privados usa cliente Supabase falso ou
intercepta o transporte. Isso é correto para testar mapeamento, erro e estado,
mas significa que **nenhum teste do app olha o outro lado do contrato**. Três
defeitos atravessam a suíte inteira sem deixar rastro:

1. a RPC chamada não existe no banco;
2. um parâmetro foi renomeado por uma migration posterior e o cliente continua
   enviando o nome antigo;
3. a função existe em duas formas e o cliente chama a antiga, perdendo a
   invariante que a nova introduziu.

Os dois primeiros só aparecem no primeiro uso real, como `PGRST202` ou
`undefined_function`. E aí vem a parte que torna a classe caríssima: no cliente
esse erro cai no mesmo `catch` de indisponibilidade que trata queda de rede, e a
tela mostra "tente novamente". **A própria UI disfarça o defeito de contrato de
falha transitória**, então ele pode sobreviver a várias rodadas de teste manual.
O terceiro é pior, porque nada falha: o banco aceita a chamada e a guarda
simplesmente nunca roda.

## Como verificar

A verificação é estática e não toca banco remoto. Compare, em um teste do
repositório:

- toda chamada `.rpc(...)` do app, com nome e chaves de primeiro nível quando o
  mapa de parâmetros é literal;
- toda `create [or replace] function` de `packages/coelo_database`, com nomes de
  parâmetros e quais têm `default`, ignorando `tests/`, porque pgTAP cria
  funções auxiliares que não fazem parte do contrato.

Três invariantes decorrem disso: a função existe; nenhuma chave enviada está
fora da assinatura; nenhum parâmetro obrigatório é omitido. O exemplo de
referência é `apps/superadmin/test/contracts/rpc_contract_test.dart`.

Duas decisões de desenho importam mais que a varredura:

**A omissão deve ser medida contra a interseção das sobrecargas, não contra uma
assinatura só.** Sobrecargas convivem no Postgres. Exigir a união acusaria
chamadas legítimas; exigir a interseção acusa exatamente quem não satisfaz forma
alguma. Em troca, o teste deixa de decidir *qual* sobrecarga o produto deveria
usar — e essa é uma decisão de produto, não uma invariante estática. Escolher a
forma correta pertence ao relatório e ao Owner; um teste que legislasse isso
estaria errado de princípio.

**A lista de ausências conhecidas tem de falhar nos dois sentidos.** Se a função
passar a existir e o nome continuar na lista, o teste precisa falhar também.
Sem isso a allowlist envelhece e passa a esconder o defeito seguinte, que é como
esse tipo de lista costuma morrer.

## Por que o achado não se resolve no cliente

Quando a medição acusa ausência de função, há duas leituras e elas pedem
decisões opostas: ou a função foi instalada em produção fora do versionamento, e
então **o pacote não descreve produção** e não existe o que revisar; ou ela não
existe, e a superfície falha fail-closed no primeiro uso. Não se decide entre as
duas a partir do repositório. Um `select` de catálogo resolve em segundos, e é
por isso que a pergunta pertence à próxima janela com autorização nominal — e
precisa ser respondida antes de promover a superfície afetada.

Quando a medição acusa uso de sobrecarga legada, a correção quase nunca é
local. Enviar um parâmetro de guarda que o domínio do cliente não possui obriga
a inventá-lo, normalmente lendo do próprio banco imediatamente antes da escrita
— o que reproduz exatamente a corrida que a guarda existe para fechar. A
correção honesta é o caminho de leitura passar a expor o valor que o usuário
viu, e isso é mudança de contrato de domínio.

## Sinal de que vale rodar a verificação

Desconfie sempre que uma migration do pacote **chamar** uma função que o pacote
não cria, ou quando o cabeçalho de uma migration mencionar reparo de função
"instalada localmente". Isso é drift declarado no próprio versionamento e
costuma vir acompanhado de mais ausências na mesma superfície.
