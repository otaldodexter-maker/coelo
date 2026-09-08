---
title: "ROUTINE-READ01 — proposta de listagem pelo realm interno"
source: "apps/superadmin/lib/features/daily_routine/domain/routine_contract.dart"
status: "proposed; não implementado nem aprovado para deploy"
generated_at: "2026-09-07"
---

# Contrato da fatia

Reserva LOCAL E2E5-ROUTINE-READ01 concedida pelo Coordenador: desenho/crosswalk
e pgTAP proposto, somente leitura interna de Rotina no Superadmin. Não permite
restaurar migrations históricas, criar ponte People→interno, conectar composição,
liberar comandos ou executar remoto. Nenhum BD executado.

## Proveniência e divergência

Criação 62364121fed4e770b4ac69c6a76c8d024240eb3e; remoção
f71b6a9c52667e27238a307b4237c404aa26f700; testes parcialmente restaurados b20a9c20.
Fontes em packages/coelo_database/migrations no commit de criação:

| Fonte histórica | Papel | Tratamento proposto |
| --- | --- | --- |
| 20260811231000_daily_routine_schema.sql | modelos/versões/aplicações/lançamentos | Confirmar base autoritativa; não recriar catálogo paralelo |
| 20260811231600_daily_routine_commands.sql | require_routine_actor; RPC público | Não reutilizar ator current_person_id nem comandos |
| 20260811231700_daily_routine_hierarchy_hardening.sql | diretório privado, filtros e hierarquia | Reaproveitar somente requisitos de dados após crosswalk |
| Seis hardenings seguintes até20260812150100 | segurança, remapeamento, receipts | Inventariar dependência antes de qualquer reconstrução nominal |
| 20260825193112_final_review_daily_routine_lint_hardening.sql atual | refinamento dependente da base ausente | Não serve como fundação completa |

Histórico usa current_person_id/has_platform_permission/has_context_permission,
autor e auditoria person_id. Realm interno atual exige identidade, auth-link,
membership, sessão, capability e escopo internos reais. Uma pessoa familiar ou
metadado de usuário não pode ser convertido em ator interno por fallback.

## Reader proposto — depende de review nominal

Nome candidato `public.superadmin_routine_directory_v2`, preservando os oito
argumentos tipados históricos: kind/search/status/institution/unit/group/limit/offset.
Não criar esse símbolo antes da confirmação da base e do contrato.

1. Validar sessão/identidade/membership/capability interna `routine.read` antes
   de consultar entidades. Reutilizar contexto interno canônico, sem trocar
   current_person_id global nem fabricar marcador de outro domínio.
2. Interseção entre escopo efetivo e filtros: plataforma/instituição autorizada;
   unidade/turma devem pertencer à instituição real. Filtro nunca concede acesso.
3. Kind model/application/launch conserva o contrato existente; nenhum novo tab
   ou filtro visual é exposto. Busca literal limitada; paginação limitada e ordem
   estável por lower(name),id. Confirmar limites no contrato nominal final.
4. Envelope coerente com gateways internos: ok/data/error. Projeção allowlist
   somente id/kind/name/status/version/origin_label/effective_label e escopo
   necessário, total_count/limit/offset. O cliente deriva página somente quando
   offset for compatível com seu tamanho de página; não assumir divisibilidade.
   Sem respostas infantis, vínculos pessoais,
   receipts, auth IDs, objetos ou URLs de mídia no diretório.
5. `can_manage=false` nesta fatia estritamente read-only. Não anunciar escrita
   porque o ator possui capability: comandos continuam indisponíveis até prova.
6. Reautorizar cada leitura; negar perfil expirado/revogado/people-only.
   Filtros fora do conjunto autorizado não podem retornar linhas; confirmar se
   preservam vazio histórico ou exigem erro nominal antes de fechar o contrato.
   Auditoria mínima de negativa pelo caminho interno canônico. Sem segredo/logPII.
7. SECURITY DEFINER apenas se necessário, search_path vazio, grants nominais,
   sem grants diretos de escrita. Não enfraquecer RLS para facilitar fixtures.

## Matriz pgTAP proposta

Fixtures sintéticas isoladas e rollback; invocações sob SET LOCAL ROLE
authenticated com current_user assert, executor somente para seed/auditoria.

- Catálogo/assinatura/owner/search_path/ACL, anon e service_role sem execute implícito.
- Positivo interno plataforma e reader institucional sem capacidades de escrita.
- Dois tenants, IDs adulterados, filtros instituição/unidade/turma cruzados.
- People-only, auth-link ausente/revogado, sessão expirada, membership revogado,
  capability deny e política AAL vigente (sem restaurar gate histórico por engano).
- Três kinds, campos reais, sem duplicação por joins, vazio/total/limit/offset,
  ordem estável e busca literal; JSON/tipos inválidos não ampliam consulta.
- Sem vazamento de respostas, dados infantis ou IDs internos; can_manage falso.
- Releitura após revogação e auditoria mínima. Sem efeitos de escrita de domínio.

Esqueleto de preflight em routine-read01-catalog.proposed.sql não executa
listagem nem substitui os testes comportamentais. Não está no runner/manifesto.
Busca literal, envelope ok/data/error e can_manage=false são propostas novas,
não comportamentos herdados ou decisões já aprovadas.

## Gate seguinte

Coordenador/Eng1 precisam confirmar a base nominal autoritativa e sua cadeia,
sem recuperar nove migrations em bloco. Só depois se fecham fixture/pgTAP RED,
migration forward-only, adapter e composição. Etapas posteriores incluem UI real,
persistência/reload, revogação, tenantA/B, produção nominal e cleanup. Nenhum
action_id promovido. Memória no-op: proposta técnica ainda não é regra aprovada.
