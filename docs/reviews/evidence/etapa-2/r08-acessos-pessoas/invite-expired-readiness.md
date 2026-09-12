---
source: "R08 G2"
status: "preparacao local; sem mutacao remota"
generated_at: "2026-09-12"
---

# Convite expirado — preparo de aceite

## Contrato confirmado

- leitura autorizada: `superadmin_invite_detail_v2(p_invite_id uuid)`;
- reenvio: `superadmin_invite_resend_v2(p_invite_id uuid, p_request_id uuid,
  p_expected_version bigint)`;
- o cliente permite reenvio quando o status e `expired` e envia a versao atual;
- o link so e consumido da resposta de reenvio, para copia unica, e nao deve ir
  para evidencias, JSON ou Git.

## Fixture reutilizavel

O contrato pgTAP de `superadmin_internal_invites_v2_test.sql` inclui a fixture
R08 de convite interno expirado, com request id sintetico terminado em `0603`.
Ela roda em transacao com rollback: prova novo estado `pending`, validade futura
e ausencia de link no recibo persistido, sem deixar convite ou link no banco.

## Sequencia quando o runtime liberar

1. Abrir o convite sintetico expirado pela rota normal e confirmar `expired`.
2. Acionar Reenviar uma vez, mantendo o link somente em memoria.
3. Confirmar recibo sanitizado, `pending` e validade futura; recarregar a rota.
4. Registrar apenas ids, status, versao e booleanos de autorizacao/releitura.
5. Se houver negativa de contexto ou erro transitivo, confirmar mensagem honesta
   e ausencia de link; nao tentar alterar SQL, status ou expiracao manualmente.
