---
title: "Modelos — comandos interpretam envelopes sem falso sucesso"
source: "Reserva nominal do Coordenador; confronto original em 84a42e7b; migrations 20260901193000 e 20260901170731; reviews realm_audit e account_review"
status: "local-green; production-and-e2e-open"
generated_at: "2026-09-08"
---

## Recorte e RED real

Somente SupabaseAccessProfileRepository.createModel/updateModel/duplicateModel/
deleteModel e testes. Perfis list cru, READ Models, import/export, Conta,
router/shell/SQL/grants e composição produtiva intocados.

Dois testes executados separadamente antes de alterar produção, ambos exit1:

- `delete rejects HTTP200 SAI_PERMISSION_DENIED without reporting success`:
  esperava AccessProfileUnauthorizedException; Future emitiu null como sucesso.
- `create accepts SQL receipt replayed=false and preserves request`:
  TypeError, Null não é Map, em _modelFromReceipt:326; decoder procurava model
  no topo da resposta e não em data.model.

Comando de cada RED: `flutter test --no-pub
test/features/access_profiles/data/access_profile_models_write_envelope_test.dart
--plain-name "<nome acima>"`, cwd apps/superadmin, via RTK. MockClient em
memória; nenhum comando SQL nem requisição de rede executados.

## Correção e contrato exato

Wrappers 20260901193000:26–56 preservam p_request_id/p_draft ou
p_request_id/p_model_id/p_expected_version/p_reason. Chamam
app_private.access_profile_model_call; 20260901170731:1067 retorna erro
envelopado e :1069 sucesso `{ok:true,data:result,error:null}`.

Novo decoder exclusivo dos quatro writes exige envelope válido e entrega
data ao decoder do receipt. Não aceita payload cru como fallback.
Sete códigos SAI de autorização/sessão/MFA viram unauthorized;
SAI_CONCURRENT_CHANGE vira conflict; desconhecidos, inválidos e dados
malformados recebem mensagem local genérica. PostgREST 42501/40001 conserva
os subtipos já mapeados. Nenhum detalhe técnico do servidor é exibido.

Create/update/duplicate decodificam o modelo aninhado; não alegar validação
integral de todos os metadados externos desses receipts. Delete valida alvo
igual ao solicitado, status inactive, version inteiro e replayed booleano,
conforme SQL :693–694. Replay do helper :231 preserva o receipt e muda
replayed para true; ambos são aceitos. Request IDs, drafts, versão esperada,
razão e semantics de autorização/idempotência não mudam. Não há retry
automático de comando, recálculo de versão ou nova chamada auxiliar.

## Verificação

- Primeira matriz nova: 76/76 PASS após a correção.
- Matriz final: 88 casos novos (adicionados 8 transportes 403/409 e 4 receipts
  delete malformados), incluídos na regressão data completa **169/169 PASS**,
  exit0. Não somar com os 76 ou com rodadas históricas.
- Analyzer dos três arquivos Dart alterados: zero problemas, exit0.
- Testes antigos ajustaram somente respostas simuladas create/update/delete
  para o envelope SQL real; asserções de request e parâmetros preservadas.
- Reviews independentes account_review e realm_audit sem bloqueantes;
  conferência estática de operação/RPC/envelope/receipt e escopo do diff.

Os negativos verificam que a continuação de sucesso do Future não executa;
não são prova de SnackBar ou navegação real da UI. A suite data também contém
READ/Perfis/adapter existentes, mas não navegador, SQL, mídia ou produção.

## Handoff e limites

Ações: access-models.create/edit/duplicate e comando delete exposto pelo
contrato de Modelos (não criar novo denominador por inferência). Backend
Supabase não alterado; Cloudflare não se aplica à corretiva de parsing.
Primeiro gate aberto: pacote backend/runtime nominal e prova UI → comando →
persistência → reload/negação, além do catálogo domain-only já separado.
Não habilitar imports/exports históricos nem tratar local-green como E2E.
Gate coelo-knowledge: no-op, restauração de contrato existente sem decisão
nova de produto. Matriz do escopo original foi preservada no crosswalk.
