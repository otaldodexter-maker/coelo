---
title: "D01 — interromper consultas ao sair da sessão autorizada"
source: "b58805ba; dependência E2E1 R03; NAV-LOGOUT01 c399e5ca; regressão local"
status: "local-green; not-verified-e2e"
generated_at: "2026-09-07"
---

# Recorte

Somente dois builders de detalhe Unit/Group e seus testes. Sessão, guard,
backend e demais rotas preservados. Complementa P1, não substitui R03.

## RED e causa

Regressão ampliada após R03+b588:129PASS/2FAIL. O teste existente exigia uma
consulta; logout800 efetuava duas. Ao receber revisão de invalidação, o builder
recriava a página e iniciava fetch antes do redirect. Reproduzido isoladamente
para Unit com expected1/actual2. Não se relaxou a expectativa.

## Correção e verificação

Builder retorna SizedBox.shrink quando sessão não autenticada ou em recovery.
Não inicia consulta nem retém payload. Sessão autenticada ainda recria página
por revisão e reautoriza leitura no repository/backend como antes.

- Oito testes novos: Unit/Group ×payload carregado/pendente ×logout/recovery,
  em1440. Sem nova consulta nem reaparecimento de payload tardio.
- Oito testes A→B anteriores preservados; suíte de autorização16GREEN.
- Testes de rota agora exercitam logout também1440, além de800.
  Dependem do NAV-LOGOUT01 para não travar no layout compartilhado.
- Regressão D01 completa:139GREEN (adapters, controllers, páginas, rotas,
  goldens, composição e autorização).
- Analyzer dos três arquivos: zero issues. Review estático independente:
  sem bloqueadores, sem editar ou executar Flutter em paralelo.

## Integração e limites

Aplicar após b58805ba, sobre R03 já integrado pelo Coordenador. Para suíte
desktop, incluir c399e5ca. Não integrar93df1044, cópia local dependency-only.
Nenhum baseline foi alterado. Nenhuma ação remota ou sessão real executada.
Permanece local-green, sem conclusão E2E. Memória: no-op, nenhuma regra nova.
