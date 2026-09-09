---
title: "R02 D01 — campanha local de aceites Auth"
source: "R02-20260909/prompts/D01.md; handoff D01; logs da campanha e Git"
status: "local-client-and-integrated-green; remote-pending"
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

## Plano e execução até 15:48 BRT

| Grupo de casos únicos | P | F | B | S | U | Recibo |
|---|---:|---:|---:|---:|---:|---|
| Recovery router,14 |14|0|0|0|0|`router-recovery.txt`, commit db1ade40|
| Login tela18 +goldens3 |21|0|0|0|0|`login.txt`, commit386ad474|
| OTP inválido/expirado/reutilizado simulado |3|0|0|0|0|`recovery-otp-negatives.txt`, commit953ce9d3|
| Teclado4 +reduced-motion1 |5|0|0|0|0|`keyboard-motion*.txt`, `header-motion-final.txt`, commit95da937e|
| Recuperar/Redefinir telas23 +goldens8 +responsivo30 |61|0|0|0|0|`recover-reset-client.txt`, commit6dfec55a|
| Persistência navegador e credencial inválida |4|0|0|0|0|`browser-b4-static-receipt.md`, CUA/Chrome real com HTTP sintético|
| Continuidade adapter2 +VM7 de Recuperar |9|0|0|0|0|`recover-adapter-viewmodel.txt`, exit0,4s|
| Composição SDK/callback/form/reset/logout |2|0|0|0|0|`recovery-composition-reconciliation.md`, dois IDs finais PASS|
| Demais casos SDK de recovery/scope, sem repetir as3 negativas OTP acima |18|0|0|0|0|`recovery-persistence-regression.txt` e `recovery-persistence-fixtures-green.txt`|
| Storage condicional: contrato existente |5|0|0|0|0|`recovery-persistence-regression.txt`|
| Cold reload SDK/storage, preferência ligada/desligada |2|0|0|0|0|`recovery-cold-storage-green.txt`|
| Corrida de escrita/remoção e recuperação após erro |2|0|0|0|0|`recovery-cold-storage-green.txt`|
| Gateway: replay/seed/erros síncrono e assíncrono de limpeza |5|0|0|0|0|`recovery-persistence-gateway-review.md` e logs referenciados|
| Retry após falha transitória de purge |1|0|0|0|0|`recovery-persistence-retry-green.txt`, novo ID apenas|
| Cold restart após falha de storage: confinamento cliente + servidor |1|0|0|0|0|`integrated-auth-boundary-46-pass.log`; SDK/scope/rota/RPC/logout reais, D00r18|
| **Total do plano local153** |**153**|**0**|**0**|**0**|**0**|Sem somar variantes/reruns|

Resultado histórico de motion e erros iniciais de compilação do harness estão
preservados nos logs; asserções corrigidas e mesmo ID final PASS, sem somar
tentativas. As três falhas visuais anteriores de Login foram resolvidas por
geometria do componente. Os onze PNGs aprovados permanecem inalterados.
Executado153/153 neste checkpoint; bloqueados0 e não executados0 permanecem
explícitos. Estes números não são avanço FE/BE/E2E nem porcentagem de produto.
Taxa aprovada153/153=100%; falha0/153=0%; execução do plano
153/153=100% e aprovação153/153=100%. A espera de fixture foi resolvida pelo ciclo assíncrono real
de criação/dispose do SDK; a expectativa incorreta de mensagem foi corrigida
para o feedback específico do contrato. Resultados intermediários estão
preservados e pertencem aos mesmos dois IDs finais verdes.

O RED novo de cold reload com persistência ligada e a corrida de escrita foram
resolvidos pela remoção serializada e recuperação somente em memória. A
regressão de28casos apresentou25PASS/3FAIL de fixture: inicializadores SDK
substituídos pelos testes não inicializavam o storage fornecido. Os seis casos
afetados pela correção das fixtures (quatro scope e dois composição) passaram;
os demais verdes não foram repetidos. Falhas iniciais nos predicados de dois
novos testes do gateway também foram corrigidas no teste. Não são falhas
atuais do produto nem casos adicionais. Uma falha real de remoção do storage
continua explicitamente fora da garantia de cold reload seguro; os testes de
erro preservam essa limitação e exigem erro sanitizado e confinamento em memória.

