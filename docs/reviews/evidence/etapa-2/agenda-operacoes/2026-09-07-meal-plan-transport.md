---
title: "Cardápios — falha de transporte pelo contrato de domínio"
source: "apps/superadmin/lib/features/meal_plans/domain/meal_plan_repository.dart"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

Dois REDs reproduziram ClientException e TimeoutException escapando do adapter,
embora as telas consumam MealPlanRepositoryException. A RPC agora normaliza
Exception operacional para MealPlanUnavailableException com mensagem segura;
AuthException permanece Unauthorized. Mapeamentos PostgREST existentes intactos.
Não captura Error de programação, não muda parser nem adiciona retry automático.

29 regressões de dados/wizard/diretório verdes antes dos dois casos finais;
seis testes finais do adapter verdes, incluindo publicação com apenas uma chamada
após falha de transporte e AuthException. Analyzer limpo e review independente
sem bloqueios. Nenhum widget/golden/RPC/SQL/ambiente remoto alterado.

Comandos no cwd apps/superadmin: flutter test --no-pub
test/features/meal_plans/data
test/features/meal_plans/presentation/development_meal_plan_wizard_test.dart
test/features/meal_plans/presentation/meal_plan_directory_page_test.dart;
depois teste focado data/supabase_meal_plan_repository_test.dart.

Limite: falha de transporte após envio de comando pode ter resultado remoto
desconhecido; esta correção não afirma rollback nem repetição segura. Persistência,
autorização, mídia R2, publicação/reload reais e promoção E2E continuam pendentes.
Memória no-op: normaliza erro segundo contrato existente, sem nova regra de produto.
