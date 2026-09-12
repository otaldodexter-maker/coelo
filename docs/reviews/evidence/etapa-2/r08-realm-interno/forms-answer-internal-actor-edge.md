---
fonte: R08 G5; form-media; recibos G0/C0
status: em revisão antes do deploy
generated_at: 2026-09-12T13:31:41-03:00
---

# Answer-image: ator do realm interno na Edge

## Defeito medido

O smoke normal API autenticou a identidade interna e passou por
`form_get_occurrence_for_response` e `form_open_response_draft`, mas a Edge
`form-media` v17 devolveu `401 unauthorized` antes de preparar o ativo. Nenhum
asset foi criado; o draft foi preservado.

O C0 confirmou `getUser` 200 e zero `person_auth_links` ativos para o usuário.
Esse é o estado canônico do realm interno, ligado por
`superadmin_internal_auth_links -> superadmin_internal_actor_people`. O código
da Edge só consultava `person_auth_links`, embora as RPCs de Forms já resolvessem
a mesma pessoa pela ponte interna.

## Correção focal

O resolvedor da Edge preserva a precedência de `person_auth_links`. Somente
quando a consulta passa sem erro e não encontra pessoa ele usa, com o JWT do
próprio usuário, `list_my_principal_contexts()`. Essa RPC existente resolve a
pessoa pelo helper canônico `person_id_for_auth_user(auth.uid())` e só projeta
memberships ativas.

O fallback aceita uma ou mais linhas somente quando todas contêm o mesmo UUID de
pessoa. Erro, resposta vazia, UUID inválido ou pessoas divergentes continuam
falhando com 401. O ID resolvido continua sendo passado ao autorizador existente;
ownership, autorização da participação e RPCs mutantes permanecem inalterados.

Limite: o fallback exige ao menos um contexto Principal ativo. Esta correção não
certifica atores internos sem contexto ativo nem altera o contrato desses atores.

## Testes locais executados por G5

- RED: ator interno sem `person_auth_links` devolveu 401 em vez de chegar ao
  prepare; a negativa também mostrou que o fallback ainda não era chamado.
- GREEN focal: 2/2 — contexto interno coerente passa; vazio/divergente nega.
- Regressão `form-media/index_test.ts`: 33/33.
- `deno check index.ts`: exit 0.
- `git diff --check`: exit 0.

Nenhum pgTAP, SQL remoto, deploy, Flutter ou Chrome foi executado por G5.
