---
title: "Rotina diária — classificação de resultado filtrado e gate produtivo"
source: "apps/superadmin/lib/features/daily_routine/domain/routine_contract.dart"
status: "local-partial; integração bloqueada pelo contrato"
generated_at: "2026-09-07"
---

# daily-routine.list — fatia local

Quatro REDs: status/instituição/unidade/grupo, sem texto de busca, produziam
empty após resposta vazia. Controller agora considera todos os filtros já
existentes no contrato; nenhum filtro, tab ou capability novo foi exposto na UI.
Busca e filtros em branco continuam empty. Query e chamada ao repository intactas.

10/10 testes focados passaram; analyzer focado limpo e review independente sem
achados. Suíte do domínio anterior ao último controle de campos em branco:
46 passaram, 6 casos de golden falharam, 4 skips já presentes. Não atualizados
os baselines; não declarar suíte completa verde nem E2E. Memória no-op.

## Gate produtivo identificado

Composição ainda usa UnavailableRoutineRepository; adapter Supabase não existe.
Proveniência histórica read-only: criação62364121fed4e770b4ac69c6a76c8d024240eb3e;
remoção de nove migrations em f71b6a9c52667e27238a307b4237c404aa26f700;
restauração parcial de testes b20a9c20 sem a base.

Histórico: 20260811231000schema, 20260811231600commands,
20260811231700hierarchy e seis hardenings posteriores. Diretório retorna
items/total_count, mas ator é current_person_id com autorização people-based.
Isso não comprova equivalência ao realm interno atual. Nenhuma migration
restaurada, nenhum gateway inventado ou composition root liberado.
Reserva LOCAL R01 solicitada ao Coordenador para desenho/crosswalk/teste nominal.
BD nenhum nesta fatia; persistência, produção e gates E2E permanecem abertos.
