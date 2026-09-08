---
title: "AG-READ01 — suplemento de busca e datas canônicas"
source: "reserva nominal do Coordenador; contrato fechado; migration 20260908045531"
status: "preparado e revisado; NÃO executado"
generated_at: "2026-09-08"
---

Arquivo separado:
`packages/coelo_database/supabase/tests/superadmin_agenda_read_v2_projection_supplement_test.sql`.
Não inclui nem altera a fixture congelada a3b/114. O GREEN54 dessa fixture não
deve ser usado como resultado deste suplemento.

- LF: 8511 bytes; SHA256 `089e2fd1179fb52f14cc3d7942fb4bf94ee9fe903b06e2c0ca606c417d8669c2`.
- CRLF: SHA256 `947297fe5dd5c70538381affc2d9eed7424b7ad3e4af7bc1b12d63fd2f3acdd0`.
- Prefixo sintético independente `8a510000`; ator interno039, sessão AAL1,
  membership institucional e role sintética com `agenda.read` somente.
- Autor People apenas para FK histórica, sem ponte de autenticação.
- Dois eventos no mesmo intervalo: marcador `%_\` apenas na descrição do
  primeiro, busca com espaços externos, busca só espaços e ausência literal.
- Recorrência usa datas armazenadas em formato PostgreSQL com `UTC` textual;
  list/get devem devolver JSON de timestamps canônicos. Compara JSON direto,
  não recast da resposta para timestamp, evitando falso positivo.
- Timezone da transação fixado em UTC para comparação determinística.
- Capturas reais sob `authenticated`; TAP após RESET ROLE; snapshot de eventos
  antes/depois; rollback final. Sem helper privilegiado substituído, trigger
  desativado ou grant de papel produtivo.

Review independente `activities_sql_review`: nenhum bloqueio estático.
Root não executou SQL, Docker ou HTTP real. Eng1 é o único operador serializado;
perfil, janela e replay deste arquivo exigem liberação nominal do Coordenador.
Nenhuma contagem PASS, GREEN ou conclusão E2E é atribuída nesta preparação.
O cliente local tem controle de parse das mesmas datas canônicas; isso não
substitui o replay PostgreSQL deste arquivo.
