---
title: "D01 — recovery pré-reset obtém contexto backend no ambiente real local"
source: "local-auth-recovery-boundary.log; packages/coelo_database/scripts/Test-LocalAuthRecoveryBoundary.ps1; packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1"
status: "red-local"
generated_at: "2026-09-09"
---

Etapa 2 → apps/superadmin → Auth → Redefinir senha → sessão recovery antes
de trocar senha → `auth.reset`, dependência de `auth.login`/contexto protegido.

Uma execução focal real local, sem PUT de senha, demonstrou que o token de
recovery obtém `ok=true` e `platform.read` pelo bootstrap backend antes do reset.
O mesmo acontece após refresh dessa sessão. Este é um gate backend RED novo;
o PASS do lifecycle anterior continua válido apenas para seus asserts existentes.

| Gate único | Resultado | Contexto produtivo | AMR observado |
| --- | --- | --- | --- |
| password-control | PASS | true | password |
| recovery-before-reset | RED | true | otp |
| refreshed-recovery-before-reset | RED | true | otp |

Cobertura focal: 3/3 executados, 1 aprovado e 2 falhos, sem bloqueados/ignorados.
O runner é de observação: exit 0 significa execução e cleanup completos, não
aceite dos gates RED. Não houve rerun dos 30 pgTAP nem do lifecycle completo.
Replay das 47 migrations foi necessário para criar a nova base descartável.

Comando executado no checkout `e2-r02-d01-autenticacao`:

```powershell
rtk proxy powershell -NoProfile -File packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260901200206 -AuthOnly -RunAuthRecoveryBoundary *> docs/reviews/evidence/etapa-2/identidade-acessos/r02-d01-20260909/local-auth-recovery-boundary.log
```

CLI `2.116.0`; imagem Auth inspecionada:
`public.ecr.aws/supabase/gotrue:v2.196.0`. Projeto:
`coelo_safe_59cda9eaae8149868836b035bcb51`. Perfil `auth`, 45 migrations
canônicas + 2 preflights, adicionais 0, manifesto
`4279E67C9651F4049329591B6E8AAD82E3A9052506C1A4E16BA8BBB693249D59`.
Não foram registrados horários absolutos de início/fim ou duração total.

SHA-256 dos artefatos do discriminante (scripts históricos da execução;
log atualizado após normalização):

| Artefato | SHA-256 |
| --- | --- |
| local-auth-recovery-boundary.log, atual normalizado | `C1C32281F970960BFA191EBE1C1189088375FED95A1893046F686181AFCB82EB` |
| Test-LocalAuthRecoveryBoundary.ps1 | `102CE9371828E45E6ABFB915FECACA680152508A729AF284AEE0C17946CE3140` |
| Invoke-SafeLocalMigrationReplay.ps1 | `AD94F7C106052DC56356BB8F73EBE0099DD7FACF8DD26E8DDD9E4613B054ADE4` |
| Test-LocalAuthLifecycle.ps1, helpers importados sem executar corpo | `7EC1F6588A6F59303C0EF3876C313A54F4361C079D521DA377A7331E682C0AA3` |

Hash histórico do log da execução, conferido antes de normalizar:
`65B0BCCE91E488EC382692529D153509CD9318B86DC7CE0BF6282073991E12DB`.
Em 2026-09-09, o arquivo UTF-16 passou a UTF-8 sem BOM, LF e sem espaços
finais. Nenhum runner foi repetido e os resultados permaneceram intactos.

O wrapper recebeu somente um switch focal nominal, incompatível com
`RunAuthLifecycle` e dependente de `AuthOnly`. Ambas combinações inválidas
foram recusadas antes de inicializar Docker. Parse do script e `git diff --check`
passaram. Uma tentativa inicial de parser via comando PowerShell aninhado
falhou por quoting do comando, antes de executar arquivo; a verificação direta
do AST passou sem alterar o script.

Cleanup: wrapper informou zero resíduos e terminou exit 0; reconferência
somente leitura por nome exato do projeto retornou zero containers, volumes e
networks (três comandos exit 0); diretório temporário ausente. Nenhum remoto,
Owner real ou recurso de outra rodada foi alterado. Só um usuário synthetic
operations e os vínculos locais mínimos foram criados no volume descartável.
Não foram impressos tokens, senhas, links recovery ou emails.

O comportamento `otp` também corresponde à fonte primária
[GoTrue v2.196.0 verify.go](https://github.com/supabase/auth/blob/v2.196.0/internal/api/verify.go#L174),
que emite sessão implicit pelo método OTP. Isso não justifica aceitar recovery
no Coelo e não torna um marcador de frontend controle de autorização.
O guard canônico `20260901200206` não verifica AMR. Nenhuma correção de produto
ou migration foi feita neste pacote; o escritor central deve reconciliar o gate
backend RED nas matrizes/handoff, separado do avanço frontend.

Memória: no-op, pois diagnóstico e evidência não constituem decisão de produto
aprovada. Os `.log` são ignorados e precisam de inclusão explícita pelo integrador
se fizerem parte da entrega.

Revisão do log normalizado: 79 linhas, sem JWT/Bearer, credenciais atribuídas,
e-mails, CPF formatado ou links de recuperação. A leitura não encontrou dados
pessoais nem valores de tokens/senhas; ficam somente identificadores da base
descartável, nomes de migrations, versões e resultados minimizados.
