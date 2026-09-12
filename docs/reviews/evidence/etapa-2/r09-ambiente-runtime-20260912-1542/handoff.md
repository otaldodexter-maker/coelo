---
source: "Owner; coordenacao.json revisao 96; commit 7907453f0; build e CUA G0"
status: "runtime-gate-passed; espelho-em-medicao"
generated_at: "2026-09-12"
---

# G0 — E2-R09-20260912-1542

C0 unico: `01a096ed-314b-7c13-a9e0-3e64649e66fc`, host local.
G0: `01a096ed-88b6-79e3-a35c-3197d533b24d`. ACK C0 revisao96,
G0 revisao38 publicado em76e869f89. T0 novo15:42:18BRT; execucao19:42:18,
fechamento20:12:18, sujeitos ao primeiro corte de consumo/tempo.

Recorte: apps/superadmin -> Auth -> Login/entrada -> auth.login,
depois Estrutura -> Instituicoes -> leitura/reload como prova de runtime.
Nenhum novo aceite de produto ou delta de rastreador proposto.

## Runtime entregue 16:07 BRT

Fonte do build `76e869f89530ab4335a4a62360d80dd4cd97432f`, contendo
`7907453f0362665ab87fe8faaa4854f286904148`. Worktree e branch nominais
`e2-r09-ambiente-runtime-20260912-1542` / `work/etapa2-r09-ambiente-runtime-20260912-1542`.

Comandos no apps/superadmin: `flutter pub get --offline` exit0;
`flutter build web --release --no-pub -t test_driver/qa_main.dart --dart-define-from-file=.env.local --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=false`
exit0,88.3s. Uma chamada inicial de pub get na raiz falhou por diretorio sem
pubspec; corrigida a invocacao. Sem alteracao de dependencia ou feature.
Configuracao ignorada copiada do runtime anterior, apenas ambiente, URL e
chave publicavel. Build log preservado. Avisos de Wasm/fontes nao sao falhas.

Servidor Python existente do grupo PID7476/3014 foi medido e substituido
somente depois do build pronto por PID39504, em127.0.0.1:3014, usando
`docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/ferramentas/serve.py`
e `apps/superadmin/build/web` desta worktree. Comando: `python <serve.py>
<worktree>/apps/superadmin/build/web 3014 127.0.0.1`, Start-Process Hidden.
HTTP/login200, SHA256 local e servido de main.dart.js identicos:
`bb2932c37305649d953bad160e0081ed153499790b28450831054b0cf43ae305`.
Essas medidas de HTTP/hash apenas identificam o artefato.

Chrome raiz existente PID22592; browser CUA2; aba829822462 criada no mesmo
Chrome, pois nenhuma aba QA estava disponivel. Nenhum segundo Chrome.
Posse G0 medida antes do uso; agora slot liberado ao C0, aba preservada para
handoff e servidor mantido. Nenhum processo alheio encerrado.

Provas pelo canal CUA suportado, sem CDP alternativo/evaluate mutavel/Driver:

- `click(E-mail)`, `typeText(runtime-probe)`, `pressKey(Tab)`: texto visivel,
  screenshot `text-entry.png`. Primeira tentativa passou. A arvore AX nao
  inclui o valor digitado; screenshot confirma. Nao tratar omissao AX como
  controller vazio.
- Credencial QA autorizada lida do arquivo privado em memoria; E-mail e Senha
  preenchidos por teclado. Manter sessao aberta marcado; clique Entrar;
  Home aberta pela composicao normal (`login-home.png`). Sem sessao injetada,
  mudanca de senha ou gravacao da credencial no navegador.
- Menu Estrutura -> Instituicoes, clique pela UI: tres instituicoes de teste
  existentes renderizadas; pagina1de1 (`authorized-read.png`). Nenhuma escrita
  de produto foi feita.
- `reload()` em `/institutions`, acessibilidade reativada: mesma lista e
  contagens renderizadas; sessao preservada (`reload.png`).

RAM antes do build1,08GiB, minimo observado254MiB, apos build4,03GiB.
Nenhum flutter test iniciado. Build Dart PID41348 terminou; servidor segue.
Diagnostico anterior reutilizado; a mudanca nominal de emulacao do teclado
resolveu o probe pela mesma familia de canal suportado. Sem nova regra de
produto; memoria duravel no-op, fonte QA ja corrigida pelo C0.

Proximo gate: medir Docker/WSL e forma do espelho conforme ordem real ate59;
SQL/pgTAP novo somente sob posse nominal e candidato atribuido pelo C0.