O checkpoint14:26 tinha147PASS/B4. D00 manteve auth.reset pendente e pediu
o gate frio com storage falho. Retry foi corrigido após RED, com3PASS focais
(dois casos já existentes). O diagnóstico frio usa backend sintético permissivo
e permanece RED conhecido; não será substituído por um deny simulado. A
variante SDK/scope/rota/RPC/logout reais foi preparada para a stack local,
com o mesmo ID lógico de aceite, e naquele checkpoint ainda não havia executado. Sua seleção por ambiente
fora de um lote não conta como teste SKIP já executado nem como novo ID.

## Browser: bloqueio histórico resolvido às15:42

Harness `apps/superadmin/test/manual/auth_session_persistence_harness.dart`,
SDK/storage/scope e rotas normais; apenas HTTP sintético. Debug obrigatório,
origem exata `http://127.0.0.1:8921`, sem fallback remoto e sem deploy.

Comando reproduzível a partir de `apps/superadmin`. Desde assignment D00 r7,
o coordenador detém a porta/origem para diagnóstico; D01 não inicia runner
concorrente:

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

Terceira tentativa, motivada por mudança material do inventário: aba109 ausente
e nova aba116 da mesma origem selecionável. Compilação debug176,4s do mesmo
harness, servidor61459. Com servidor pronto, reload perdeu conexão de controle
(`Debugger unattached`); novo inventário e tentativa de selecionar a aba116
confirmaram a mesma falha. Sem interação de credenciais/storage nem caso
aprovado. Servidor61459 encerrado via `q`, exit0, às13:36 BRT. B4 mantido.

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
- Pacote nominal: seis testes Node preflight e16 executor PASS, modos offline
  PASS, GET settings real e SQL READ ONLY qualificados. Recibo
  `remote-package-qualification.md`. Categoria ferramentas, fora dos153 acima.
- Memória: gate de validação PASS; suíte da ferramenta12PASS/1SKIP por symlink
  indisponível no host, fora do produto. Nenhuma regra durável aprovada nova.

## Provedor real local: campanha separada

Perfil AuthOnly até migration20260901200206, GoTrue2.196.0/Postgres17/
PostgREST/Mailpit reais em recursos descartáveis próprios. Trinta testes
pgTAP e o ciclo HTTP completo de Auth passaram (`local-auth-lifecycle-receipt.md`).
Não equivalem a teste na revisão completa atual do banco nem a produção.

Novo discriminante backend: **1PASS/2FAIL**, três casos únicos em
`local-auth-recovery-boundary-receipt.md`. Login por senha obtém contexto;
recovery antes do PUT e após refresh também obtiveram contexto, indevidamente.
Saída0 do observador não significa aprovação. Correção SQL é proposta local
com preparação reservada por D00 r9 e janela SQL pendente; nenhum resultado GREEN dessa
correção existe neste checkpoint. Cleanup dos dois projetos locais confirmado.

Corretivo local reservado tem plano próprio de verificação:36pgTAP
(30preservados+6novos),9HTTP e1coldcomposto =46gates, **U46 na base candidata**.
O coldcomposto é o mesmo ID lógico frio da tabela cliente, não um caso adicional
ao agregar campanhas. O wrapper/script aguardam janela serial D00. Guardas de
ferramenta passaram, mas não substituem essas provas funcionais.

## Limites de certificação

Reconciliação após RED: **FE1/4 certificado, BE0/4, E2E0/4** no recorte D01.
`auth.recover` tem aceite FE verificado,
conforme `recover-fe-reconciliation.md`, após fechar adapter/VM9PASS;
ausência de SMTP não rebaixa essa camada. `auth.reset` foi reaberto por cold
reload; correção inicial integrada a07c2a2ef e retry publicado5816f982a não
restauram o aceite antes do gate frio com falha de storage e proteção backend,
conforme D00 r10/recibo14:42. Não antecipar o recibo da base conjunta.
Login/Sair têm gates de browser. Esses números
não substituem inventário global datado nem provam integração/publicação.

Pacote remoto `D01-AUTH-PROOF-R02-v1` possui dez gates nominais A1/A2,
R1–R6,L1,C1: bloqueados para execução funcional por mailbox controlada e
autorização nominal ainda pendentes. São gates operacionais, não dez testes
automatizados e não entram no153. Nenhuma conta, senha, email, SMTP ou
configuração remota foi alterada. D00 serializa decisão e integração.

## Ensaio candidato na base integrada — 15:25 BRT

