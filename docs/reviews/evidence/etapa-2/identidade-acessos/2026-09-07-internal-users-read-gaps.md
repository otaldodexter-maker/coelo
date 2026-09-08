---
title: "Usuários internos — gaps nominais do payload de leitura"
source: "Revisão estática root/realm_audit da migration 20260901210000; escopo original Identidade e Acessos"
status: "findings-awaiting-nominal-forward-fix; not-runtime-verified"
generated_at: "2026-09-07"
---

## Contrato deste registro

Somente evidência, separada da fixture nominal de 45 asserts. Não altera SQL,
RPC, grants, produção ou decisões de produto. Os achados foram enviados ao
Coordenador; nenhum teste RED destes dois casos foi executado nesta frente.

## Leitura minimizada incompleta

Em `packages/coelo_database/migrations/20260901210000_superadmin_internal_users_directory.sql`,
a projeção em linhas 131–133 mascara `identity.professional_email` quando
`p_include_sensitive=false`, mas a linha 178 inclui o mesmo endereço integral
em `invitation.email` incondicionalmente. A lista chama a projeção com `false`
(linha 369). Logo, o payload inteiro não preserva a minimização anunciada.

Critério para correção nominal: e-mail minimizado em todas as ramificações do
payload da lista; detalhe continua sujeito à autorização interna. O teste
deve verificar o JSON completo, não somente `professional_notes` ou um campo.

## Elegibilidade divergente entre lista e projeção

A CTE `filtered` (linhas 343–361) exige identidade, perfil e membership, mas
não auth-link. A projeção usa inner lateral join de auth-link (linhas 199–203).
Inferência do SQL: identidade com perfil/membership sem auth-link pode entrar
na paginação e no total, enquanto sua projeção retorna NULL, produzindo
`items:[null]`. Isso viola o formato de registros esperado pelo adapter Dart.

Critério para correção nominal: alinhar elegibilidade, total e paginação com
os requisitos da projeção, sem backfill ou criação de vínculo inventados.
O teste deve incluir registro parcial e comprovar ausência de itens nulos,
sem ocultar usuários completos permitidos ou introduzir vazamento de escopo.

## Fora destes dois achados

`invitation.status='accepted'` e `attempts=1` são derivados do auth-link na
projeção atual; isso não demonstra envio ou aceite de convite e não fecha
OQ-039. Versão de update/status e motivo de auditoria permanecem recortes
separados. Nenhum desses gaps autoriza habilitar mutações produtivas agora.

Não houve regra nova de produto para projetar em Knowledge. A fonte técnica
canônica permanece a migration, com eventual correção forward-only nominal.
