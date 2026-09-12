---
source: G1 UI R09; C0 API normal; pgTAP R04/R06; ADR0034
status: verified-e2e
generated_at: 2026-09-12
---

# Aceite groups.location — C0 revisão104

apps/superadmin -> Estrutura -> Turmas -> Criar -> Vínculos e aparência -> groups.location.

G1 criou pela UI normal a Turma1043c165-7f24-44fe-a868-5bfc6fb0b50f,
salvou Ativo v2 e confirmou Locald5461295-9273-4caa-9197-8f9d8c05c4f8
na Unidadef5284f2f da Escola190dd028. Reabertura pelo card da lista,
detalhe normal e reload conservaram a hierarquia e seleção. Evidências:
`../r09-estrutura-20260912-1542/location-ui-proof.md` e capturas ali citadas.
Build integrado, repository produtivo, Supabase real; sem mock ou sessão injetada.

C0 completou a negativa real em `group-location-negative.json`: Auth normal,
seleção retida legível, leitura anônima401, criação com LocalA e instituição/
unidadeB existentes recusada `SAI_PERMISSION_DENIED`, logout da própria sessão204.
Cinco checks PASS; três de domínio, dois de autenticação. SQL read-only confirmou
zero grupos com nome do teste negativo e recurso positivo intacto Ativo v2.
Request2144cba5-6a26-482e-aa4f-d09e7bc3f88c. Não criou novo vínculo/grupo.

A prova de ator escopado a outro tenant é reutilizada do pgTAP46/46 da mesma
família, registrado em R04 e na regressão R06
`../r06-realm-interno/regressao-pgtap-2026-09-11.md`.
O caso foreign_create nega atorB em payloadA/localA e verifica zero inserções;
outros casos negam unidade cruzada, capacidade ausente, revogação e expiração.
Não houve nova sessão real escopada a B neste probe (registrado false).
Corpos atuais idênticos no espelho/produção: create MD5
8b15b85a8b4fd817106538e2cbfa6687 e selection c57f9d7bbc438d55f1f9c8cecbd44427.
Não repetimos os testes verdes sem mudança pertinente.

Aceite MVP composto: FE verified, BE done, E2E verified-e2e para Local.
Não certifica Membros, edição arbitrária do Local nem reserva de agenda.
Turma e Local sintéticos preservados; nenhuma chave criada, SQL ou deploy novo.
