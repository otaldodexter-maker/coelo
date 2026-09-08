---
title: "E2E5 — regressão ampla do escopo original"
source: "testes Flutter locais em a5ad81d10954dde9d4c443fa5e0522835ec357c0"
status: "669 PASS; 1 runtime SKIP; integração real aberta"
generated_at: "2026-09-08"
---

## Rerun após 0b55e919

Em 2026-09-08, a seleção de **70 arquivos** do mesmo escopo terminou com
**711 PASS e 1 SKIP**, exit0, runner52s. Runtime A01 foi explicitamente
desabilitado (`COELO_A01_LOCAL_RUNTIME=0`), sem HTTP real. Esta rodada substitui
a contagem anterior para este HEAD; não somar execuções sobrepostas.

Uma tentativa anterior teve erro no seletor de separadores Windows, gerou lista
vazia e iniciou a suite geral sem filtro. Foi interrompida após detecção, com
resultado parcial não conclusivo (havia falha não diagnosticada fora da seleção
pretendida); não é evidência de regressão completa. O comando corrigido normaliza
caminhos e **recusa manifesto vazio antes de chamar Flutter**:

```powershell
$env:COELO_A01_LOCAL_RUNTIME = '0'
$taskTests = @(rg --files test/features -g '*test.dart' -g '!*golden*' | Where-Object { $_.Replace('\','/') -match '^test/features/(agenda|activities|attendance|daily_routine|assessments|plans|meal_plans|support|audit|catalog|errors)/' })
if ($taskTests.Count -eq 0) { throw 'Empty original-scope test manifest' }
rtk proxy flutter test --no-pub @taskTests
```

Sem rebaseline, mudanças de produção ou promoção de gate E2E nesta rodada.

# Resultado

**669 testes PASS, 1 SKIP, exit0**, em69arquivos selecionados. O runner
reportou51segundos. Nenhum arquivo de teste ou master foi alterado durante a
execução. Somente o plano documental estava modificado sobre o commit indicado.

Superfícies: Agenda/Eventos, Atividades, Assiduidade, Rotina diária, Avaliações,
Planos, Cardápios/modelos, Suporte, Auditoria, Catálogo e erros globais.
O caso SKIP é exatamente o runtime A01 candidato, explicitamente desativado.

Seleção a partir de apps/superadmin, no commit indicado:

```powershell
$env:COELO_A01_LOCAL_RUNTIME='0'
$taskTests = @(rg --files test/features -g '*test.dart' -g '!*golden*' |
  Where-Object {
    $_ -match 'test/features[\\/](agenda|activities|attendance|daily_routine|assessments|plans|meal_plans|support|audit|catalog|errors)[\\/]'
  })
rtk proxy flutter test --no-pub @taskTests
```

O filtro exclui arquivos com golden no nome; não afirma ausência de comparações
visuais internas aos demais testes. Masters antigos divergentes previamente
registrados não foram rebaselineados e não estão resolvidos por este resultado.
Os testes de router fora de test/features não integram esta contagem.

Mocks, DEV repositories e guards não comprovam persistência ou autorização
backend. Esta regressão não executou A01HTTP, SQL, Docker ou produção e não
promove qualquer tela a verified-e2e. As dependências nominais de backend e os
gates de decisões continuam registrados no plano por tela.
