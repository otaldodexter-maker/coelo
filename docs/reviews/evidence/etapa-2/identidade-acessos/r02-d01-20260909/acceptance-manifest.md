---
title: "R02 D01 — campanha local de aceites Auth"
source: "R02-20260909/prompts/D01.md; handoff D01; logs da campanha e Git"
status: "in-progress; client-evidence-only"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Campanha R02 D01

Etapa 2 → apps/superadmin → Autenticação → Login / Recuperar senha /
Redefinir senha / Sair → `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`.
MFA permanece adiado pela ADR0019, fora dos quatro IDs ativos.

Base D00 `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`;
checkout D01 `C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d01-autenticacao`.
Ambiente local Windows, Flutter3.44.2/Dart3.12.2, execução Flutter serializada
dentro da frente D01. Registros de D00 na base integrada são recibos distintos;
não aumentam os testes únicos desta campanha.

## Plano e execução até 13:26 BRT

| Grupo de casos únicos | P | F | B | S | U | Recibo |
|---|---:|---:|---:|---:|---:|---|
| Recovery router,14 |14|0|0|0|0|`router-recovery.txt`, commit db1ade40|
| Login tela18 +goldens3 |21|0|0|0|0|`login.txt`, commit386ad474|
| OTP inválido/expirado/reutilizado simulado |3|0|0|0|0|`recovery-otp-negatives.txt`, commit953ce9d3|
| Teclado4 +reduced-motion1 |5|0|0|0|0|`keyboard-motion*.txt`, `header-motion-final.txt`, commit95da937e|
| Recuperar/Redefinir telas23 +goldens8 +responsivo30 |61|0|0|0|0|`recover-reset-client.txt`, commit6dfec55a|
| Persistência navegador e credencial inválida |0|0|4|0|0|Falha CUA descrita abaixo|
| Continuidade adapter2 +VM7 de Recuperar |9|0|0|0|0|`recover-adapter-viewmodel.txt`, exit0,4s|
| Composição SDK/callback/form/reset/logout |0|0|0|0|2|Novo teste focal em preparação|
| **Total do plano local119** |**113**|**0**|**4**|**0**|**2**|Sem somar reruns|

Resultado histórico de motion e erros iniciais de compilação do harness estão
preservados nos logs; asserções corrigidas e mesmo ID final PASS, sem somar
tentativas. As três falhas visuais anteriores de Login foram resolvidas por
geometria do componente. Os onze PNGs aprovados permanecem inalterados.
Executado113/119 neste checkpoint; bloqueados4 e não executados2 permanecem
explícitos. Estes números não são avanço FE/BE/E2E nem porcentagem de produto.
Taxa aprovada113/113=100%; falha0/113=0%; execução e aprovação do plano
113/119=94,96%. Os dois testes novos de composição ainda sem resultado
conclusivo permanecem U2; sua espera de fixture não foi classificada como
falha de produto.

## Browser: quatro casos bloqueados por ferramenta

Harness `apps/superadmin/test/manual/auth_session_persistence_harness.dart`,
SDK/storage/scope e rotas normais; apenas HTTP sintético. Debug obrigatório,
origem exata `http://127.0.0.1:8921`, sem fallback remoto e sem deploy.

Comando reproduzível a partir de `apps/superadmin`, porta exclusiva D01:

```powershell
rtk proxy flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 8921 -t test/manual/auth_session_persistence_harness.dart
```

Usar os valores sintéticos explícitos do arquivo; nunca credenciais reais.
Controle do navegador somente pela ferramenta CUA; encerrar o próprio runner
com `q` após a prova. Repetir os quatro casos só quando a falha de interação
tiver condição material nova ou no ambiente funcional da consolidação.

1. Credencial inválida deve permanecer em Login com erro seguro.
2. Login sem manter sessão deve voltar ao Login após reload completo.
3. Login mantendo sessão deve restaurar contexto após reload completo.
4. Logout normal seguido de reload deve permanecer sem sessão.

Login renderizou no Chrome, mas não houve entrada efetiva de texto. A primeira
tentativa terminou em timeout seguido de indisponibilidade Chrome. Após D00 r5
identificar a recuperação da disponibilidade, nova tentativa na mesma aba
829820109 teve CDP Input.dispatchMouseEvent timeout, fill sem alteração
confirmada por leitura do DOM, pressSequentially e reload com timeout.
Nenhum dos quatro casos chegou ao seu aceite. Os servidores próprios foram
encerrados; a segunda sessão37967 saiu0 com `q`, às13:10 BRT. Não acessamos
storage por caminho alternativo nem contamos tela aberta como teste aprovado.

## Verificações separadas do denominador de testes Auth

- Build normal `flutter build web --no-pub --release`: PASS322,9s, fonte
  produtiva HEAD6dfec55a; `release-build.txt`. Wasm dry run passou. Aviso de
  CupertinoIcons não empacotado permanece registrado; não foi falha de build.
  Artefato local não publicado e não comprova credenciais/configuração remota.
- Análise estática focal limpa; logs de teclado e header preservados.
- Gate global de contratos visuais: FAIL herdado em Locais, linha292 de
  `location_schedule_section.dart`, idêntico à base56eb3f19. Encaminhado a D00,
  nenhuma alteração de Locais/allowlist. Não invalida goldens Auth, mas impede
  alegação de gate global limpo.
- Preflight nominal: seis testes Node PASS, modo local PASS, GET settings real
  e SQL READ ONLY qualificados. Categoria ferramentas, fora dos119 acima.
- Memória: gate de validação PASS; suíte da ferramenta12PASS/1SKIP por symlink
  indisponível no host, fora do produto. Nenhuma regra durável aprovada nova.

## Limites de certificação

Reconciliação atualizada: **FE1/4 (25%), BE0/4 (0%), E2E0/4 (0%)** no recorte
D01, proposta ao escritor D00. `auth.recover` tem aceite FE verificado,
conforme `recover-fe-reconciliation.md`, após fechar adapter/VM9PASS;
ausência de SMTP não rebaixa essa camada. Login/Sair têm gates de browser,
e Redefinir tem a composição cliente acima ainda em execução. Esses números
não substituem inventário global datado nem provam integração/publicação.

Pacote remoto `D01-AUTH-PROOF-R02-v1` possui dez gates nominais A1/A2,
R1–R6,L1,C1: bloqueados para execução funcional por mailbox controlada e
autorização nominal ainda pendentes. São gates operacionais, não dez testes
automatizados e não entram no119. Nenhuma conta, senha, email, SMTP ou
configuração remota foi alterada. D00 serializa decisão e integração.
