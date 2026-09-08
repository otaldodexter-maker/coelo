---
title: "F-AUTHOR03-SAFE — candidato de proveniência e alvo de distribuição"
source: "Reserva explícita do Coordenador em 2026-09-08; migrations históricas 20260901194209 e 20260813155126; crosswalk 8cde3915"
status: "candidate-statically-reviewed-sql-not-executed"
generated_at: "2026-09-08"
---

# Recorte e resultado preparado

Nova migration nominal `20260908054000_forms_internal_provenance_guards.sql`,
numeração reservada centralmente e conferida sem colisão nesta worktree.
Pré-requisito F-AUTHOR01: coluna interna e XOR/FKs já existentes.

Exatamente dois corpos existentes:

1. `app_private.form_assert_distribution_target(uuid,uuid,uuid)` remove somente
   `and form_record.deleted_at is null`, pois a coluna não existe em Forms.
   Mantém pareamento formulário/instituição, `forms.manage`, escopo, mensagens,
   SQLSTATEs, assinatura, SECURITY DEFINER e search_path vazio.
2. `app_private.block_published_form_definition_mutation()` usa IS DISTINCT FROM
   em created_by_person_id e created_by_internal_identity_id. Mantém todos os
   outros campos, transições válidas, timestamps e caminho das tabelas filhas.

Preflight exige executor postgres, ambas as funções e coluna de F-AUTHOR01.
CREATE OR REPLACE conserva identidade/owner/ACL. Nenhum grant, ALTER OWNER,
trigger, XOR, FK, writer People, wrapper ou endpoint novo é criado/modificado.

# Verificação estática realizada

Comparação automática dos statements contra as fontes históricas, normalizando
apenas CRLF/LF: G é exatamente a remoção de uma linha; trigger é exatamente a
substituição da comparação People e adição da comparação interna. Dois
statements CREATE OR REPLACE; zero ALTER/DROP/GRANT/REVOKE/CREATE TRIGGER.
Revisão independente read-only favorável do candidato e da fixture.
Diff check sem erros. **Nenhum SQL, parser de banco, Docker ou remoto executado.**

## Pins

| Artefato | Git blob |
| --- | --- |
| Nova migration 054000 | `7bc6778338ce19874c53add0c2e60fda231182ee` |
| `forms_internal_provenance_guards_test.sql` | `91c2a065e2264e0a91c6c6a0d0f0dba7439bd7ce` |
| F-AUTHOR01 migration, intocada | `3c6fcfe072a38a35f79dad22c482c3ccc22794ad` |
| F-AUTHOR02 migration, intocada | `309e2f2dae95a8dcf1eaf6b3a2dcf346c016bf0b` |
| F-AUTHOR02 fixture, intocada | `53f37358bd6ffd53fb69755ffd35b787b57c8a9a` |

SHA-256 dos bytes locais antes do handoff:

- migration: `5089edb9da4aa134b79e5ea31fc700cb67f41fd7daf1d39f7a3fd8c15d05ab75`;
- fixture: `51d853580dbb4e2b7d9fa140e61751dc49442dd5fd6b2c0cf42c3d31c538d63f`.

# Fixture preparada, não executada

`packages/coelo_database/supabase/tests/forms_internal_provenance_guards_test.sql`
usa somente dados sintéticos dentro de BEGIN/ROLLBACK. São 12 casos de transição
em formulários independentes, evitando colisão da unicidade de versão working:

- working→published e published→superseded;
- oito negativas: interno I1→I2, People P1→interno I1, interno I1→People P1 e
  People P1→P2, para cada transição;
- quatro controles: creator preservado em cada realm e transição.

Todos os creators/FKs existem e tanto o estado original quanto o alvo respeitam
XOR e timestamps. Negativas exigem exatamente 42501 e snapshot integral da
versão inalterado, incluindo estado, published_at e ambos os creators. Falha de
FK, CHECK ou estado inválido não pode mascarar o teste. Controles confirmam a
transição e proveniência preservada.

G tem positivo com People e membership institucional/allow forms.manage reais,
negativo por instituição divergente (22023) e por ator sem grant (42501).
Catálogo operations/forms.manage ativo e F-AUTHOR01 são pré-requisitos explícitos.
Há checks de existência/configuração e ACL dos helpers. Expectativa estática:
39 assertions via no_plan; contagem e execução devem ser confirmadas pelo Eng1.

São unidades diretas como postgres, **não** uma prova de autorização de wrapper,
sessão, publicação ou acesso People a conteúdo de autoria interna.

# Protocolo de execução exclusivo Eng1

1. Coordenador revisa manifesto fechado da base efetiva com F-AUTHOR01; não
   improvisar pontes nem executar contra base incompleta.
2. Na base anterior à 054000, rodar a fixture e preservar RED por coluna
   inexistente de G e trocas indevidas de creator, com controles válidos.
3. Capturar antes/depois os metadados das duas funções: OID, assinatura,
   proowner, proacl, prosecdef, proconfig, provolatile, proisstrict, proparallel,
   proargnames, proargtypes e prorettype. Eles devem permanecer iguais;
   apenas prosrc muda conforme o delta nominal.
4. Aplicar somente o candidato nominal, repetir fixture e regressões aprovadas.
   Registrar saída, SQLSTATE, contagem, identidade do runner e cleanup.
5. Divergência de base, owner/ACL, controls ou SQLSTATE exige revisão do pacote,
   nunca adaptação silenciosa. Root não executa nenhum desses passos.

# Gates que permanecem abertos

Publicação nominal e gestão pós-publicação dependem da decisão explícita do
Owner sobre realm People institucional versus endpoints internos. Este candidato
não responde essa pergunta. Remove_schedule não passa por G; diferença preservada.
F-AUTHOR01/02 e o restante do escopo continuam com seus gates independentes.

Gate de memória: restaura invariantes existentes, sem nova política de domínio;
nenhuma projeção criada para registrar atividade. Trackers/ledger são da
coordenação. Candidato preparado não é local-green, remoto-green ou E2E.
