---
title: "Usuários e Modelos — candidato runtime local separado por base"
source: "Reserva de preparação do Coordenador; abordagem A01 f5b0e5bf; Users49 36964bbb; Models50 5ef2fc4e; fixtures e review realm_audit/account_review"
status: "candidate-only; runtime-not-executed; seed-and-window-pending"
generated_at: "2026-09-08"
---

## Contrato

Somente Superadmin: Usuários READ e Modelos READ por rota normal, repositories
reais e bootstrap039 via PostgREST local. Nenhum HTTP, SQL, Docker, servidor ou
remoto executado nesta preparação. Eng1 é o único operador da futura janela;
Coordenador reserva perfil, recursos, porta, seed e teardown antes de ativar.
Não alterar cleanup do replay para deixar uma stack ligada informalmente.

Arquivos focais em test/features/identity e test/support/identity. Nenhum
import em lib, framework genérico, edição E5, router ou adapter produtivo.
Estimativa da preparação: 20–35 minutos; execução depende do pacote do operador.

## Bases e seeds separados

| Modo | Base requerida | Seed inicial de referência |
|---|---|---|
| Users49 | Auth45 + 20260901210000 + corretiva20260908021644 + dois preflights | Minimização3, prefixos e1/e2/e3/e4/e5; Owner Sintético e Parcial Sintético |
| Models50 | ModelReadAuthorizationGreen, pacote464a947d; Auth45 +171731 +193000 +21821 + dois preflights | Primeiro seed da fixture17, prefixos f1/f2/f3/f4/f5 e modelos f7 |

Users49 teve 48 TAP PASS; Models50 teve 38 TAP PASS, incluindo repetição11/17.
Não somar essas contagens como integração. Provas do operador, lidas antes de
preparar o candidato: users49-green-2026-09-07.md e models-read-green-2026-09-08.md.

Hashes LF das fontes imutáveis:

- Users minimização3: 3f63667461cb3aa52f6bd363319d9f06810ebf8504776a740570156a690e71f3.
- Users45, para etapa de escopo posterior: f19fe5166dc9ba6405f5921d4a2406a645fb1209933fec4df432692558b4c8fa.
- Models17: 084d70c291552ff779192f96c4821b9d9b1a98dc4efaa0bec9d3435874de8e73.

O operador precisa criar seed HTTP nominal revisado, persistido somente no
banco descartável, com constraints verificadas. Não substituir o ROLLBACK
das fixtures por COMMIT: elas mudam grants/estados e fazem mutações entre TAPs.
O primeiro corte do candidato requer somente o seed inicial indicado, sem
essas fases intermediárias. Names/hash do novo seed ainda não estão fechados.

## Identidades e credenciais sintéticas

Guard Users49: Auth e1000000…001, sessão e2000000…001, identidade e3000000…001;
parcial e3000000…002 deve permanecer sem auth-link e fora da lista/count.
Guard Models50: Auth f1000000…001, sessão f2000000…001; modelos f7000000…001/002/003.
As abreviações representam o meio fixo `-0000-4000-8000-000000000` dos UUIDs
completos nas fixtures e no código de teste, não um novo esquema de IDs.
Sessão negativa de cada modo termina099 e deve estar ausente do banco.

O candidato não faz login nem inventa assinatura. Eng1 deve fechar emissão de
JWTs locais assinados, suas linhas reais de sessão, AAL1 e validade, validando
assinatura no servidor. JWT sintético para testar PostgREST não prova login
GoTrue real, MFA, recuperação ou revogação de sessão. JWT/GUC da fixture não é
automaticamente uma credencial HTTP válida. Segredo assinador não entra no teste.

Variáveis fornecidas somente no processo local pelo operador, sem exibir valores:

