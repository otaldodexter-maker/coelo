---
title: "C04 — estado medido das 47 ações, segunda apuração"
source: "medição própria; substitui o retrato de 2026-09-08 19:30, que fica preservado"
status: "medido em 2026-09-09 02:00 -03:00"
generated_at: "2026-09-09T02:00:00-03:00"
timezone: "America/Sao_Paulo"
---

# Por que existe um segundo retrato

O primeiro tem carimbo de 08/09 19:30 e continua no lugar, porque um retrato
datado não se reescreve. Desde então publiquei vinte revisões de handoff e
**corrigi seis afirmações minhas** que estavam naquele documento. Deixar o leitor
reconciliar isso sozinho, atravessando vinte revisões, seria empurrar para a C00
um trabalho que é meu.

As correções, para quem só ler esta página:

| O que eu dizia | O que a medição mostrou |
|---|---|
| `institutions.edit` persiste "7 de ~45 campos" | **14 de 39 strings** chegam; 25 são descartadas, e **3** falham fechado |
| "sete RPCs de Unidade sem definição" | **quinze**, e nem todas são CRUD |
| `units.status` "não existe em lugar nenhum" | não há controle nem transição, mas o status **viaja no save genérico** |
| `institutions.locations-map` entregue | **parcial**: mesmo formulário bloqueado que fez `institutions.edit` ser parcial |
| `locations.list` "sem entrada no app" | **rota existe e alcança**; o que falta é link de superfície e integração da cadeia |
| `students.list` — cheguei a duvidar | **confirmado**: a lista vem da leitura CHILD real |

# Três avisos que mudam a leitura de tudo abaixo

1. **Bloqueio deliberado.** `structureMutationsEnabled` é `false` fixo
   (`superadmin_auth_scope.dart:313` e `:382`), com a razão no código citando
   **OQ-032/OQ-043**. Criar e editar Instituição, Unidade e Turma não são
   alcançáveis em produção — decisão registrada, não defeito. Medido depois: a
   flag guarda **quinze** chamadas sem função, não só o CRUD.
2. **Bloqueio na composição, antes da chamada.** Diretório de Unidades, diretório
   de Turmas e acompanhamento de Alunos recebem repositórios `Unavailable` em
   produção. As RPCs ausentes são a **causa** da recusa, não o ponto onde ela
   acontece.
3. **Goldens congeladas.** As 77 imagens de Estruturas já divergiam no baseline
   `479d1bd1`. A C07 rastreou até `d9232a94`. Onde digo "verde", quero dizer verde
   fora dessas imagens — mais **uma** que eu movi de propósito e declarei.

Legenda: **E** entregue e provado · **P** parcial · **B** bloqueado por decisão
registrada · **A** ausente · **D** adiado por decisão do Owner

# Instituições (13)

| action_id | Estado | Evidência |
|---|---|---|
| `institutions.list` | **E** | RPC existe e é chamada; paginação servidor-side testada. Corrigidos nesta rodada: teclado e seis colunas de métrica que eram hash do id. **Leitura permissiva**: campo novo do servidor é ignorado sem sinal |
| `institutions.filter` | **E** | `superadmin_institution_filter_options_v2` existe; filtros no `p_filters` |
| `institutions.detail` | **P** | RPC e tela existem e são testadas; **sem entrada em produção** — a única porta é `onEdit`, nulo atrás do portão. Leitura permissiva |
| `institutions.create` | **A** | O repositório lança antes de qualquer rede; nenhuma `superadmin_institution_create*` existe. Assistente de 7 passos sem backend |
| `institutions.edit` | **P** | **Perda medida com sentinelas**: das 39 strings que o registro carrega, **14 chegam**. Três falham fechado antes da rede (representantes legais, administradores, cor de superfície secundária). **25 são descartadas em silêncio**, entre elas contato, e-mail do titular, domínio, documento, slug e presença pública |
| `institutions.status` | **A** | Controle visível e desabilitado com a frase que explica; `status` não está na allowlist do servidor. **Cercado dos dois lados**: habilitar a UI produziria descarte silencioso |
| `institutions.files` | **D** | Botões visíveis e inertes, com cerca de fonte |
| `institutions.import` | **D** | idem |
| `institutions.export` | **D** | idem |
| `institutions.error` | **E** | Cada tipo de falha diz a frase certa; a mensagem do servidor não vaza; negação não oferece repetir |
| `institutions.access-denied` | **E** | Dirigido pelo repositório, com as palavras conferidas |
| `institutions.reload` | **E** | Prova contando leituras, não a existência do botão |
| `institutions.locations-map` | **P** | *Corrigido de E.* A seção está montada e composta, mas mora no formulário que o portão de mutação fecha. Mesmo critério de `institutions.edit`; não dá para aplicar dois |

