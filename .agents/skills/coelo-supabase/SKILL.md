---
name: coelo-backend
description: Use when a Coelo task involves backend, Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Realtime, Cloudflare R2, Stream, Workers, Media Gateway, migrations, remote persistence, backend security, or backend completion.
---

# Coelo Back-end

> O caminho desta skill permanece `coelo-supabase/` por compatibilidade com
> documentos e prompts antigos. O nome e o contrato canônicos são **Coelo
> Back-end** (`coelo-backend`).

## Princípio e limite

Tratar o backend Coelo como a soma dos provedores realmente usados pela ação:

- **Supabase/Postgres:** identidade, sessão, dados relacionais, vínculos,
  autorização, RLS, metadados, auditoria, RPCs, Edge Functions e Realtime;
- **Cloudflare R2:** origem privada dos binários novos do MVP;
- **Cloudflare Stream:** cópia privada e removível para vídeo HOT somente onde
  a política do produto exigir;
- **Media Gateway server-side:** fronteira que reautoriza o ator e coordena
  Supabase e Cloudflare sem expor segredo ao cliente.

Uma ação sem mídia não precisa de Cloudflare. Uma ação com mídia ou exportação
não pode ser `done` apenas porque o Supabase está verde.

## Leitura e skills obrigatórias

Antes de analisar, estimar ou editar:

1. Ler `AGENTS.md` e integralmente
   `docs/reviews/coelo-supabase-pendencias.md`.
2. Ler specs, ADRs, decisões e perguntas abertas da superfície; para mídia,
   começar por `decisions/0032-mvp-private-media-r2.md`.
3. Usar `coelo-knowledge` quando comportamento, domínio, segurança, UX ou
   documentação observável mudar.
4. Usar `rtk` em comandos com wrapper compatível.
5. Para Supabase, usar a skill oficial `supabase`, o plugin oficial disponível
   e `supabase-postgres-best-practices`; consultar documentação atual antes de
   afirmações temporais ou implementação.
6. Para Cloudflare, usar `cloudflare`; usar `wrangler` e
   `cloudflare:workers-best-practices` quando houver Worker, binding, recurso ou
   deploy. Se a tarefa envolver gerenciamento operacional de vários serviços
   Cloudflare (deploy, DNS, rotas, KV, R2, Pages) em um fluxo único, usar também
   `cloudflare-manager` como fallback para guiar a orquestração; manter a decisão
   final em `cloudflare`, `wrangler` e `cloudflare:workers-best-practices` conforme
   o objetivo técnico.
7. Consultar `coelo-frontend-backend` para os limites da prova integrada. Ler
   também os rastreadores de Front-end e integração quando a conclusão da tela
   depender do cliente.

Review, auditoria e diagnóstico autorizam somente leitura. Mutation, migration,
deploy, configuração ou recurso remoto exigem autorização para o ambiente e o
pacote exatos. O projeto Supabase `coelo` é produção; autorização anterior de
outro pacote não se transfere. Todo recurso Supabase ou Cloudflare remoto do
Coelo deve ser tratado como produção; não presumir DEV/homologação. Validar
localmente primeiro e aplicar no remoto somente o pacote nominal, forward-only,
revisado, serializado e com plano de recuperação.

## Segurança de credenciais

- Nunca colocar `service_role`, secret key, token Cloudflare, credencial R2,
  signing key, segredo de Worker ou URL temporária em Flutter, Astro, Git,
  asset, log, evidência ou parâmetro permanente.
- Guardar segredos somente no secret store do ambiente. Arquivos locais de
  segredo ficam ignorados; exemplos contêm apenas nomes e valores fictícios.
- Token que apareceu em conversa, anexo, log ou diff é comprometido: não usar,
  não testar, não copiar e não pedir novamente em chat; solicitar rotação e
  provisão de menor privilégio diretamente no secret store.
- Presigned URL é credencial temporária: operação, objeto, MIME e TTL mínimos;
  CORS não substitui autorização.

## Comunicação e progresso

Traduzir na primeira ocorrência: Auth (entrada/sessão), RLS (segurança por
linha), RPC (função do banco), Edge Function/Worker (função no servidor),
`fail-closed` (nega por segurança), `local-green` (prova local),
`remote-green` (provedores remotos aplicáveis comprovados) e `done` (fim do
backend da ação).

Calcular o progresso geral sobre todas as famílias e `action_id` do rastreador,
e o recorte separadamente. Não inferir tempo usado pelo percentual. Se faltarem
horários/evidências, usar `não calculável ainda` e registrar o próximo dado
necessário.

```text
Progresso geral conhecido — Concluído: 21,43% (3/14 unidades)
Progresso geral conhecido — Restante: 78,57% (11/14 unidades)
Tempo usado no trabalho geral concluído: ...
Tempo estimado para finalizar o backlog geral: ...
Progresso do recorte — Concluído: ...
Progresso do recorte — Restante: ...
Tempo usado no trabalho concluído no recorte: ...
Tempo estimado para finalizar o recorte: ...
Base do cálculo: IDs/gates, evidência, provedores e horário de referência.
```

### Limite de `done` do Back-end

`done` encerra tudo que pertence ao backend da ação, sem exigir Front-end:

1. contrato e validação de entrada não confiável;
2. sessão, ator, capability, tenant, ownership e hierarquia;
3. schema/migration, RLS deny-by-default, grants mínimos e caminho server-side;
4. persistência, idempotência/concorrência, auditoria e efeitos laterais;
5. permitido, negado, revogado, tenant A/B e IDOR/BOLA;
6. reload por cliente de teste e resposta estável;
7. todos os provedores aplicáveis comprovados no remoto autorizado;
8. regressão, Advisors/observabilidade, cleanup e rastreador atualizado.

