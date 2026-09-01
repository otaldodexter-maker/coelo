---
source: "autorizacao nominal do usuario em 2026-09-01; ADR 0019; specs 039; OQ-006, OQ-015, OQ-016, OQ-034, OQ-035, OQ-037, OQ-041, OQ-042 e OQ-043; documentacao oficial Supabase Auth"
status: "approved-for-local-implementation"
generated_at: "2026-09-01"
---

# Auth-first local do Superadmin sem MFA

## Objetivo

Fechar localmente o contrato transversal de entrada, identidade interna,
lifecycle de sessao e autorizacao do Superadmin, incluindo as telas reais de
Login, Recuperacao e Redefinicao de senha. O teto desta entrega e
`local-green`: nenhuma evidencia local promove o remoto, uma tela ou o produto
a `done`.

Esta especificacao complementa a spec 039 e substitui somente a exclusao
historica do callback e da redefinicao de senha. A autorizacao do usuario neste
pacote e a decisao nominal para materializar essa etapa. MFA continua fora do
escopo e todas as exigencias AAL2 existentes permanecem fail-closed.

## Contrato funcional

- Login usa credencial existente e devolve a mesma mensagem segura para conta
  inexistente, senha incorreta ou detalhe interno do provedor.
- A escolha de persistencia e aplicada antes do login. A restauracao e o
  refresh usam o lifecycle nativo do Supabase; logout invalida a sessao e
  remove o estado/cache cliente correspondente.
- Recuperacao chama `resetPasswordForEmail` com redirect explicito para
  `/reset-password`, sempre responde de modo neutro e nao cria conta publica.
- A tela de redefinicao somente habilita a troca apos o SDK estabelecer uma
  sessao de recovery valida. Callback ausente, invalido, expirado ou reutilizado
  permanece negado sem revelar tokens ou detalhes do provedor.
- A nova senha e aplicada por `updateUser`. Depois do sucesso, o app encerra a
  sessao de recovery e volta ao Login; senha antiga e link reutilizado devem ser
  recusados na prova full-stack local.
- Auth interno usa principal, auth link e membership proprios do realm
  Superadmin. Nenhuma pessoa sintetica e criada e nenhuma autorizacao
  people-based e reutilizada.
- Operacoes protegidas revalidam no backend `auth.uid()`, `session_id`, realm,
  membership ativa, papel, capability e escopo institucional. JWT, IDs,
  tenant/contexto, filtros e payloads do cliente sao nao confiaveis.
- Membership suspensa ou revogada, sessao revogada, capability ausente,
  cross-realm, cross-tenant e identificador adulterado falham antes de retornar
  dados protegidos.
- Troca de tenant/contexto invalida dados derivados e cache da superficie antes
  da nova leitura. O cliente nao concede acesso; apenas solicita e renderiza.
- Auditoria registra resultado e motivo estavel minimizados, nunca senha,
  token, segredo, e-mail completo ou outro dado pessoal desnecessario.

## Fronteiras de seguranca

- `user_metadata` nunca participa de autorizacao.
- `service_role`, secret key, senha e tokens nao entram no bundle, Git, URL de
  aplicacao, logs ou evidencias.
- RLS permanece deny-by-default e grants sao minimos. Toda funcao
  `SECURITY DEFINER` tocada deve ter justificativa, `search_path` seguro e ACL
  explicita.
- Requisitos AAL2 ja existentes nao sao removidos, rebaixados ou simulados.
  Quando o usuario AAL1 alcanca uma operacao que exige MFA, o recurso fica
  indisponivel e a operacao e negada.
- O projeto remoto `coelo` permanece read-only enquanto OQ-041 estiver aberta
  e nao houver uma nova autorizacao nominal de mutacao.

## UX aprovada

As tres telas preservam as baselines existentes: superficie neutra, campos com
label persistente, borda `outlineVariant`, foco primario de 2 px, acao primaria
laranja, feedback textual e aviso de acesso restrito. Devem funcionar em
375/768/1024/1440, light/dark, teclado e texto ampliado. Nao nasce componente
visual novo.

Estados adicionais da Redefinicao: processando callback, link valido, link
invalido/expirado, envio, sucesso e falha segura. O estado processando nao
aceita senha; o invalido oferece retorno ao Login.

## Evidencias locais exigidas

1. Testes Dart/Flutter RED→GREEN de gateway, recovery state, composicao, router
   e tres telas, preservando goldens aprovados.
2. GoTrue, Kong, PostgREST e Postgres locais reais para login, refresh, logout,
   recuperacao, callback, update password, expiracao/reuso e revogacao.
3. pgTAP do contrato interno para principal/link/membership, role/capability,
   realm, tenant, IDs adulterados, sessao e auditoria.
4. Replay descartavel limpo, regressao proporcional, analyze/build, validador
   visual, advisors focados, secret scan, `git diff --check` e cleanup.

## Criterio de parada e limite

Parar no fim das 6 horas, em conflito canonico/ownership, decisao de MFA,
necessidade de outra tela ou dominio, mutacao remota, ambiente nao descartavel
ou impossibilidade de provar uma negativa sem reduzir seguranca. O primeiro
gate nao demonstrado permanece explicitamente aberto.

