---
title: "R08 G0 — Ambiente e runtime"
source: "Execução local da R08 e docs/reviews/etapa-2-operacao/next-round/R08-prompts.md"
status: "handoff"
generated_at: "2026-09-12T11:08:00-03:00"
---

# R08 G0 — Ambiente e runtime

## Recorte e resultado

Recorte exclusivo de ambiente local, espelho Supabase preservado e scripts QA existentes. Nenhuma feature, router, composição, tracker central ou delta de estado foi alterado.

- Docker Desktop/WSL: recuperado sem factory reset, reinício do Windows, remoção de volume ou recriação de VHDX.
- Espelho `supabase_db_coelo_baseline`: saudável em `127.0.0.1:57322`, com volume nomeado preservado.
- Build QA: concluído em modo release a partir de `af99409cf5bb266b4be96647690abde44ace8f23`.
- Servidor: ativo em `127.0.0.1:3014`, PID `16248`.
- Navegador compartilhado: aba Chrome mantida aberta, mas a automação CUA não atualizou o controller dos campos Flutter. Login, leitura autorizada e persistência após reload **não foram comprovados**.

## Docker Desktop e WSL

Estado inicial:

- cliente Docker `29.7.2` disponível;
- named pipe `dockerDesktopLinuxEngine` ausente;
- distribuição `docker-desktop` parada;
- `WslService` ativa e serviço `com.docker.service` parado/manual;
- nenhum processo Docker Desktop ativo.

Os logs do backend registravam aborto de inicialização por processo residual: PID `6984` (`Docker Desktop.exe`). O próprio Docker tentou `taskkill`, recebeu que o processo não existia e terminou com `lingering processes detected at startup`.

Primeira tentativa preservadora:

```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
```

O daemon respondeu aproximadamente 28 segundos depois. Estado medido em 2026-09-12 11:07 BRT:

```text
SERVER=29.7.2 CLIENT=29.7.2
supabase_db_coelo_baseline: running / healthy / restart unless-stopped
5432/tcp -> 0.0.0.0:57322
volume: supabase_db_coelo_baseline -> /var/lib/postgresql/data
```

Preservação observada:

```text
C:\Users\adrie\AppData\Local\Docker\wsl\disk\docker_data.vhdx
bytes: 34184626176
```

O VHDX continuou montado e sendo atualizado pelo daemon. Não houve segunda tentativa porque a primeira recuperou o serviço.

## Espelho baseline e ordem real

O ledger `supabase_migrations.schema_migrations` contém apenas `20260910000000 | baseline_producao`. Esse ledger não representa a sequência realmente carregada: o espelho preservado foi montado historicamente com migrations encaminhadas diretamente por `psql`, sem inclusão automática no ledger.

Uma tentativa inicial de replay cego reaplicou somente os dois primeiros arquivos idempotentes e parou no terceiro, corretamente, com `daily routine foundation already present`. Nenhum reset foi executado.

Depois da interrupção, a paridade foi conferida por objetos e corpos SQL representativos do fim da fila. O espelho contém:

- lote 52: correção de escopo HOT;
- lote 54: `canonical_handle` de atividades;
- lote 54: `next_version_number` de formulários;
- lote 54: `public.superadmin_people_identity_lookup_v1(text,text,uuid,uuid)`;
- lote 55: sincronização de papéis;
- lote 55: regra de escopo com `jsonb_typeof`;
- lote 55: função do worker de usuário interno.

Contagens observadas: `1232` funções e `335` tabelas nos schemas `public`, `app_private`, `audit` e `analytics`. A fonte serializada contém 156 migrations nos lotes 1–55, e todos os arquivos referenciados estavam presentes. Conclusão operacional: o espelho preservado está materializado até o lote 55; o ledger isolado não deve ser usado para decidir replay. O lote 56 continua reservado ao C0 e nenhum banco linked foi acessado ou resetado.

## Build QA e servidor

O `.env.local` foi copiado mecanicamente do backup local autorizado e permaneceu ignorado pelo Git. O SHA-256 do arquivo foi comparado, sem imprimir valores: `24152d9c513447ed049a79c8d8ea78e40678be21b89d48aef2c8bcb8f79f5d5a`.

Comando executado em `apps/superadmin`:

```powershell
flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
```

Resultado: exit code 0 em 74,1 s, Flutter `3.44.2`, Dart `3.12.2`.

```text
build/web/main.dart.js
bytes: 8339145
sha256: 4ca0e74024f379b451b78fb36daeca2a09a29445474eacf938266005845e4bf1
```

Servidor SPA existente reutilizado:

```powershell
python docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/ferramentas/serve.py --directory apps/superadmin/build/web --host 127.0.0.1 --port 3014
```

Recursos entregues:

