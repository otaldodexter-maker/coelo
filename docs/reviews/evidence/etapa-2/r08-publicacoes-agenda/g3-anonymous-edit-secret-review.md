---
source: "C0 R08; commit 72e6e6f22; docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; docs/knowledge/team/superadmin-forms-production.md"
status: "reviewed-read-only; production-composition-pending"
generated_at: "2026-09-12"
---

# Revisão focal do segredo de edição anônima G3

Recorte somente leitura: pacote `72e6e6f22`, sem executar Flutter, alterar G3/C0
ou ampliar a revisão de segurança além da régua do MVP.

## Resultado

O store separa a capability por hash de projeto + conta + ocorrência. Instâncias
recriadas no mesmo runtime convergem pela chave completa, enquanto contextos de
projeto, conta ou ocorrência diferentes não reutilizam o segredo. A capability
aleatória não incorpora esses identificadores.

A página aguarda `setString` e a releitura confirmatória antes de chamar
`openResponseDraft`. A consulta autorizada da ocorrência acontece antes porque é
ela que informa se o modo é anônimo; ela não cria resposta nem recebe o segredo.
Não há abertura ou mutação anônima com fallback efêmero.

Trocas de API, ocorrência, sessão de mídia ou store incrementam a geração. O
resultado tardio do store, da consulta ou de comandos não atualiza o novo
contexto. Falhas de storage bloqueiam a abertura e oferecem nova carga; falhas
transitórias do comando mantêm o mesmo comando pendente, permitindo repetir o
`request_id` e o payload com o mesmo segredo.

## Achado de composição

O commit não liga o store à rota produtiva. Em
`apps/superadmin/lib/app/router/superadmin_router.dart`, a construção de
`FormResponsePage` passa API, ocorrência e mídia, mas não
`anonymousEditSecrets`. Portanto, no estado isolado do pacote, uma ocorrência
anônima termina na indisponibilidade honesta e `openResponseDraft` não é chamado.

Isso coincide com o limite declarado em `07-anonymous-edit.md`: C0 deve criar uma
instância estável fora de `build`, particionada pelo identificador canônico do
projeto e pelo usuário autenticado, substituí-la quando o contexto autenticado
mudar e passá-la à rota normal. O teste de composição precisa provar que a troca
de conta/store invalida a carga anterior. Não há justificativa para alterar o
algoritmo do pacote G3 para resolver esse wiring.

`FormsTestPage` em modo produtivo também não recebe o store, mas não substitui o
bloqueio da rota normal nem promove E2E.

## Veredito

- store e página: nenhum defeito concreto remanescente nos focos revisados;
- rota produtiva: wiring obrigatório ausente e já declarado pendente;
- testes executados nesta revisão: nenhum, por ordem nominal do C0;
- produção, SQL, deploy, Chrome e Flutter: não tocados.
