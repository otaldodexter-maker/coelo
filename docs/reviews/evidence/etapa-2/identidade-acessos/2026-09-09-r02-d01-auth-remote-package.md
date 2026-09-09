---
title: "R02 D01 — pacote nominal de prova Auth"
source: "R02-20260909/prompts/D01.md; R02-20260909/CONTRATO.md; decisions/0019-superadmin-internal-identity.md; código Auth integrado"
status: "prepared; remote-authorization-and-controlled-mailbox-required; not-executed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Pacote D01-AUTH-PROOF-R02-v1

Etapa 2 → apps/superadmin → Auth → Login, Recuperar senha, Redefinir senha,
Sair → `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`.
Provedor: Supabase Auth/Postgres e SMTP configurado. Cloudflare não participa.
Nenhum envio, alteração de conta/senha, configuração remota ou teste remoto
foi executado na preparação deste documento.

## Base e limites

Base disponibilizada por D00: `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`.
Usar o SHA final integrado e registrar a revisão efetivamente testada.
Preservar R06/R07/I017, recovery confinado, single-flight e AAL1 da ADR0019;
não adicionar MFA ou usuários de Admin/Principal ao recorte.

O adapter já envia recuperação com redirect e atualiza a senha usando o token
da sessão de recovery capturado antes do await. Depois chama `signOut()`.
O gotrue 2.26.0 instalado define seu escopo padrão como `local`: a prova deve
medir a sessão encerrada, sem afirmar revogação global de outras sessões.
JWT antigo precisa ser negado pelo contexto/comando sensível que consulta
`auth.sessions`; a ausência do token no navegador, isoladamente, não basta.

## Pré-condições nominais ainda não preenchidas

D00 precisa registrar autorização vigente para este pacote exato, projeto
Supabase de produção identificado, SHA/build, janela e executor. A autorização
de Git da R02 não supre isso. Exigir persona interna sintética existente ou
provisionamento separado autorizado, IDs privados correlacionados, mailbox
controlada autorizada e responsável pelo cleanup. Não usar conta/senha do Owner,
email de terceiro ou endereço `example.invalid` para entrega real.

Conferir de forma sanitizada o provedor SMTP, origem HTTPS efetiva, allowlist
do redirect `/reset-password`, fluxo Auth e validade do link. O código constrói
o redirect a partir da origem do app em
`apps/superadmin/lib/core/config/superadmin_auth_scope.dart`.
Mudança de configuração não está incluída implicitamente neste pacote de prova;
se necessária, propor delta exato antes de aplicá-la. Nenhum token, senha,
cookie, URL de recovery ou credencial SMTP entra em Git, log ou screenshot.

## Recursos existentes reutilizáveis

- `packages/coelo_database/scripts/e2-r01-auth-personas.ts` exporta preparação
  de personas e exige snapshot/projeto/ownership; **não é CLI remoto pronto**.
  Seu pacote `C01-AUTH-PERSONAS-v1` e emails `example.invalid` não autorizam
  personas ou entrega SMTP para esta prova. Não alterar o pacote antigo para
  contornar essas restrições.
- `e2-r01-auth-personas-private.ts`, `e2-r01-auth-personas-local-sql.ts` e
  `e2-r01-auth-personas-ban-proof.ts`, no mesmo diretório, são peças existentes
  de vínculo/qualificação. I021/bridge continua dependência conforme tracker;
  não alegar que a mera presença desses arquivos qualifica produção.
- `packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql`
  contém negativas do contexto para reaproveitamento em ambiente local.
- `apps/superadmin/test/features/auth/domain/coelo_auth_recovery_sdk_test.dart`
  exercita SDK instalado com HTTP simulado. O delta D01 adiciona negativas
  inválido/expirado/reutilizado: nenhuma sessão de recovery, senha recusada,
  zero PUT/logout. Reutilizado consome o mesmo hash em outro cliente da fixture
  antes da negativa; validade e expiração são respostas simuladas, não relógio
  nem token real do provedor. Execução e resultado pertencem ao runner D01.

Comando local existente, a partir de `apps/superadmin`, somente pelo runner
serializado e quando houver causa de execução:

```powershell
rtk proxy flutter test --no-pub test/features/auth/domain/coelo_auth_recovery_sdk_test.dart
```

Não há neste pacote um comando remoto pronto que substitua autorização,
mailbox controlada ou o fluxo real na UI normal.

## Sequência e recibos exigidos

| Gate | Operação autorizada e aceite | Evidência sanitizada |
|---|---|---|
| A1 | Login normal da persona; senha inválida negada sem revelar cadastro; AAL1 aceito conforme contrato | SHA, rota, horário, estado UI e contexto interno |
| A2 | Manter sessão ligado/desligado; reload, restauração e expiração real | Estado esperado em cada cenário e leitura de contexto após restauração |
| R1 | Solicitar recuperação na UI; entregar email somente à mailbox autorizada; conferir destino normal `/reset-password` | Recibo de entrega sem conteúdo sensível; origem/path sem query/fragment |
| R2 | Link válido cria recovery e não libera shell/contexto produtivo | UI confinada, negativas de navegação e contexto |
| R3 | Link adulterado e link realmente expirado não permitem senha nem contexto | Resultado UI/provedor por caso; validade/horários sem token. Não reduzir TTL global para fabricar caso |
| R4 | Alterar senha da persona; mostrar sucesso somente após atualização e encerramento confirmado | Operação correlacionada, nova leitura; nenhum segredo |
| R5 | Reabrir link já consumido em sessão limpa; negar novo reset; voltar ao login | Negativa real e ausência de contexto produtivo |
| R6 | Senha anterior recusada; senha nova aceita; reload continua sob autorização interna | Resultado de login/contexto por tentativa |
| L1 | Logout pela UI; sessão encerrada; tentativa com sessão antiga negada no contexto/comando sensível; novo login permitido | Recibo Auth e negativa server-side correlacionados |
| C1 | Encerrar sessões de teste e executar somente cleanup nominal dos recursos criados pela prova | Ownership, recursos envolvidos, auditoria e confirmação; não remover trilha histórica |

Executar A/B e cross-realm com D04 somente se as personas/cenários já estiverem
autorizados; não criar perfis, vínculos ou fixtures remotas incidentalmente.
Não contar esse gate como aprovado com mocks ou teste SQL local.
Não repetir envio/reset automaticamente após resposta ambígua: confirmar estado
da própria persona, preservar auditoria e retomar somente passo necessário.

## Saída da prova e bloqueio

Registrar por action_id FE/BE/E2E e testes P/F/B/S/U, revisão, ambiente, horário,
resultado e cleanup. SMTP, token e senha reais permanecem bloqueados até
pré-condições preenchidas; provas locais não promovem BE `done` ou E2E.
Responsável por desbloqueio: D00 coordena pacote e autorização nominal;
executor D01 executa a prova no escopo concedido. Não há decisão de produto
nova a promover para Knowledge.

Referências oficiais consultadas em 2026-09-09:
[verificação OTP Dart](https://supabase.com/docs/reference/dart/auth-verifyotp) e
[códigos Auth](https://supabase.com/docs/guides/auth/debugging/error-codes).
O índice `https://supabase.com/changelog.md` foi solicitado, mas o leitor web
recusou seu content-type; isso não foi tratado como changelog verificado.
