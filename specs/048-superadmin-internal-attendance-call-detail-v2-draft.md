---
title: "Rascunho técnico — Assiduidade Call DETAIL/RELOAD CORE v2"
source: "decisions/0015-contextual-people-authorizations-attendance.md; decisions/0019-superadmin-internal-identity.md; specs/015-contextual-people-access-attendance.md; specs/038-attendance-responsive-dashboard.md; specs/039-superadmin-internal-auth-session-context.md; OQ-040"
status: "draft-for-review"
generated_at: "2026-08-28"
---

# Assiduidade — Call DETAIL/RELOAD CORE v2

## Status e limite

Este documento registra proveniência, riscos e alternativas para uma futura
leitura aditiva de uma chamada existente. Ele não aprova capability, matriz,
AAL, scope, shape final, migration, RPC, RED executável, cutover Flutter ou
alteração remota.

Até as decisões da OQ-040, RED e SQL permanecem bloqueados. Esta spec não
autoriza restaurar a cadeia histórica 20260811231000..20260812150100 nem o
dashboard local-only 20260825171221.

## Objetivo

Preparar detalhe e reload futuros de uma chamada para o principal interno da
spec 039, sem usar Pessoa como ator e sem misturar leitura com comandos de
presença oficial.

## Problema atual

A fundação física pertence ao realm global. Sua autorização usa
current_person_id(), memberships legadas, responsáveis e atribuições
profissionais. Isso não autoriza o Superadmin interno.

O Flutter produtivo injeta SupabaseAttendanceRepository. O dashboard chama
RPCs presentes somente numa migration local; o fluxo de chamada espera RPCs
removidas do HEAD e ausentes do remoto. A composição produtiva não comprova
funcionamento end-to-end.

## Proveniência

### Fundação canônica e remota

20260724152731_attendance_assiduity_foundation.sql:

- commit b6c4095a85ea454ee9febc61a9b8aac2862d46d2;
- blob 9539cb6a4fddd0d1d211497c2a95ef30ebdf07fe;
- SHA-256 D8F99E587330EB4EC8F30525097A25667CC593B0CB03722DC89B1CDF47269AE6;
- presente no ledger remoto consultado somente por leitura;
- cria sessões, participantes esperados, avisos, registros e revisões;
- autoriza pelo realm people-based e audit v1.

No snapshot remoto, as sete tabelas do domínio têm RLS habilitada sem FORCE e
grants diretos de leitura/escrita a `authenticated`. O helper privado
`can_access_attendance_child(..., require_manage)` aceita `platform.read`
antes de diferenciar leitura de gestão. Como essa capability possui grants
ativos para os cinco papéis de plataforma, a composição SQL atual autoriza
inclusive o ramo `require_manage=true` sem escopo institucional do ator.

Essa autorização alcança os wrappers públicos de confirmação/reversão e a
policy `ALL` de participantes esperados. Portanto há P0 de autorização SQL
cross-tenant por ID comprovado pelas definições, ACLs e policies. Nenhum DML,
RPC ou HTTP foi executado e nenhum incidente foi afirmado. Esta spec não
autoriza revogação nem correção remota; o hardening forward-only é pacote de
segurança anterior e separado do detalhe v2.

### Dashboard local-only

20260825171221_attendance_responsive_dashboard.sql:

- commit 7165762b6b3735bd35cb60f07d8774305ac61b11;
- blob b2719019232cf444c3e4acce0b96b5812a43b74c;
- SHA-256 E3A93182083FE3EE80A500D1FB91DBEB7195E9C01A6D239C3D5EB4F0DA9C1128;
- ausente do ledger remoto;
- usa current_person_id(), attendance.read/manage/export institucionais e
  audit v1.

Ela não pode servir de ponte do principal interno nem ser promovida para
resolver o detalhe.

### Cadeia histórica removida

As RPCs superadmin_attendance_* esperadas pelo Flutter aparecem somente numa
cadeia local/recovery de dez migrations entre 20260811231000 e
20260812150100. A cadeia mistura Rotina diária e Assiduidade, possui evoluções
múltiplas e continua people-based, com receipts actor_person_id e audit v1.

Não existe restauração isolada autorizada ou equivalência suficiente para
promovê-la.

## Escopo candidato

Somente após aprovação das decisões abertas:

