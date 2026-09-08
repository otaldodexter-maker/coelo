---
title: "Configurações — persistência local em navegador real"
source: "SuperadminApp e SharedPreferencesAsync reais; harness isolado; observação UI pela skill computer-use"
status: "browser-local-persistence-observed; full-e2e-open"
generated_at: "2026-09-07"
---

## Ambiente e limite

Harness `apps/superadmin/test/manual/settings_persistence_harness.dart`, sem
alterar main/router/shell. Usa SuperadminApp real com repository padrão
SharedPreferences e autorização sintética, sem cliente Supabase configurado.
Não é entrypoint de deploy nem prova de autenticação. Browser in-app Chromium,
origin exclusivo `http://127.0.0.1:8917`, rota normal `/#/settings` (não `/dev`).

Comando, a partir de `apps/superadmin`:

```powershell
rtk proxy flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8917 --target test/manual/settings_persistence_harness.dart
```

## Observação em 2026-09-08 01:20–01:23 UTC

1. Página normal carregou Configurações; semântica Flutter habilitada pelo
   botão de acessibilidade. Switch de redução de animações inicialmente 0.
2. Clique em Escuro aplicou tema escuro no app/shell e selecionou o segmento.
3. Clique em Reduzir animações mudou o switch para 1.
4. Reload completo da mesma URL destruiu a instância Dart anterior. Após
   nova inicialização, screenshot mostrou Escuro selecionado e tema escuro;
   árvore acessível mostrou novamente switch com valor 1.
5. Retorno a Sistema e redução desligada, seguido de outro reload: screenshot
   confirmou Sistema selecionado e switch desligado. Aba temporária fechada.
   Como stdin do processo estava fechado, foram identificados e encerrados
   somente servidor nominal 8917 e seus dois processos auxiliares; listener
   8917 ausente após encerramento. Nenhum outro Flutter/Docker foi encerrado.

Esta prova atravessa UI → controller → repository → armazenamento real do
navegador → nova montagem/UI. Não injeta memória, localStorage ou flags via
JavaScript. Não testa persistência de sessão, Auth, backend Conta ou R2.
Screenshots e estados acessíveis estão nos resultados desta tarefa; nenhum
dado pessoal real foi usado. Analyzer do harness sem diagnósticos.

## Gates preservados

Feedback de erros de leitura/gravação ainda não é tratado pela UI.
Não houve prova direta de MediaQuery.disableAnimations/precedência do sistema,
texto 200%, todos os tamanhos ou fluxo autenticado produtivo. Não declarar
Conta/Configurações integralmente verified-e2e com esta evidência.

Knowledge: comportamento durável já descrito na fonte canônica de
Perfil/Configurações; nenhuma decisão nova de produto.