```text
PID: 16248
http://127.0.0.1:3014/login -> HTTP 200, 1020 bytes
http://127.0.0.1:3014/flutter_bootstrap.js -> HTTP 200, 9975 bytes
```

Esses HTTP 200 provam somente a entrega dos artefatos, não o login.

## Chrome e bloqueio de E2E

Foi criada uma única aba compartilhada pelo mecanismo documentado CUA:

```text
browser: Chrome por extensão
session name: 🧪 Coelo G0
provider tab id: 829822454
URL: http://127.0.0.1:3014/login
processo raiz Chrome reutilizado: 22592
renderers criados no intervalo: 41024 e 4624
```

A integração por extensão reutiliza o Chrome já aberto e não expõe um PID exclusivo por aba; por isso os renderers são candidatos observados, não uma associação afirmada.

Com a identidade QA autorizada carregada somente em memória, sem registrar valores, foram tentadas três formas documentadas e materialmente distintas:

1. `setValue` nos campos acessíveis;
2. foco do campo seguido de `paste`;
3. foco, `Control+A` e `typeText`.

Nas três, o submit retornou `Informe seu e-mail.`. Os campos visuais permaneceram vazios e nenhuma chamada de autenticação foi transmitida. A captura sanitizada está em [login-runtime-bloqueado.png](./login-runtime-bloqueado.png).

Por orientação do C0, não foi aberto caminho alternativo de CDP nem outro navegador. A aba foi marcada para handoff e não houve logout. Próximo gate: um executor com digitação Flutter funcional ou CDP já autorizado deve reutilizar o servidor 3014, executar o login, abrir uma leitura autorizada e provar que o estado permanece após reload.

## Estado de entrega

- Pronto para uso: Docker Desktop, baseline 57322, build QA e servidor 3014.
- Bloqueado com diagnóstico: login/leitura/reload pelo Chrome compartilhado CUA.
- Não executado: reset, factory reset, reboot, acesso destrutivo/linked, credenciais em log, testes Flutter ou deltas de estado.
- Recursos intencionalmente mantidos: daemon Docker, containers baseline, servidor PID `16248` e aba Chrome `829822454`.

## Gate adicional solicitado pelo C0: ACL compartilhada e lote 56

Depois da primeira entrega, o C0 atribuiu o gate SQL local adicional. G5 identificou as suítes e definições finais em `76aed97cb`; G0 executou no mesmo baseline, sem aplicar migrations e sem cleanup externo.

Ordem e resultado em [pgtap-acl-shared-20260912.log](./pgtap-acl-shared-20260912.log):

| Ordem | Suíte | Resultado | Exit nativo |
| ---: | --- | ---: | ---: |
| 1 | `principal_internal_actor_bridge_v1_test.sql` | 22/22 | 0 |
| 2 | `internal_actor_scope_root_v1_test.sql` | 46/46 | 0 |
| 3 | `internal_actor_scope_root_v1_hotfix_test.sql` | 4/4 | 0 |
| 4 | `internal_actor_institution_access_by_role_v1_test.sql` | 16/16 | 0 |

Wrapper: exit 0. Cada suíte abriu transação própria e terminou em rollback. Os 88 testes provam a ponte people-based, escopo platform/institution, negação cross-tenant, reativação restrita do hotfix, idempotência, troca/revogação de papéis, Owner → `institution_admin`, Operations → `institution_reader`, Auditor sem vínculo e ausência de EXECUTE direto para clientes.

O preflight somente leitura [preflight-lote56.sql](./preflight-lote56.sql) passou 20/20, com terminal em [preflight-lote56-20260912.log](./preflight-lote56-20260912.log), exits nativo e wrapper zero. Ele confirma:

- `has_platform_permission(text,uuid)` com o ramo final do lote 50;
- `scope_targets()` e o reativador na forma final do hotfix lote 52;
- sincronizador na forma final do lote 55, sobre `scope_targets`, com mapeamentos por papel;
- `security definer`, `search_path` fixado e ACLs restritas;
- `institution_reader` somente com permissões ativas `%.read`;
- `pg_cron`, `cron.job` e `sweep_expired_now_publications(uuid,integer)` disponíveis;
- zero jobs existentes com o nome/comando de expiração do Agora.

A primeira formulação local do check 2 procurava incorretamente `internal_actor.institution_id`; a função final usa o parâmetro `institution_id` junto de `not internal_actor.is_internal`, como definido pelo lote 50. A definição materializada foi inspecionada, a asserção foi corrigida sem alterar o banco e a execução registrada passou 20/20.

Com isso, o espelho está comprovado para o preflight do lote 56. O ledger de uma linha continua explicitamente não autoritativo; aplicação, backup e ledger do lote 56 permanecem sob posse exclusiva do C0.