# Unidades (12)

| action_id | Estado | Evidência |
|---|---|---|
| `units.list` | **B** | Bloqueado **na composição**: `UnavailableUnitDirectoryRepository`. Corrigidas nesta rodada: quatro colunas de métrica inventadas |
| `units.filter` | **B** | idem |
| `units.create` | **B** | `create_unit_for_superadmin` sem definição; `20260825180500:55` chega a **chamá-la sem defini-la** |
| `units.edit` | **B** | `update_unit_for_superadmin` idem. Corrigido: passo de gestão local não inventa mais linhas |
| `units.status` | **A** | *Corrigido.* Não há controle nem método de transição no gateway — **mas o status viaja em `unit_status` no save genérico**, para uma função que não existe aqui. Sem controle e sem destino, com caminho |
| `units.import` | **D** | Cercado; nenhum arquivo de produção compõe a implementação adiada |
| `units.export` | **D** | idem |
| `units.people-export` | **D** | Entregue: botão visível, inerte, com cerca |
| `units.error` | **E** | `unit-detail-unavailable` era chave de produção com zero cobertura |
| `units.access-denied` | **E** | Palavras conferidas; id malformado cai em negado de propósito |
| `units.reload` | **E** | Conta leituras; desabilitado enquanto uma está em voo |
| `units.copy-institution-location` | **E** | Trazer local da instituição para a unidade, com painel próprio; agora pede a capacidade `copy` e não "gestão" |
| `units.locations-map` | **P** | Leitura testada e **porta pronta na página** (`onOpenLocationCatalog`, botão e três testes); o router não passa o argumento |

**As quinze RPCs de Unidade sem definição**, medidas com a indireção `_request`
incluída: `create_unit_for_superadmin`, `get_unit_form_for_superadmin`,
`list_units_for_superadmin`, `unit_directory_filter_options`,
`update_unit_for_superadmin`, `change_unit_handle_for_superadmin`,
`request_unit_type_for_superadmin`,
`preview_unit_institution_transfer_for_superadmin`,
`transfer_unit_institution_for_superadmin`,
`superadmin_prepare_unit_identity_upload`,
`superadmin_finalize_unit_identity_upload`,
`superadmin_request_unit_identity_delete`,
`superadmin_confirm_unit_identity_delete`,
`superadmin_unit_identity_download_descriptor`,
`superadmin_unit_import_template`.

# Turmas (7)

| action_id | Estado | Evidência |
|---|---|---|
| `groups.list` | **B** | Bloqueado **na composição** (`UnavailableGroupDirectoryRepository`); as duas RPCs de Unidade que o contexto de filtro alcança são a causa |
| `groups.create` | **B** | `superadmin_group_save` existe e teve a **carga inteira medida** contra a allowlist de catorze chaves: chave a mais derruba o save completo |
| `groups.edit` | **B** | idem, mais `superadmin_group_get` |
| `groups.members` | **P** | Payload real dos dois lados, com o risco de esvaziamento silencioso fixado em teste: `local_people` substitui o conjunto, e um save sem membros pede para esvaziar o grupo |
| `groups.location` | **E** | O seletor descartava a escolha; o passo agora diz a verdade, cercado nos dois lados |
| `groups.import` | **D** | Cercado |
| `groups.export` | **D** | Cercado |

**Achado fixado**: `GroupDirectorySaveResult` transforma um único sim do servidor
em cinco. Etapa cujo pedido veio vazio responde "sucesso" com `skipped` sem uso
ao lado, e o relatório por etapa da tela é inalcançável porque falha chega como
exceção.

# Pessoas (5)

