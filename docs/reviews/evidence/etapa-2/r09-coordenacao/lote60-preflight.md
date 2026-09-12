---
source: C0 R09; pgTAP no espelho; preflight Supabase; ADR0034
status: preflight-verde; aguardando-aplicacao-serializada
generated_at: 2026-09-12
---

# Lote 60 — autorização de anexos de respostas

Recorte: apps/superadmin -> Coelo (Principal) -> Formulários -> respostas/anexos -> forms.upload e forms.resolve-file.

O worker autorizava um asset anônimo sem segredo válido quando a expressão
booleana de ownership resultava em NULL. Dois testes reproduziram a falha:
segredo errado e segredo ausente. O candidato preserva o contrato e exige
que a expressão seja explicitamente verdadeira (`IS NOT TRUE` rejeita).
Nenhum dado, identidade ou credencial foi alterado. Execute permanece
exclusivo de service_role; cliente acessa o handler autenticado normal.

No espelho `supabase_db_coelo_baseline`, pacote focal 25 PASS e regressão
comportamental 17 PASS (42 únicos). A versão anterior falhou nos dois casos
novos; o candidato passou. Antes disso foi reconciliado somente no espelho
um grant authenticated adicional que não existe em produção.

A suíte ampliada tinha erro SQL por combinar retornos TAP text com AND.
Corrigido apenas o predicado do teste, executou 70 casos: 62 PASS, 8 FAIL
(41,42,44,47,53,57,58,70). Comparação transacional com a função original
produziu as mesmas oito falhas. Não há certificado de regressão ampla verde.
Produção fica no lote59 enquanto esse gate é esclarecido; nenhuma aplicação
nem nova composição ocorreu. Logs locais preservados no mesmo diretório.

Preflight remoto 16:45 BRT: lote59 presente uma vez; candidato ausente;
authorizer MD5 46dbfe0ed41712e020849664033e42d5; authenticated sem execute.

Backup lógico completo fora de Git, conforme ADR0034 Decisão8:

- `C:/Users/adrie/Documents/Coelo-backups/schema-producao-20260912-r09-lote60.sql`: 4.143.050 bytes, SHA256 `7149ee529105d8f39ae3dee01a4427fe9491c402d35f2863eb07085b5e4fa00a`.
- `C:/Users/adrie/Documents/Coelo-backups/dados-producao-20260912-r09-lote60.sql`: 4.349.644 bytes, SHA256 `033fd39a449415b25b6a7ecba999f9b7c2db981dde7ba6f34b1e63263be06067`; dump complete presente, processo terminado às16:40. Código de saída não recuperado após compactação; não é relatado como exit0.

Próximo gate C0: classificar as oito falhas sem enfraquecer invariantes,
validar regressões pertinentes e renovar preflight antes de aplicar forward-only.
Sem promoção FE, BE ou E2E por este candidato local.

## Gate resolvido ? revis?o105, 16:55 BRT

As oito falhas foram classificadas e resolvidas, sem alterar produ??o:
41 conferia guardian_context_permissions na fun??o errada (a autoriza??o est?
na reconcilia??o de responders);42 exclu?a draft, j? previsto na implementa??o;
44 inclu?a ?ndices no conjunto de tabelas RLS;47 ignorava o quarto job de m?dia
j? aplicado na R06 (migration20260911210900). Os testes agora conferem o
contrato vigente sem retirar a autoriza??o, a nega??o nem a allowlist exata.
As falhas53/57/58/70 eram ACLs extras do espelho; produ??o foi medida e j?
nega execute/UPDATE. Reconciliado somente localmente. Os tr?s crons antigos
faltantes foram restaurados com comandos can?nicos e TODOS os quatro jobs
locais de forms desativados antes do commit, evitando execu??o de dispatch.
N?o houve chamada remota nem leitura de segredo para essa reconcilia??o.

Resultado: su?te ampliada70PASS/0FAIL/0SKIP/native0, arquivo
lote60-reconciled-security.log. Total pertinente ?nico112PASS (25+17+70).
Falhas e logs anteriores ficam preservados, n?o somados como novos testes.
Schema e dados t?m marcador dump complete e SHA256 reconferido. Preflight
renovado, ledger59 presente e candidato ausente. Lote60 liberado para aplica??o
somente do NULL guard; n?o reaplicar lotes anteriores nem SQL de reconcilia??o.