Para mídia/exportação, acrescentar: objeto R2 privado real, metadados
consistentes no Supabase, URL curta após reautorização, expiração/revogação,
retenção e limpeza de órfãos. Para vídeo HOT, acrescentar Stream privado,
estado de processamento, playback autorizado, fallback R2, retry e remoção da
cópia Stream sem remover o master R2.

## Contrato de abertura

Se o usuário ainda não informou tempo, perguntar quanto quer investir. Se já
definiu `Completa`, `todas as pendências` ou continuidade até conclusão, não
perguntar novamente: inventariar, recalcular e prosseguir dentro da autoridade.

| Nível | Inclui | Referência inicial por unidade simples |
| --- | --- | --- |
| `Básica` | Correção pequena, RED e teste local mínimo | 30–90 min |
| `Intermediária` | Básica + contrato, autorização e negativas aplicáveis | 2–6 h |
| `Avançada` | Intermediária + cross-tenant e remoto autorizado | 1–2 dias |
| `Completa` | Avançada + regressão, auditoria, cleanup e fechamento | 2–5 dias |

As faixas são somente referência pré-inventário. Reduzir o recorte quando o
tempo não comportar o pacote seguro; nunca retirar testes, autorização ou
cleanup para caber. Registrar objetivo, apps afetados, incluído/fora, ordem,
parada, evidências e ETA por fatia.

## Políticas vigentes de mídia e exportação

- Usar os buckets privados de produção definidos na ADR 0032:
  `coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod`.
- A plataforma é compartilhada por Superadmin, Admin e Principal. Não criar
  bucket, chave, gateway ou catálogo por app; a Etapa 2 conecta somente
  Superadmin, preservando contratos em `coelo_domain`/`coelo_api` para os
  consumidores posteriores. Site não acessa mídia privada.
- A chave R2 única e estável é emitida pelo servidor, sem PII e sem árvore
  global `v1`/`v2`:
  `<scope>/<scope_uuid>/<domain>/<entity_type>/<entity_uuid>/<purpose>/<asset_uuid>/<rendition>/<object_uuid>.<ext>`.
  Substituição cria novo ativo/objeto; versão e histórico ficam no Postgres.
  Postgres mantém ativos, variantes, bindings, entregas Stream, uploads, jobs e
  auditoria; a chave nunca decide autorização.
- Perfil/avatar, capas, logos, eventos, mapas, fotos de local, imagens de
  perguntas/respostas e anexos pertencem à entidade/finalidade correspondente.
  PDF fica em `coelo-documents-prod`, nunca no Stream. Temporários, quarentena,
  processamento e XLSX ficam em `coelo-transient-prod` com lifecycle.
- Aceitar imagem JPEG/PNG/WebP; HEIC/HEIF somente após conversão. Validar MIME
  real, bytes, dimensões, pixels, checksum e política da finalidade no servidor.
  SVG de usuário e GIF animado ficam recusados no MVP. Aplicar os limites por
  finalidade da ADR 0032 e remover EXIF/GPS por padrão.
- **Agora:** master no R2; Stream HOT por até 24 h quando necessário. Após a
  janela, apagar somente a cópia Stream.
- **Momentos:** R2 por padrão; Stream apenas por publicação nova/popular ou
  tráfego medido, sem janela fixa arbitrária; permitir nova promoção.
- **Acontece:** R2 por padrão; Stream somente por necessidade medida.
- **Chat:** R2; Stream não é requisito do MVP.
- **Formulários:** `forms.responses.export` gera um arquivo XLSX com as
  respostas do formulário. Não gerar uma exportação por resposta e não
  inventar CSV, ZIP ou PDF. O artefato fica privado no R2.
- Demais importações/exportações reais do Superadmin ficam pós-MVP; botões
  permanecem visíveis e honestamente indisponíveis.

## Execução e evidência

Para cada item:

1. reproduzir o RED e nomear ator, tenant, recurso, capability e provedores;
2. rastrear schema, migration, grants, RLS, RPC/Edge/Worker, R2 e Stream;
3. escrever o teste antes da correção e provar sucesso e negativas;
4. fazer replay/cutover forward-only na ordem coordenada;
5. provar o pacote no remoto de produção autorizado, com dados sintéticos
   minimizados e cleanup comprovado;
6. atualizar o rastreador no mesmo turno com ação, estado, evidência, bloqueio
   e ETA.

Não habilitar RLS em lote sem policies e testes: a auditoria remota registrou
34 tabelas `app_private` com RLS desabilitado, um P0 que exige correção fatiada.
Não aplicar cauda de migrations em lote diante do drift de ledger.

## Estados e encerramento

- `audited`: inventariado e aberto;
- `fail-closed`: seguro, porém indisponível;
- `blocked-decision`/`blocked-environment`: depende de decisão ou ambiente;
- `local-green`: provas locais verdes;
- `remote-green`: todos os provedores remotos aplicáveis e negativas verdes;
- `done`: todos os gates do backend da unidade comprovados;
- `regressed`: evidência anterior deixou de valer.

Supabase verde sem R2/Stream aplicável não é `done`; R2 verde sem RLS,
autorização e metadados também não é. No encerramento, diferenciar atividade
concluída, unidade Backend `done` e produto ainda pendente.
