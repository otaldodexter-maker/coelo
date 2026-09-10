---
title: "Fila SQL serializada da rodada noturna 09→10/09/2026"
source: "Coordenação e Integração — Claude; candidatos publicados pelos grupos"
status: "active"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Fila SQL serializada

Nenhum destes pacotes foi aplicado em ambiente algum. Todos são **candidatos
locais revisáveis**. O projeto Supabase `coelo` é produção e o Owner ficou
indisponível a partir das 18:26 de 09/09, portanto nenhuma autorização nominal
pôde ser concedida nesta rodada.

## Colisão encontrada na integração

Três grupos, trabalhando em worktrees isoladas, escolheram independentemente o
mesmo carimbo `20260909190000`, e o grupo de Chat escolheu carimbos
(`20260909130000`, `20260909140000`) anteriores a cinco migrations que já
existiam na base. Worktrees separadas não impedem colisão lógica: a ordem da
fila é global e pertence ao integrador.

Ordenação atribuída por **ordem real de integração em `dev`**, forward-only,
depois da cauda existente `20260909174500_d04_access_models_scope_filter.sql`.
O conteúdo dos arquivos não foi tocado — o SHA256 é idêntico antes e depois do
renome.

| Ordem | Arquivo (nome final) | Carimbo original | Grupo | SHA256 |
| ---: | --- | --- | --- | --- |
| 1 | `20260909190000_superadmin_internal_audit_read_v2.sql` | `20260908230039`, já corrigido pelo autor | operacoes-sistema | `3a141214…1729b2` |
| 2 | `20260909191000_superadmin_internal_chat_receipts_edit_revoke_v2.sql` | `20260909130000` | chat-comunicacoes | `9ef0b1e9…e32e77` |
| 3 | `20260909191100_superadmin_notice_metrics_by_generation_v1.sql` | `20260909140000` | chat-comunicacoes | `a3652244…43e279` |
| 4 | `20260909192000_superadmin_location_consumer_bindings_v2.sql` | `20260909190000` | estrutura | `4c08a29e…c82ddd` |
| 5 | `20260909193000_d04_child_safety_internal_reads.sql` | `20260909190000` | acessos-pessoas | `601e7819…d302d8` |
| 6 | `20260909200000_superadmin_activity_location_create_v2.sql` | inalterado | estrutura | — |

Além destes, o pacote nominal de Modelos (`AP-MODELS-NOMINAL-20260909-v1`,
acessos-pessoas) e o candidato `get_profile_about` (perfil-para-voce) existem
como planos em `packages/coelo_database/plans/`, sem carimbo de migration.


## Segunda leva: candidatos L01 resgatados (09/09 21:25)

Seis candidatos de mídia estavam parados em `codex/e2-r02-l01-publicacoes`
enquanto três ações já integradas ficavam bloqueadas por RPCs que existem e
ninguém conseguia localizar — `list_visible_moments`, `withdraw_moment` e
`withdraw_happens_post` não aparecem em `dev` em lugar nenhum, só ali.

| Ordem | Arquivo (nome final) | Carimbo original |
| ---: | --- | --- |
| 7 | `20260909211000_now_publication_expiry_transition_v1.sql` | `20260909131000` |
| 8 | `20260909212000_circulars_media_private_r2_v1.sql` | `20260909132000` |
| 9 | `20260909213000_happens_post_withdrawal_v1.sql` | `20260909133000` |
| 10 | `20260909214000_happens_mixed_feed_withdrawal_v1.sql` | `20260909134000` |
| 11 | `20260909215000_private_media_catalog_chat_kind_v1.sql` | `20260909135000` |
| 12 | `20260909216000_moments_feed_and_withdrawal_v1.sql` | `20260909136000` |

Os testes pgTAP correspondentes vieram junto. A ordem relativa de L01 foi
preservada; só o prefixo mudou, para ficar depois da cauda `20260909210000`.

`20260909215000` toca o catálogo de mídia privada com um `kind` de chat, ou seja
encosta em `publicacoes-midia` e em `chat-comunicacoes` ao mesmo tempo. Nenhum
dos dois escreve esse objeto: a serialização é do coordenador.

Correção de registro: os candidatos vivem em `packages/coelo_database/migrations/`,
que é **rastreado** e tem mais de 180 arquivos em `dev`. A regra de ignore cobre
`packages/coelo_database/supabase/migrations/`. Eu havia registrado o contrário.

Novos candidatos, a partir daqui, usam carimbo posterior a `20260909216000`.


## Revisão dos seis candidatos L01 (09/09 21:35)

