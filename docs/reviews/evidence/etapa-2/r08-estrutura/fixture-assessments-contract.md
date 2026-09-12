---
fonte: apps/superadmin/lib/features/assessments e packages/coelo_database/supabase/tests/superadmin_assessments_internal_v2_test.sql
status: preparado
data: 2026-09-12
rodada: E2-R08-20260912
---

# Contrato mínimo de fixture — Avaliações (G1)

Destinatários: G5 (fixture), C0 (coordenação). Não aplicar SQL nem usar credenciais ou IDs reais neste artefato.

## Escopo que a fixture deve viabilizar

- `activities.assessment`: salvar e ativar configuração da atividade; a ativação deve tornar o período utilizável.
- `assessments.entry` e `assessments.gradebook`: abrir um diário para uma atribuição do contexto e encontrar uma linha de aluno.
- `assessments.close`, `assessments.reopen` e `assessments.detail`: operar o mesmo diário depois do lançamento.
- prova negativa: um ator/escopo de segunda instituição não pode salvar ou acessar a configuração/diário do primeiro escopo.

## Dados sintéticos mínimos

1. Instituição A, unidade ativa A, atividade da instituição A em `draft` ou `active`, e uma turma A vinculada à atividade.
2. Atribuição interna ativa que faça `superadmin_assessment_context_options` devolver essa combinação atividade–turma para o ator de teste.
3. Um aluno/contexto de criança sintético, ativo e membro da turma A; sem ele o diário abre sem linhas e não fecha o gate de lançamento.
4. Configuração avaliativa da própria instituição/unidade/atividade A, salva inicialmente em `draft`, contendo:
   - escala `numeric_0_10`, passo `0.5`;
   - exatamente um instrumento sintético, peso `100`, ordem `0`;
   - ao menos um período (máximo permitido: 12), com nome, ordinal, ano, início/fim, `entry_closes_at`, `family_release_at` e fuso `America/Sao_Paulo` válidos;
   - datas coerentes e período aberto no momento da prova após a ativação.
5. Instituição B sintética, separada, e ator apenas no seu escopo para a negativa de cross-tenant.

## Resultado esperado e limites

- Salvar retorna `draft`; ativar retorna `active`; o período passa a aparecer em `context_options` como `open`.
- A abertura/criação do diário usa a atribuição e o período e devolve a linha do aluno sintético; o reload conserva o estado salvo.
- A tentativa no escopo B é negada por autorização (`SAI_PERMISSION_DENIED` ou envelope equivalente), sem vazar dados de A.
- Preferir bloco transacional com rollback e nomes/UUIDs opacos de fixture. Não criar migration, não aplicar SQL, não expor dados reais nem segredos.