- detalhe de chamada existente por UUID;
- reload da mesma chamada persistida;
- principal interno da spec 039;
- hierarquia derivada no backend;
- envelope seguro com status HTTP apenas semântico;
- negativa indistinguível para UUID ausente e fora do escopo;
- audit v2/v3 correlacionado e append fail-closed;
- wrapper opt-in authenticated e helpers privados.

## Fora de escopo

- dashboard, métricas, ranking, série, histórico, listagem e filtros;
- criar/iniciar, marcar, limpar, desfazer ou confirmar aviso;
- concluir, reabrir, corrigir, cancelar, excluir ou arquivar;
- exportar, agendar ou criar chamada futura;
- anexos de justificativa;
- Flutter, rota, E2E, cutover e revogação do legado;
- restauração histórica ou aplicação remota.

## Decisões abertas

### 1. Capability interna

Alternativas não aprovadas:

- capability de plataforma dedicada;
- platform.read somente neste wrapper, com allowlist separada;
- permanecer sem API interna.

As permissions institucionais attendance.read/manage não servem
automaticamente ao catálogo platform_permissions.

### 2. Matriz e AAL

É necessário selecionar papéis positivos, papéis negados e AAL mínimo. Owner,
Operations, Auditor, Support e Content permanecem sem decisão para esta
leitura. Owner continua AAL2 se for aprovado, mas isso não define a matriz.

### 3. Scope

Alternativas: platform-only; ou platform e institution, com
scope_institution_id derivado da membership interna e comparado à sessão.
Unit, group e activity enviados pelo cliente nunca ampliam o alcance.

### 4. Shape infantil minimizado

O DTO Flutter histórico não é contrato aprovado. O detalhe precisa decidir:

- metadados coarse: id, status, data, versão e timestamps;
- contexto coarse de instituição, unidade, grupo ou atividade;
- participantes minimizados, sem nascimento, contato, documento ou Auth ID;
- estado oficial e aviso familiar separados;
- capacidade coarse can_manage, se necessária.

Notas, justificativas, anexos e payloads brutos ficam omitidos. Nomes infantis
exigem decisão explícita de necessidade e minimização.

### 5. Compatibilidade e cutover

A futura RPC v2 será aditiva e não receberá nome legado por conveniência. O
cutover exige contrato Dart, regressão do dashboard/chamada e prova de que
nenhuma rota depende das RPCs people-based.

## Autorização candidata

Após decisão, o wrapper deverá:

1. validar auth.uid() e session_id em auth.sessions;
2. resolver link e membership internos ativos;
3. exigir role, permission e grant ativos, allow e não revogados;
4. validar AAL e scope aprovados;
5. consultar a chamada somente depois do contexto válido;
6. validar hierarquia e participantes no backend;
7. convergir ausente e cross-scope sem oracle;
8. nunca usar people, person_auth_links ou platform_memberships como
   autoridade do principal interno.

## Envelope e auditoria candidatos

- wrapper público SECURITY DEFINER, search_path vazio, VOLATILE;
- EXECUTE somente authenticated;
- helpers privados sem EXECUTE de clientes ou service_role;
- nenhuma auditoria antes da sessão Auth validada;
- audit v2 para ator completo e v3 para sessão sem vínculo;
- falha do append aborta;
- audit sem lista infantil, notas, justificativas ou anexos.

## Testes exigidos depois da aprovação

- papéis, AAL e scopes aprovados positivos e demais negativos;
- sessão ausente, divergente, expirada e revogada;
- link/membership/role/capability/grant inativos, revogados ou deny;
- UUID ausente/cross-scope indistinguíveis;
- cross-app, cross-tenant e hierarquia adulterada;
- shape exato sem PII proibida;
- aviso familiar separado do registro oficial;
- persistência e reload;
- audit v2/v3 1:1 e append adversarial;
- ACL, owner, SECURITY DEFINER, search_path e overloads;
- coexistência/regressão do legado e cleanup.

## Riscos

- presença infantil expõe rotina sensível;
- realm legado não pode virar ponte interna;
- grants/RLS exigem cutover coordenado;
- cadeia removida mistura domínios;
- detalhe sem minimização pode devolver dados excessivos;
- leitura sem versão não autoriza comandos concorrentes.

## Critério para sair de draft

A OQ-040 precisa aprovar capability, matriz/AAL, scope, shape infantil/DTO e
cutover. Somente então um RED poderá ser escrito e uma migration forward-only
proposta. Até lá, o estado é blocked-contract/provenance, sem local-green,
remoto, Flutter ou E2E.
