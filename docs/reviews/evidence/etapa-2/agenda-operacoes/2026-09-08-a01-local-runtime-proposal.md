---
title: "A01 — roteiro nominal Flutter/PostgREST local"
source: "autorização do Coordenador em 2026-09-08; perfil464a947d; fixture97 ee212cb5; evidência5ef2fc4e"
status: "harness candidato; HTTP e SQL não executados nesta fatia"
generated_at: "2026-09-08"
---

# Recorte

Somente Superadmin, `activities.list` e filtros nominais v2, rota `/activities`.
Objetivo: atravessar widget/rota produtiva, adapter produtivo, PostgREST real,
bootstrap039 e auditoria backend em stack local isolada. Não cobrir CRUD,
modelos de Atividades, mídia, Admin/Principal/Site nem promover remoto/E2E geral.
Writer cliente: E2E5. **Eng1 é o único operador de SQL e Docker**; Coordenador
reserva o pacote e autoriza execução. A autorização recebida é de preparação,
não de execução. Tempo de preparação estimado: 20–35 minutos; runtime não
calculável antes da reserva/seed/endpoint.

## Base exata requerida

Reutilizar **A01DirectoryAuditGreen55**, não Foundation67 nem uma base genérica51.
Fonte: commit `464a947dff729acfaabb5ee6fbdd7faa242b6b1e`, perfil
`packages/coelo_database/replay/profiles/A01DirectoryAuditGreen/profile.json`.
São Auth45 + oito adições canônicas =53; dois preflights herdados =55; zero
bridges adicionais; alvo `20260907222911`.

- Manifesto canônico `foundation-migrations.sha256`, SHA CRLF UTF-8
  `4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`.
- Descriptor SHA CRLF UTF-8
  `bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba`.
- Corretiva v2 `96de811b8ce02333f302117e9ee8c4e7d5dc445d`, SHA CRLF
  `e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f`;
  SHA LF `e4b02a2100030c36a0895d04036685cafae623326872f3141902d00043fe66f2`.
- Sete adições Activities anteriores: actor_attribution31192831,
  provenance_hardening31195118, provenance_semantics31195944,
  permissions_receipts31203645, internal_gateways31211945,
  rls_grants31231645, final_review_hardening31234307 (prefixo202608).
  Nomes e hashes completos são os do descriptor pinado, sem seleção por glob.

O perfil55 teve97TAP PASS na evidência5ef2fc4e, mas seu wrapper desmonta o
ambiente no final. **Não usar o wrapper como se fornecesse lease HTTP.** Eng1
precisa apresentar um mecanismo nominal revisado de manter PostgREST ligado
somente à stack desse perfil durante a janela, com teardown próprio comprovado.
Não remover cleanup ou contornar guards existentes para obter essa janela.

## Seed nominal que o operador precisa fechar

Fonte imutável: `superadmin_internal_activities_v2_directory_contract_test.sql`
do commit `ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4`, SHA LF
`fc492972051e741e37d0dd7b1d7056eec24a57c4b02e98bb6ffccb9a4ca3b3b1`.
Extrair semanticamente apenas o seed até a remoção de grants de escrita de
Operations, antes do primeiro TAP. Não copiar uma contagem de linhas frágil.
Excluir pgTAP/no_plan/asserts e executar constraints imediatas antes de COMMIT.

HTTP não enxerga seed preso em transação aberta ou desfeito por ROLLBACK.
O seed confirmado é permitido apenas no banco descartável isolado nominal;
ele altera papéis owner/operations/content e não pode atingir stack compartilhada.

UUIDs usam prefixo `8a200000-0000-4000-8000-` e sufixo decimal com12dígitos:

| Recurso | Sufixos | Expectativa |
| --- | --- | --- |
| Instituições |10/20| A/B |
| Unidades |11/12/21| duas A, uma B |
| Grupos |13–17/22| cinco A, um B |
| Atividades |701/703/702| Robótica A, Robótica Local A, Robótica B |
| Reader |Auth102/session202/identity302/link402/membership502| Operations instituiçãoA |
| Membership revogada |Auth104/session204/identity304/link404/membership504| sessão existente, membership revogada |
| Capacidade negada |Auth106/session206/identity306/link406/membership506| Content, activities.read deny |

