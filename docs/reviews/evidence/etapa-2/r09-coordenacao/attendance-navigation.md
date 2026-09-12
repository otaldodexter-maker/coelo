---
source: C0 runtime normal; G3 R08 implementation; approved attendance contract
status: local-green; ui-pending
generated_at: 2026-09-12
---

# Chamada — ligação da navegação produtiva

apps/superadmin -> Acompanhamento -> Assiduidade -> Nova chamada/abrir chamada
-> attendance.create, attendance.mark, attendance.correct, attendance.finish.

O painel real carregou métricas e uma chamada sintética concluída, mas não
permitia criar nem abrir a chamada: callbacks produtivos onCreate/onOpenCall
eram null. Menu attendance.create dependia somente de developmentPreview.
As rotas já compõem repository real, e as RPCs reautorizam ator, capacidade,
tenant, hierarquia e versão. A correção liga os callbacks e a entrada de menu
quando o repository está composto. Dashboard continua exigindo o
can_create_call do backend; o formulário exige canManage das opções reais.
Não injeta AttendancePermissions.owner/development na composição produtiva.

Teste de navegação pelo dashboard reproduziu a ausência do botão (RED1FAIL).
Após correção, suíte7casos:6PASS e1expectativa antiga falha; ajustada somente
a expectativa de ação agora ligada e rerun focal1PASS. Resultado único7PASS,
0FAIL vigente,0SKIP. Cobrem navegação dos botões, chamadas ao repository,
invalidação de autorização, preview separado e menu sem capacidade oculto.
Análise de router e teste: No issues found, exit0. Nenhum golden regravado.
Build QA da base conjunta em execução com ambas as emulações false.
Prova final UI/persistência/reload ainda necessária; nenhum novo percentual.

Memória: a projeção team/superadmin-attendance-daily-routine.md já descreve
Nova chamada no dashboard e autorização no servidor. Esta correção restaura
o contrato aprovado, não altera a regra de produto; projeção no-op.
