---
source: Owner; C0 UI normal; Supabase production; G3 attendance contract
status: verified
generated_at: 2026-09-12
---

# Assiduidade — marcação, conclusão e correção

apps/superadmin -> Acompanhamento -> Assiduidade -> chamada ->
attendance.mark, attendance.finish, attendance.correct.

C0 abriu Nova chamada pelo dashboard produtivo e criou a chamada sintética
0757355f-ded6-41ab-b218-4924c09393b0 para 12/09/2026 no contexto retido
QA R04 Cuidado / Unidade QA R04 / Turma QA R04 Estrutura (editada).
Uma criança sintética existente, sem criar pessoa nem vínculo novo.
Pela UI normal: Presente -> Salvar -> reload; Concluir -> reload;
Corrigir chamada -> Falta com motivo -> reload. As seis imagens attendance-
mark/finished/corrected registram os estados antes e depois do reload.
Autenticação normal já provada por G0/C0; nenhuma sessão injetada.

Leitura SQL independente em produção confirmou sessão status corrected,
versão4, instituição d0c40000-0000-4000-8000-000000000001,
unidade d0c40000-0000-4000-8000-000000000002,
grupo368a5cea-2bcf-4fa4-ad1f-18da58694551 e registro ativo
6937bcba-e920-46c3-8869-b908f66b4dfe com outcome absent.
Revisões confirmed (present) e corrected (present -> absent); motivo
confere exatamente com o sintético digitado na UI. Recursos preservados.

BE done anterior preservado, sem somar novamente: contrato
20260911220100_attendance_superadmin_contract_v1 e pgTAP141/141 registrados
no handoff G3 (comunicacao/formularios-cuidado-rotina.json), incluindo
gestor B negado ao marcar, corrigir, reabrir e acessar chamada A;
authorization_and_idempotency16/16 também já registrado.
51 corpos de funções atuais de Assiduidade conferidos iguais entre
produção e espelho (attendance-remote-functions.json e
attendance-function-parity.json). Não executada nova sessão real tenant B;
negativa reaproveitada da família, não inventada como nova prova UI.

Ao corrigir, a UI mantinha um draft local antigo e mostrava erroneamente
“Alteração de presença não salva.”. O teste reproduziu 1FAIL antes do ajuste.
didUpdateWidget sincroniza o estado autoritativo quando não há draft prévio,
quando a linha troca de participante ou quando é somente leitura; preserva
edição local de linha ainda gravável. Suíte atual:53PASS,0FAIL,0SKIP.
Análise dos dois arquivos:0 issues. Falha inicial de teste foi resolvida.

Owner apontou selo Falta desalinhado quando Salvar/Detalhes quebravam linha.
Aplicada coelo-ui: família administrativa, mesma composição, cores e tokens;
identidade e selo alinham à primeira linha de controles usando touchMin.
Mobile/texto200 mantém empilhamento. Teste responsivo focal PASS em
375/768/1024/1440 a200%, sobreposto aos53, não somado.
attendance-alignment-fixed.png mostra o build novo no Chrome existente.
Nenhuma aprovação visual nova atribuída ao Owner.

Build release test_driver/qa_main.dart:60,5s, exit0; emulação de teclado e
arquivo sintético false. Tentativa inicial lib/qa_main.dart falhou por caminho
inexistente antes da compilação, corrigida. Aviso CupertinoIcons ausente no
dry-run mantido explícito; sem erro de compilação. Servidor C0 PID48684,
Chrome22592, aba829822468, localhost3014 contra Supabase real.
Não é deploy Cloudflare. Sem SQL novo, chave ou mídia criada nesta fatia.

Aceite FE e E2E das três ações recertifica a CallPage reconstruída em R07
por execução atual; não é apenas restauração documental do certificado R05.
Memória durável: correções restauram contrato já projetado em
docs/knowledge/team/superadmin-attendance-daily-routine.md; no-op de conteúdo.
Avatar fixo OC permanece pendência posterior C0/G7, conforme Owner.
