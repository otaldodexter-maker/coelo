---
title: "D01 B4 — persistência e logout em navegador real"
source: "harness auth_session_persistence_harness.dart; build debug; CUA nesta sessão; assignment D00 r15"
status: "passed-local-synthetic-http; not-production-e2e"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Recibo B4 — 15:34–15:42 BRT

Etapa2 → apps/superadmin → Auth → Login / Sair → auth.login / auth.logout.
Quatro IDs já existentes no plano153, anteriormente bloqueados pela ferramenta.
Resultado final **P4/F0/B0/S0/U0**; nenhuma repetição é novo ID.

Base fonte: 71782a3cb na preparação do build (6318e04e3 foi commitado às15:24, durante a compilação); commits posteriores até368c0add1 alteram documentos/SQL, nenhum fonte Flutter do bundle. Flutter3.44.2/Dart3.12.2, Windows, Chrome extension browser1. Build debug estático181,5s/exit0 em browser-static-debug-build.txt; main.dart.js SHA256 F6D990FD4B720AE897787CC9D13D22F46222619158AD8447C1C81A8048E6C575. Revisão independente confirmou dart2js, assets locais e ausência de dependência DWDS. Isso qualificou a alternativa ao runner anterior, sem presumir resolução permanente da ferramenta.

D00 r15 liberou origem/runner. Porta8921 livre antes de iniciar. Servidor próprio session35959, Python http.server somente127.0.0.1, diretório apps/superadmin/build/d01-auth-browser-debug. Aba própria829820445, grupo D01 Auth B4. Não foram usadas abas alheias nem credenciais reais. SDK Supabase, ConditionalSupabaseLocalStorage, SharedPreferences web, scope e rotas normais reais; somente HTTP é sintético e confinado pelo harness. Sem /dev, SMTP, acesso remoto ou deploy.

| ID | Procedimento observado | Resultado |
| --- | --- | --- |
| B4-invalid-credentials | Email sintético do harness + senha errada; Entrar | Continuou #/login; mensagem visual e AX: “Não foi possível entrar. Verifique os dados e tente novamente.” |
| B4-persistence-off | Checkbox valor0; login válido; Home; tab.reload completo | Voltou #/login com formulário e checkbox0, sem contexto restaurado |
| B4-persistence-on | Novo login; checkbox valor1 conferido; Home; tab.reload completo | Home e menu autenticado restaurados sem preencher novamente credenciais |
| B4-logout-reload | Menu usuário → Sair → confirmação Sair; #/login; tab.reload completo | Continuou #/login, formulário vazio e checkbox0; não restaurou Home |

Evidência observada diretamente por CUA: snapshots AX e screenshots do formulário/erro/valores sintéticos, alternância de URL e árvores semânticas de Home/Login. Após cada reload, o botão Flutter Enable accessibility foi ativado por Enter para ler a nova árvore; isso não executa login nem altera storage. Não foi feita avaliação/mutação oculta de storage ou do estado Flutter. Este recibo transcreve observações; não afirma arquivo PNG salvo.

Ocorreram timeouts intermitentes Runtime.evaluate de locator.fill/check. As ações foram verificadas antes de prosseguir. Um setValue acessível retornou sem alterar o valor Dart: screenshot mostrou a senha sintética antiga; o preenchimento semanticamente suportado posterior alterou o valor, conferido visualmente antes do login. Isso foi limitação de interação, não falha de autenticação nem teste aprovado presumido. Favicon404 no servidor não afetou os casos; assets funcionais200/304.

Cleanup: após logout e verificação final, somente a aba própria foi fechada. Servidor35959 recebeu Ctrl+C e encerrou exit1 por interrupção intencional; não é falha de teste. Porta8921 verificada livre após encerramento. Nenhum dado/aba de terceiros removido. Build e fontes permanecem preservados; nenhum processo browser/server D01 necessário após este recibo.

Proposta de reconciliação D00: auth.login e auth.logout podem fechar o aceite FE dos critérios B4 junto às provas existentes; auth.recover já FE aceito; auth.reset ainda depende coldstorage+BE. Proposta FE3/4, BE0/4, E2E0/4. B4 não certifica provedor real, revogação remota ou SMTP.