- COELO_IDENTITY_LOCAL_RUNTIME=1 e COELO_IDENTITY_LOCAL_PROFILE=Users49 ou Models50;
- COELO_IDENTITY_LOCAL_URL: http://127.0.0.1:<porta-reservada>;
- COELO_IDENTITY_LOCAL_ANON_KEY: JWT anon local;
- COELO_IDENTITY_READER_JWT e COELO_IDENTITY_INVALID_SESSION_JWT: pares nominais,
  role authenticated, aal1, validade positiva até uma hora.

A porta54381 nos testes unitários é só dado sintético, não reserva operacional.
Uma base por janela, uma porta explícita reservada pelo operador, sem misturar
os seeds. O guard confere forma/perfil/claims, não atesta banco, base ou assinatura.
Não salvar credenciais, headers, payloads sensíveis, CPF ou e-mails em logs.

## Requests permitidos

Somente POST, mesma origem127.0.0.1/porta, sem query/userinfo/fragmento/redirect:

- Ambos: superadmin_auth_bootstrap_context.
- Users49: superadmin_internal_user_profiles, superadmin_internal_users_list,
  superadmin_internal_user_detail.
- Models50: superadmin_access_profile_models_cursor,
  superadmin_access_profile_model_detail, superadmin_access_permission_catalog.

Sem tabelas diretas, service_role, Auth admin, writes, import/export ou mídia.
O transporte registra em memória apenas nomes das RPCs; não imprime respostas.

## O que o candidato executável pretende provar

1. Bootstrap real autoriza Owner platform AAL1; Session recebe somente seu retorno.
2. Users usa /internal-users; Models /profile-models, sem /dev. UI exibe o seed.
3. Saída para Home/reentrada precisa causar nova chamada de listagem. Isso é
   recarga de rota, não reinício do aplicativo nem nova sessão autenticada.
4. Users lista somente a identidade completa; detail via adapter real. Models
   lê os três domínios e catálogo via adapter real (Owner global).
5. Token com sessão inexistente nega bootstrap e reader; com shell anterior
   ainda montado, reentrada precisa exibir Acesso não autorizado e remover dados.

Código compilado com opt-in forçado a0: 25 testes de guard PASS e um runtime
SKIP, não PASS de integração. Analyzer dos dois diretórios: sem problemas.
Complemento posterior: guard ampliado para 30/30 PASS, cobrindo os limites de
expiração, claims do token negativo isoladamente e reutilização indevida do
token positivo. Analyzer focal limpo; produção e runtime continuam intocados.
Os testes de guard usaram tokens unsigned fictícios sem rede. RED de criação
foi import/classe ausente, não bug de produto. Review account_review não apontou
bloqueio estático para candidato; runtime real ainda pode revelar falhas.

## Etapa seguinte obrigatória: revogação e escopo

Estes controles estão no roteiro, NÃO implementados/provados pelo corte acima:

- Users45 reader003 institucional A, alvos004A/005B: seed separado revisado,
  bootstrap platform.read + member.read; lista não mostraB e detalheB nega.
- Após primeira leitura real, operador altera nominalmente membership/link do
  reader para revoked e registra persistência; repetir com o MESMO JWT/sessão
  e reentrada. Sessão inexistente099 não substitui esse teste de revogação.
- Models: Owner global com deny específico de institution.role_models.read;
  platform permanece permitido e institution negado. O helper exige Owner:
  não inventar um papel alternativo para simular a mesma política.
- Domain-only sem platform.read não representa login normal; contrato de
  catálogo no adapter continua separado. Modelos globais não fornecem prova
  genérica de isolamento institucional apenas por alternar p_domain.
- Login real, nova sessão/reload de app, revokeAuth, audit correlacionada por
  operador, preservação do seed e cleanup completo precisam evidência adicional.

Após seed e reserva, comando candidato em apps/superadmin:
`flutter test --no-pub test/features/identity/identity_read_local_runtime_test.dart`.
Sem opt-in, SKIP. Produção permanece fora e exige lease próprio. Nenhum
verified-e2e concedido. Gate de memória: no-op, roteiro técnico não muda produto.