Recibo D00 assignment r14/session29307, migration8500 integrada36e8e4c0b:48migrations aplicadas; campanha46=P35/F1/B10/S0/U0. TAP35 falhou na razão auditada das três recusas AMR. HTTP9 e cold1 não executaram por dependência do TAP. Aprovação35/36=97,22%; falha1/36=2,78%; execução36/46=78,26%; aprovação do plano35/46=76,09%. Não somar essa variante cold ao plano cliente153, nem usar estes testes para promover FE/BE/E2E. Correção da allowlist de auditoria em preparação; nenhum rerun D01 paralelo.
## Reconciliação B4 — 15:42 BRT

Os quatro IDs browser passaram na aba própria829820445 e builddebug estático do mesmo harness, após release D00r15. Recibo browser-b4-static-receipt.md: credencialinválida, persistênciaoff/on comreload, saída+reload. Plano cliente atual P152/F1/B0/S0/U0. A falha restante é o discriminante coldstorage, que depende da campanha real corretiva; não foi apagada pela aprovação browser. Proposta de aceite FE3/4 (login/recover/logout), resetpendente; centralD00 ainda precisa reconciliar essa proposta. BE0/4 e E2E0/4 permanecem. Servidor e aba próprios encerrados, porta8921zero.
## Gate integrado real fechado — 15:48 BRT

D00r18/session78850 exit0: **P46/F0/B0/S0/U0**,36TAP+9HTTP+1cold composto.49SQLaplicadas até173100, candidate368c0add1 integrado9e7e23f18. Logcopiado sanitizado/LF em integrated-auth-boundary-46-pass.log, SHA256E2255866F0A43E0F1C0E98D7C0AD1A5B0DCDBE3BC9B46001816565BD6E038A51. D00confirmoucleanupzero pelo wrapper e inventárioindependente. Resultados100%aprovados/executados nesta campanha46; não somar ao plano153 como novosIDs, pois cold1 écompartilhado e rerunTAPnãoétesteextra.

O antigo35P1F10B foi substituído pelo mesmo universo46 com o successor. Motivo auditado corrigido e verificado também no resolver; nenhum filtro enfraquecido. Coldstoragefalho agora foi negado por backend real, com SDK reinicializado, scope/rota reais e logout. O diagnóstico antigo permanece evidência histórica opt-in, não falha atual do payload corrigido.

Plano cliente153 agora153PASS/0FAIL/0BLOCKED/0SKIP/0UNEXECUTED. Proposta de reconciliação FE4/4 (login/recover/reset/logout); D00 escritorcentral incorpora matrizes. **BE0/4 e E2E0/4 no critério remoto permanecem**: os46 comprovam integração local real, sem certificar ambienteprodução/SMTPrealremoto. Próximo gate independente é transporteCLI/ledger do pacotev2; qualquer revisão dos delimitadoresSQLexige nova prova do payload final, sem repetir46enquanto fonte ficarigual.
## Certificado central confirmado — 16:02 BRT

D00 registrou FE4/4 em15:49 no certificado canônico `docs/reviews/evidence/etapa-2/r02-d00-integration-20260909/auth-fe-reconciliation.md` e no rastreador integrado. Não é mais apenas proposta D01. BEremoto0/4 eE2E0/4 preservados. O cenário cold de storagefalho reinicializaSDK/scope/rota dentro do teste; **não é reinício do processoOS nem reload de navegador desse cenário**. B4 é a prova distinta de reloadreal no navegador com armazenamento normal. Essa distinção limita a garantia ao discriminante executado, sem ampliar o certificado central.
## Build normal atual — 16:08 BRT

Uma compilação release de lib/main.dart, posterior às correções de persistência, passou em76,9s/exit0; Wasm dry-run tambémPASS. FonteHEAD57e3758d24b3c5e2880f49b7472e65fcf16d158c, somente WIPdocumental. Output próprio apps/superadmin/build/d01-auth-release-candidate; main.dart.js SHA25612D479F50683C3F1C5CF01715EEB6B5F43ADA380F1E06C2119DBEB03C110A4C5. Log normal-release-after-persistence-fixes.txt. Sem pubget, define de credencial ou execução/publicação remota. O warning CupertinoIcons já constava no release-build.txt anterior; nenhuma regressão nova atribuída a Auth. Build não é testeIDextra, app configurado para produção ou deploy. Runner67501concluído, recursos próprios ativoszero.