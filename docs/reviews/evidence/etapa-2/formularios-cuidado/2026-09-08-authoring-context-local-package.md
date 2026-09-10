---
title: "F-AUTHOR02 — cliente, contexto e catálogo nominal local"
source: "Contrato central 83c552 com aprovação posterior; F-AUTHOR01 2aa27b2; fontes e testes locais listados"
status: "local-verified-sql-prepared-not-executed-e2e-open"
generated_at: "2026-09-08"
---

# Entrega delimitada

Interface separada `FormsAuthoringApi`, adapter estrito e construtor
`FormsEditorPage.authoring`. Nenhuma rota/composição produtiva foi alterada.
Novo rascunho recebe UUID estável; candidato institucional usa páginas de até 20
por padrão, busca literal no servidor, seleção explícita ou única opção somente
na busca inicial vazia sem próxima página. Abrir existente chama apenas o
reader do formulário, com instituição vinculada e `capabilities.manage` efetivo.
Publicar/recorrência permanecem indisponíveis pela fatia, sem fabricar grants.

Read-only pode navegar seções; cards e filhos ficam expandidos para leitura,
sem liberar mutações. Ajuda já carregada também é exibida para perguntas comuns.
Negações ocultam corpo e navegação e invalidam edição. Revalidar acesso não perde
um comando cujo resultado é incerto nem reidrata os campos sobre edições locais
enquanto esse comando aguarda confirmação. Depois de criar, revalidação usa o ID
confirmado do formulário, não o catálogo de criação.

Save serializa somente a allowlist nominal: status e management_version não
entram no payload; expectedVersion vai no parâmetro próprio. Receipt deve ter
IDs correspondentes e versão expectedVersion+1, sem reload que substitua snapshot.
Retry mantém o comando original; edições posteriores continuam locais e recebem
feedback explícito. Descarte fica bloqueado enquanto o comando está incerto.
Troca de API/formId invalida callbacks e projeções do contexto anterior.

# Evidências do cliente

- Adapter: 35 testes; revisão identificou allowlist incompatível e versão de
  receipt não vinculada, reproduzidos em 3 RED antes da correção.
- UI nominal: 12 testes, incluindo 21 candidatos, seleção única/busca, contexto
  tardio, receipt tardio, negação/revalidação, retry/descarte e 375px a 200%.
- Regressão conjunta final: **198/198** em nove arquivos de teste de Formulários,
  incluindo os 35 do adapter e 12 da UI nominal. Exit 0.
- Analyzer dos cinco arquivos Dart alterados e validator visual canônico sem
  achados na execução registrada antes do handoff; não são prova visual E2E.
- Golden baselines preexistentes continuam abertos; nenhuma imagem atualizada
  e nenhuma alegação de equivalência pixel a pixel.

# Pacote SQL nominal separado

Migration: `packages/coelo_database/migrations/20260908032100_superadmin_forms_authoring_institution_context_v2.sql`.
Git blob: `309e2f2dae95a8dcf1eaf6b3a2dcf346c016bf0b`.

Fixture: `packages/coelo_database/supabase/tests/superadmin_forms_authoring_institution_context_v2_test.sql`.
Git blob: `81ac1e9cc9a1a4758e011409a590f64a4da423d1`.

Dependência obrigatória: closure F-AUTHOR01 completa e revisada, incluindo
reauth após espera e expiração com clock_timestamp. Pacote01 permanece intacto:
`20260908030000_superadmin_internal_form_drafts_v2.sql`, blob
`3c6fcfe072a38a35f79dad22c482c3ccc22794ad`.
Não substituir fontes históricas nem ignorar falha de preflight.

02 cria somente reader público/privado de candidatos e republica o corpo privado
do editor com nome institucional sob o mesmo lock e capability escolhida. Save,
receipts e helpers compartilhados não mudam. Catálogo active+notdeleted é snapshot;
não transfere regra active para leitura ou save existentes. Autorização vem do
contexto real, antes dos parâmetros e novamente após a query. Auditoria obrigatória
fora do catch; nenhum nome, busca, cursor, grafo ou People no log.

Fixtures próprias 8f032000, dois Owners, rollback final e RPCs sob authenticated.
<!-- Correção de 2026-09-10: o identificador 8f032000 acima NÃO resolve para
     nenhum objeto neste repositório. Verificado com `git cat-file -t` em
     todos os hashes citados pelo grupo: os outros quinze não-commit são
     blobs válidos; só este está ausente. Preservado no texto em vez de
     apagado, porque apagar esconderia que houve uma referência aqui; quem
     precisar das fixtures deve localizá-las pelo pacote, não por este hash. -->
Cobrem 20+1, cursor do último visível, empate por UUID, busca literal %/_/barra,
tipos/null/limites, manage-only sem platform.read/read, read-only sem catálogo,
escopo e cursor estrangeiro, inactive/deleted, sessão relógio real/NULL, revogação,
auditoria correlacionada por chamada, minimização/digest e falha de audit em
sucesso/negação/editor. Caso bytes é defesa redundante junto aos limites por
campo/allowlist; não prova isoladamente o ramo do teto de bytes.

**Nenhum SQL ou Docker foi executado por E2E 4.** Review independente estático
aprovou migration/fixtures, não execução. Eng1 continua executor exclusivo.
Repetir protocolo de duas conexões de F-AUTHOR01 no editor estendido para
revalidar bloqueio, revogação e expiração após espera; o nome deve vir da mesma
instituição bloqueada. Não promover catálogo snapshot a garantia permanente.

# Gates e memória

Replay SQL 02, concorrência executada, wiring aprovado, persistência real,
segurança integrada e E2E permanecem abertos. A confirmação central F-READ
117/117 em base derivada é evidência separada, não valida F-AUTHOR01/02.
Locais internos, Cuidado/saúde/medicação, Respostas e XLSX por formulário
permanecem no escopo original. Trackers/ledger são do Coordenador.

Contrato canônico da frente atualizado antes desta evidência. Não surgiu regra
de produto nova além do contrato aprovado; nenhuma projeção de conhecimento
foi criada somente para registrar atividade. Coelo UI orientou componentes,
leitura e estados; TDD/review exigiram negativos antes das correções.
