---
source: "D01 feb3e3932 acceptance-manifest and browser B4; D00 AMR 9e7e23f18 and integrated focal manifests"
status: "frontend-accepted; backend-and-e2e-pending"
generated_at: "2026-09-09"
---

# Reconciliação Front-end de Autenticação

D00, 15:49 BRT: apps/superadmin → Autenticação → Login, Recuperar senha,
Redefinir senha e Sair. IDs canônicos: auth.login, auth.recover, auth.reset,
auth.logout. O inventario tambem possui account.logout fora deste recorte;
nao se unificam nem se certificam os dois IDs por esta prova. Referencias
historicas R01 que tratam auth.logout como shorthand precisam de reconciliacao
formal; o recorte R02 explicito prevalece nesta certificacao.

Aceite FE: 4/4. BE remoto: 0/4; E2E: 0/4. MFA continua adiado conforme ADR0019.
O aceite não representa implantação das migrations locais nem certificação
da sessão, SMTP ou revogação em produção.

Reutilizadas as provas válidas de layout/goldens, responsividade, teclado,
validação, adapter/ViewModel, estados seguros, scope e composição SDK/router
registradas no [manifesto D01](../identidade-acessos/r02-d01-20260909/acceptance-manifest.md).
Os critérios de Recuperar já estavam aceitos e permanecem preservados.

Login e Sair encerram o gate B4 com quatro casos observados no Chrome:
credencial inválida, persistência desativada e ativada após reload completo,
e logout confirmado seguido de reload. SDK/storage/scope/rotas são reais;
HTTP é sintético. Fonte e limitações no
[recibo B4](../identidade-acessos/r02-d01-20260909/browser-b4-static-receipt.md).
Não foi repetida a campanha apenas para somar testes.

Redefinir senha havia sido reaberto pela recuperação indevida de contexto
após falha de purge. Correções FE de serialização, confinamento e retry já
estavam integradas e verificadas. O gate restante passou com backend local
real: 36 TAP, 9 HTTP e 1 composição cold, incluindo auditoria minimizada,
recusa de recovery antes/depois de PUT, refresh, metadata mutável, logout e
novo login password. A composição recria SDK/scope e reabre /reset-password
com storage simulado que falha permanentemente ao apagar; o backend nega
contexto e o logout funciona. Isso não é um reinício real do processo nem
um reload de navegador desse cenário. Evidência e hashes no
[manifesto integrado](manifest-auth-boundary-second-integrated.json).

Essa prova resolve o gate específico que suspendeu o aceite FE anterior.
Os demais critérios FE preservados foram reconciliados; auth.reset volta a
verified somente nessa camada. O caso cold é um único ID lógico, compartilhado
com o plano D01 de 153 casos, e não deve ser somado novamente à união de testes.
Resultado D01 reconciliado: 153 P / 0 F / 0 B / 0 S / 0 U, com o último ID
provado por D00. O recibo autoral anterior 152 P / 1 F permanece histórico.

Inventário e três matrizes devem apontar este certificado, preservando BE/E2E
pendentes. Resultado global após esta reconciliação: FE 7/230, incluindo três
ações informativas adiadas e estas quatro ativas; BE 0/223 e E2E 0/198.