Necessidade adicional explícita do seed HTTP: garantir `platform.read` efetivo
em Operations102 e Content106 para bootstrap real. O grant deve constar no
seed nominal revisado; **não é autorizado implicitamente por este documento**.
Reader102 continua somente leitura do domínio.106 deve passar bootstrap e
falhar no reader de Activities;104 deve falhar no bootstrap e no domínio.
Não adicionar pessoa global aos atores internos, grants client-side, service
role ou RPC privada de inspeção. Pessoa601 da fixture é somente caso negativo.

Eng1 deve fechar e pinar seed completo, constraints, sessões `not_after`,
reload de schema e prova de que o PostgREST está conectado à base55 preparada.

## Credenciais e execução candidata

O operador fornece por ambiente somente credenciais **locais sintéticas**:

- `COELO_A01_LOCAL_RUNTIME=1` como opt-in;
- `COELO_A01_LOCAL_URL=http://127.0.0.1:<porta-local-reservada>`;
- `COELO_A01_LOCAL_ANON_KEY`: JWT anon da stack local;
- `COELO_A01_READER_JWT`, `COELO_A01_REVOKED_JWT`, `COELO_A01_DENIED_JWT`:
  JWTs assinados pelo operador para os três pares Auth/session acima,
  role authenticated, aal2, validade restante positiva e no máximo1hora.

Segredo assinador nunca entra no cliente. Não imprimir ou salvar tokens,
chaves, headers ou sessão pessoal em Git/logs/evidências. Não usar dart-define
ou assets de frontend para essas credenciais. O harness vive apenas em test/.
Seu parser valida a forma e o ator; **a assinatura é validada pelo servidor**.

Após reserva/autorização formal, o comando candidato a partir de apps/superadmin é:

```powershell
rtk proxy flutter test --no-pub test/features/activities/a01_local_runtime_test.dart
```

Sem opt-in o caso é SKIP, nunca prova de execução. Transporte real permite
apenas POST para três RPCs: bootstrap039, directory_v2 e filter_options_v2;
origem127.0.0.1 com porta explícita, sem query/userinfo/fragmento/redirect.
Nenhuma conexão remota, SQL, Docker, mutation RPC ou tabela direta no harness.

## Critérios de verificação da janela

1. Bootstrap real do102 retorna instituiçãoA e capacidades requeridas; só então
   `SuperadminSession.authorize` usa esse resultado (sem signInForTesting).
2. Rota normal `/activities`, sem `/dev`, usa adapter real e mostra701/703,
   não702; comandos indisponíveis continuam ocultos.
3. Saída/reentrada recarrega dados via HTTP; os dois readers devem ser chamados
   novamente. Não chamar essa ação de reinício do aplicativo ou nova sessãoAuth.
4. Adapter real confirma dois IDs A, options1/2/5 e filtroB adulterado vazio.
5.104 membership revogada nega bootstrap e leitura;106 bootstrap válido com
   domínio negado. Mudança para token104 com shell já autorizado precisa limpar
   itens e renderizar acesso não autorizado na nova leitura.
6. Harness emite somente nomes de RPC, status HTTP, ok e correlações UUID.
   Eng1 consulta auditoria separadamente por essas correlações: ator/identidade/
   link/membership, permissão, resultado, instituição, hash de sessão e
   after_json apenas row_count em sucesso. Não usar reader legado de Auditoria.
7. Eng1 confirma seed persistido e imutável após as leituras, audit real,
   ausência de efeitos de escrita do domínio e teardown nominal completo.

Negativas de ID de detalhe/CRUD, revogação de sessãoAuth, concorrência completa,
reautenticação de usuário e produção continuam fora. FiltroB é prova de escopo,
não prova de todos os caminhos IDOR. Correlações impressas não provam audit sem
consulta posterior. Nenhum `verified-e2e` deve ser atribuído antes desses gates.

## Preparação já executada

13 testes de guards locais PASS. Runtime forçado a SKIP durante compilação;
nenhum HTTP ou SQL executado por E2E5. Um erro inicial do harness com argumento
nulo em HttpOverrides foi corrigido; não era falha do produto nem RED E2E.
Revisão independente de seed/base confirmou os gates acima. Memória: roteiro
operacional candidato, sem nova regra de produto a projetar em docs/knowledge.
