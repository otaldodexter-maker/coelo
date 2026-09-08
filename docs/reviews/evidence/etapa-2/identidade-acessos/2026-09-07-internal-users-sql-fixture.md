---
title: "Identidade e Acessos — fixture nominal de usuários internos"
source: "Reserva focal do Coordenador em 2026-09-07; migration 20260901210000; revisão estática realm_audit"
status: "prepared-for-exclusive-eng1-replay; not-verified-e2e"
generated_at: "2026-09-07"
---

## Recorte e execução

Somente `superadmin_internal_users_directory_test.sql` foi alterado.
Migration/RPCs, grants, realms, convites e superfícies fora do Superadmin
permanecem inalterados. O pacote é Auth45 + migration 20260901210000,
conforme composição 46+2 e target 20260901210000 informados pelo Coordenador.
Docker, replay e eventual execução remota pertencem exclusivamente ao Eng1;
esta frente não executou SQL nem realizou escrita remota.

IDs de roles são resolvidos na preparação privilegiada em GUC local antes de
`SET ROLE authenticated`. Todas as chamadas públicas continuam autenticadas;
as consultas de auditoria e snapshots privados ocorrem após `RESET ROLE`.
Não foi adicionado grant para fazer a fixture passar.

## Cobertura preparada

`plan(45)`: 29 verificações originais + 16 novas, contagem revisada estaticamente.

- Leitura AAL1 conforme exceção explícita do MVP.
- List/detail/profiles negados sem capability, com membership suspensa ou
  revogada, auth-link suspenso ou revogado, sessão removida e realm global.
- Atores ativos independentes e leituras positivas antes da invalidação do
  auth-link e antes da remoção da sessão, evitando negativos confundidos.
- Realm global com Auth, sessão e vínculo `people/person_auth_links` reais na
  fixture, sem inventar união com identidade interna.
- Revoke de alvo por RPC com versão lida, receipt idempotente, timestamps,
  auditoria única e nenhuma alteração após tentativa terminal de reativação.
- O envelope atual da tentativa terminal é `SAI_INTERNAL_ERROR` para SQLSTATE
  55000; o teste registra o contrato existente e verifica ausência de mutação,
  sem promover esse código genérico a contrato ideal.

O teste termina em `ROLLBACK`. Dados sintéticos ficam apenas no replay nominal.
Revisão estática sem bloqueios e `git diff --check` sem erros não substituem
resultado pgTAP. Os 45 testes **não estão declarados aprovados**.

## Proveniência

- Migration inalterada, SHA256 dos bytes locais:
  `b1f62d73704638c72f8230ae1457da7345842d5997cca075564a7ad67e999db7`.
- Mesma migration, UTF-8 com CRLF convertido explicitamente para LF:
  `c50fc78f0d17375eca835ac481454e29fdeefa487a693199a61b0cc69cd02247`.
- Teste preparado, UTF-8/LF:
  `f19fe5166dc9ba6405f5921d4a2406a645fb1209933fec4df432692558b4c8fa`.
- Teste preparado, SHA256 dos bytes locais antes do commit:
  `21c944bf77f3a06be3c330de5b1a94ba89d89726525c3ef12978092980233167`.

Documentação de referência: [testes de banco com pgTAP](https://supabase.com/docs/guides/database/testing).
O gate de memória não cria regra de produto nova: somente provas das regras
canônicas existentes e pendências técnicas próprias.

## Gates restantes

Replay exclusivo do Eng1, tratamento de falhas reais, prova PostgREST/cliente
com sessão válida e revogada, persistência/reload, auditoria e pacote remoto
nominal autorizado. A fixture não habilita edição produtiva ou convites e não
conclui Identidade e Acessos E2E.