| action_id | Estado | Evidência |
|---|---|---|
| `people.list` | **P** | Busca, ordenação, paginação e sete filtros reais ponta a ponta. Atividade, UF, Município e Bairro **não têm parâmetro nem opção no servidor**, e estão cercados dos dois lados: preencher só as opções devolveria lista **sem filtro**, não vazia. Leitura permissiva |
| `people.create` | **B** | `superadmin_people_create_draft` existe e é testada; rota bloqueada |
| `people.edit` | **B** | `superadmin_people_update` existe; rota bloqueada |
| `people.links` | **P** | Escrita agora **medida contra a função**: allowlist, strip, tradução `remove`→`revoke` e `role`→`role_code`. **Achado**: a carga leva as duas listas e o servidor lê **uma**, escolhida pelo `person_type` gravado; a outra é descartada sem aviso e o save relata sucesso |
| `people.reload` | **E** | Prova de segunda leitura no detalhe; o diretório tem só "Tentar novamente" no estado de falha |

# Alunos (5)

| action_id | Estado | Evidência |
|---|---|---|
| `students.list` | **E** | *Reconfirmado.* A lista vem da leitura CHILD, composta de verdade em `main.dart:89`; o acompanhamento **abaixo** dela é que é fail-closed. Contrato CHILD medido contra a função e **íntegro nas duas pontas** |
| `students.link` | **A** | Cercado em dois níveis: o repositório declara duas leituras e nenhuma escrita, e a tela é conferida contra o vocabulário de gestão inteiro em todas as abas |
| `students.transfer` | **A** | idem |
| `students.edit` | **A** | idem |
| `students.revoke` | **A** | idem |

# Locais (4)

| action_id | Estado | Evidência |
|---|---|---|
| `locations.list` | **P** | *Corrigido.* A rota existe, está registrada e produção a alcança **nesta branch** desde `567b3993`; o reader real é composto. Falta **link** de qualquer superfície alcançável, e falta a cadeia ser integrada. Sem os filtros que a spec pede |
| `locations.create-edit` | **P** | Editar, status e duplicar entregues no cliente e na tela; **capacidades por ação** entregues, e concessão retirada recolhe a superfície que abriu. Falta endpoint aplicado |
| `locations.detail-links` | **A** | Ausente nos dois lados e **cercado**: o decodificador tem conjunto fechado, então adicionar vínculo no servidor recusa a carga inteira em vez de passar despercebido |
| `locations.schedule` | **P** | Disponibilidade semanal ponta a ponta no cliente, com capacidade própria. **Insuficiente para a spec de 02/09**; contrato mínimo de reservas publicado à parte |

# Duas gerações de decodificador

Medido entregando a cada leitura uma carga válida com uma chave a mais:

- **Recusam a carga inteira** (contratos v2): detalhe de Unidade, Locais, leitura
  CHILD, detalhe de Pessoa.
- **Ignoram sem uma palavra**: detalhe de Instituição, linha do diretório de
  Instituições, linha do diretório de Pessoas.

Consequência para a decisão 1: ampliar a edição de Instituição no servidor **não
chega sozinha à tela**, e nenhuma falha vai avisar.

# As treze decisões que destravam o resto

Publicadas nominalmente na revisão 47 do handoff, com desde quando esperam e o
que acontece se ninguém decidir. As de maior consequência:

1. **Lease nominal de banco** para replay dos três pacotes de Locais — SQL
   escrito, verificado em container descartável, **nunca aplicado**. Runbook
   pronto.
2. **Integrar a cadeia `023f19ea..567b3993`** e aplicar o patch de uma linha no
   detalhe de Unidade. São dois passos: a cadeia entrega o catálogo por URL, a
   linha entrega por navegação.
3. **`people.links`** — recusar no servidor a lista que não casa com o tipo
   gravado, ou o cliente enviar só uma.
4. **`institutions.edit`** — ampliar no servidor (e no decodificador de leitura),
   ou tirar da tela os 25 campos que não persistem.

# O que eu não fiz, e por quê

- **Não regenerei golden nenhuma.** Movi uma, de propósito, ao corrigir o retry
  no estado negado: 492 pixels de 337.500, 0,146%, região 96×14 no rodapé.
- **Não converti decodificador permissivo em estrito.** Sem o remoto não sei se
  as cargas reais carregam campos que o cliente ainda não lista; é decisão com
  risco, não acabamento.
- **Não construí as quatro ações de Alunos.** Estão ausentes por decisão de
  produto, e cerquei a ausência em vez de inventar superfície.
- **Não criei tipo de capacidade para Alunos.** Tipo que não guarda nada é
  andaime, e passei a rodada marcando andaime como problema.
- **Não executei SQL** desde a I009, nem em scratch.
- **Não editei o router**, que está sob reserva; o patch de uma linha está
  escrito no handoff, pronto para quem tiver a reserva.
