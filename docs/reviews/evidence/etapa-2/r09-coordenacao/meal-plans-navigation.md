---
source: C0 normal navigation; G4 productive routes; Owner R09
status: local-green
generated_at: 2026-09-12
---

# Cardápios — entrada produtiva

apps/superadmin -> Operação -> Cardápios -> meal-plans.list/create/edit/publish.
A rota produtiva já compõe MealPlanRepository e RPCs autorizadas; a entrada
do menu ainda estava marcada development-only, impedindo chegar pela UI normal.
Removida a restrição de ambiente apenas da entrada de Cardápios. Diretório
continua mostrando negação do servidor, sem entregar dados antes de autorização;
assistente deriva instituição/tenant autorizado e backend reautoriza escopo.
Não alterados grants, RLS, SQL, sessão nem composição de permissões.

Teste da disponibilidade produtiva reproduziu1FAIL. Depois do ajuste, os18
testes de navegação passaram. Os7 testes de ambiente/logout passaram após
migrar sua referência development-only para Planos: quatro falhas intermediárias
do finder contavam o próprio campo de busca; finder corrigido para Text do
destino, preservando asserções de listeners e troca de router.
Resultado único25PASS,0FAIL vigente,0SKIP. Análise dos3arquivos:0issues.
Build e prova CRUD em andamento; nenhum novo certificado ou percentual aqui.

Memória: alteração restaura a rota produtiva já definida; regra de produto
inalterada. Planos permanece conforme disponibilidade anterior, sem alteração.