Revisão linha a linha em
`NOTURNA-revisao-candidatos-sql-publicacoes-midia.md`. Quatro passam limpos;
dois têm ressalva, e uma delas **bloqueia a aplicação**.

**Bloqueia — vazamento de existência em `20260909213000` (`withdraw_happens_post`).**
A função levanta `post_not_found` **antes** de qualquer verificação de ator: faz
o select, levanta se não achou, e só então chama `happens_actor` para comparar
autoria. Um ator autenticado distingue "existe mas não é seu" de "não existe",
inclusive para publicação de outro tenant. É oráculo de existência, e contraria a
invariante de não entregar informação antes da autorização. O padrão certo está
no arquivo irmão do mesmo autor: em `20260909216000`, `withdraw_moment` usa a
mesma mensagem para não-encontrado e para não-autor. Correção de uma linha.
Severidade prática baixa — exige autenticação e adivinhar um UUID v4 — e
severidade de invariante alta, porque é exatamente a distinção que
`circulars_production` mascara de propósito.

**Exige prova antes de aplicar — `20260909214000` sem suíte.** É o único dos seis
sem teste, e copia fielmente um corpo grande de função alterando o predicado de
retirada e dois campos do payload. Cópia fiel de corpo grande sem teste é onde a
divergência silenciosa mora, e essa função alimenta o feed misto de Acontece, que
já está integrado e em uso.

Três coisas que **pareciam** defeito e não são, registradas para ninguém gastar
tempo: `20260909214000` sem revoke/grant está correto, é `create or replace` de
assinatura inalterada; `20260909215000` sem grant está correto e documentado no
próprio arquivo; e `20260909216000` ter três `security definer` em quatro funções
está correto, porque a quarta é um predicado `sql immutable` em `app_private`
com `search_path` vazio e revoke de todos os papéis.

A revisão é estática: nenhuma suíte foi executada contra banco, nada foi
aplicado, nenhuma autorização nominal foi usada.


## ORDEM OBRIGATÓRIA: a trinca de Circulares não pode ser autorizada em partes

`20260909212000_circulars_media_private_r2_v1` faz mais do que expor
`storage_provider`: ele **muda o default da coluna para `r2`** e tira o default
de `bucket_id`. A partir do instante em que a migration é aplicada, todo ativo de
mídia de Circular novo nasce apontando para o R2, com bucket escolhido pelo MIME
e chave opaca versionada travada por CHECK. A topologia está correta e o
candidato está bem construído.

O risco é de **ordem**. Se a migration entrar antes de a Edge Function com o ramo
R2 estar implantada e o R2 configurado, a função que está em produção hoje recebe
um descritor cujo bucket é `coelo-media-prod` e tenta usá-lo no Supabase Storage,
onde esse bucket não existe. **Anexar arquivo em Circular passa a falhar para
todo mundo**, com modo de falha confuso: a tela reporta erro de assinatura ou de
upload incompleto, sem dizer que o destino mudou.

A ordem segura é a inversa, e os três passos são inseparáveis:

1. Configurar `COELO_R2_ENDPOINT`, `REGION`, `ACCESS_KEY_ID` e
   `SECRET_ACCESS_KEY` no ambiente da função, e garantir que
   `coelo-media-prod` e `coelo-documents-prod` existam.
2. Implantar a Edge Function `circular-media` com o ramo R2 — já integrada em
   código, não implantada.
3. Só então aplicar a migration.

**Autorizar apenas a migration cria o incidente.** A autorização nominal ao Owner
tem de pedir os três de uma vez.

Reduz o risco, e está correto no candidato: os dois CHECK novos entram como
`NOT VALID`, então as linhas existentes — que ficam com `supabase` — não são
revalidadas e o acervo antigo continua legível. O que quebra é a criação de
ativo novo, não a leitura do que já existe.

Correção de registro: o ramo R2 de `circular-media` **não** é código dormente,
diferente dos de Acontece e Agora. Aqui a RPC devolve `storage_provider` nos
cinco envelopes, então o código é a outra metade de um par que só falta ser
aplicado e implantado, junto e nessa ordem. Acontece e Agora continuam retidos
porque lá a migration ainda nem existe.

## Consequências registradas

- Manifests e handoffs dos grupos citam os carimbos **originais**. Esta tabela
  é o mapeamento autoritativo; o conteúdo verificado por hash é o mesmo.
- Renomear ordena a fila, mas **não** substitui o preflight contra o alvo real.
  Nenhum destes pacotes teve preflight executado contra produção.
- A verificação estática de pré-requisitos feita pelos autores permanece válida
  como evidência de revisão, não como prova de aplicabilidade.
