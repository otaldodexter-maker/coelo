---
title: "Spike Tecnico De Midia R2"
source: "docs/architecture/macro-architecture.md; docs/security/lgpd-security-media.md; docs/data/data-model.md; docs/product/prd-master.md; decisions/0010-private-media-r2.md"
status: "approved-for-spike"
generated_at: "2026-06-22"
approved_at: "2026-06-22"
approved_by: "Adriel B Coelho"
---

# Spike Tecnico De Midia R2

## Status

Spec aprovada para executar spike tecnico. Esta aprovacao autoriza pesquisa, desenho tecnico, prototipo descartavel e registro de evidencias; nao autoriza codigo de produto, deploy, migrations reais ou exposicao de midia real de criancas.

## Objetivo

Validar Cloudflare R2 como destino unico de midia privada desde o MVP, com bucket privado, URLs temporarias, metadados e permissoes no Postgres/Supabase, auditoria minima e limpeza de uploads orfaos.

## Problema

O PRD Master menciona Supabase Storage privado no MVP e R2 como opcao futura para midia pesada, CDN, archive e custo. A Arquitetura Macro consolida R2 privado desde o MVP para toda midia de produto. O spike deve reduzir essa incerteza tecnica antes de qualquer implementacao de produto.

## Resultado Esperado

Ao final do spike, engenharia deve conseguir decidir se R2 desde o MVP permanece viavel, quais limites operacionais precisam ser adotados e quais contratos minimos devem existir em `packages/coelo_database` e `packages/coelo_api`. O resultado deve atualizar `decisions/0010-private-media-r2.md` para aceitar, rejeitar ou ajustar a decisao.

## Superficies E Pacotes

- `packages/coelo_database`
- `packages/coelo_api`
- Futuro Media Gateway server-side
- Futuras Edge Functions/RPCs para comandos sensiveis

## Fontes

- `docs/architecture/macro-architecture.md`
- `docs/security/lgpd-security-media.md`
- `docs/data/data-model.md`
- `docs/product/prd-master.md`
- `docs/open-questions.md`
- `decisions/0010-private-media-r2.md`

## Escopo

- Desenhar o fluxo de upload privado: autorizacao server-side, chave de objeto definida pelo servidor, URL temporaria de envio, finalizacao e validacao.
- Desenhar o fluxo de leitura privada: sessao valida, contexto ativo, autorizacao do recurso, URL temporaria de leitura e negacao para usuario sem vinculo.
- Definir o contrato minimo de metadados: `tenant_id`, `institution_id`, owner, contexto, classificacao, tipo, tamanho, checksum, status, expira/remocao futura e vinculos de negocio.
- Definir estados de midia: solicitada, enviada, finalizada, disponivel, falhou, orfa, removida logicamente e expurgada.
- Validar que chaves R2, `service_role` e segredos equivalentes ficam exclusivamente no servidor.
- Validar estrategia para uploads orfaos: deteccao, fila/rotina de limpeza, auditoria e janela de tolerancia.
- Registrar evidencias tecnicas suficientes para decidir a ADR.

## Fora De Escopo

- Codigo de produto em Flutter ou Astro.
- UI final de upload, galeria, Moments, chat, rotina ou feed.
- Migrations definitivas sem spec tecnica posterior.
- Deploy de infraestrutura ativa de producao.
- Uso de midia real de criancas, familias ou instituicoes.
- Definicao final de retencao juridica de midia, rotina ou chat.
- Transcodificacao pesada, streaming adaptativo ou Cloudflare Stream.

## User Scenarios E Testes

### Cenario 1 - Upload privado autorizado (P1)

Como equipe autorizada de uma instituicao, quero enviar uma midia para um contexto permitido sem expor credenciais, para que fotos, videos e anexos privados possam existir no produto com controle institucional.

**Teste independente:** simular uma sessao autorizada, solicitar URL temporaria de upload, concluir envio, finalizar metadados e verificar que o objeto fica associado ao tenant e contexto corretos.

**Aceite:** dado um usuario com membership valido, quando ele solicita upload para um contexto permitido, entao o servidor emite uma autorizacao temporaria sem expor segredo e a finalizacao registra metadados verificaveis.

### Cenario 2 - Leitura privada autorizada (P1)

Como responsavel ou equipe com vinculo valido, quero acessar uma midia privada somente enquanto minha autorizacao existir, para que o conteudo infantil nao tenha URL publica permanente.

**Teste independente:** simular leitura por usuario autorizado e confirmar emissao de URL temporaria de leitura com expiracao curta.

**Aceite:** dado um usuario com vinculo ao recurso, quando ele solicita acesso a midia, entao o servidor valida contexto, permissao e classificacao antes de emitir URL temporaria.

### Cenario 3 - Acesso cruzado negado (P1)

Como responsavel sem vinculo com aquela crianca, grupo ou tenant, nao devo conseguir acessar midia por ID, path ou URL direta.

**Teste independente:** tentar acessar a mesma midia a partir de tenant, instituicao ou membership sem direito.

**Aceite:** dado um usuario sem vinculo, quando ele solicita leitura ou finalizacao de midia alheia, entao a tentativa falha, nao gera URL valida e registra evento de negacao sem logar o conteudo.

### Cenario 4 - Limpeza de upload orfao (P2)

Como operador tecnico do Coelo, quero que uploads incompletos sejam detectados e limpos, para reduzir custo e evitar objetos sem ownership claro.

**Teste independente:** criar uma autorizacao de upload sem finalizacao e validar que a rotina proposta identifica o objeto como orfao e define acao de limpeza.

**Aceite:** dado um upload expirado sem finalizacao, quando a rotina de limpeza roda, entao o item entra em estado orfao/removido conforme regra registrada e gera auditoria minima.

## Dados E Entidades

- `media_assets`: registro logico do arquivo, owner, tenant, instituicao, contexto, classificacao, status, tamanho, MIME, checksum, object key e timestamps.
- `media_variants`: thumbnail, versao comprimida e transformacoes futuras quando aprovadas.
- `media_links`: vinculo entre midia e post, Now, Moment, rotina, chat ou agenda.
- `media_access_classification`: classificacao privada por tenant, grupo, crianca, familia ou conteudo sensivel.
- `media_consent_records`: autorizacoes ou restricoes de imagem quando aplicavel.
- `audit_logs`: eventos sensiveis de solicitacao, finalizacao, leitura, negacao, limpeza e erro.

## Permissoes E Tenant

- Toda operacao deve partir de sessao valida, pessoa ativa e contexto ativo.
- Acesso deve considerar `tenant_id`, `institution_id`, membership, papel contextual, vinculo com unidade/grupo/crianca, audiencia do recurso e restricoes de consentimento.
- RLS/policies ou camada server-side equivalente devem impedir acesso cruzado entre tenants.
- Cliente nunca recebe `service_role`, chave R2, segredo de terceiro ou path previsivel suficiente para bypassar autorizacao.
- UI pode ocultar acoes, mas a decisao final precisa ocorrer no backend ou banco.

## UX States

O spike nao cria UI final. Ainda assim, o plano tecnico deve prever estados para interfaces futuras: aguardando autorizacao, enviando, processando/finalizando, disponivel, expirado, falhou, sem permissao, removido e inacessivel por politica.

## Eventos, Logs E Notificacoes

- `media_upload_requested`
- `media_upload_finalized`
- `media_upload_failed`
- `media_read_authorized`
- `media_read_denied`
- `media_orphan_detected`
- `media_orphan_cleanup_executed`

Logs devem registrar IDs, tenant, instituicao, ator, contexto, status e motivo tecnico; nao devem registrar conteudo da midia, URL assinada completa ou segredo.

## Criterios De Aceite

- O conflito entre PRD Master e Arquitetura Macro permanece registrado em `docs/open-questions.md`.
- O spike descreve pelo menos um fluxo de upload, um fluxo de leitura, uma tentativa de acesso negado e uma rotina de limpeza de orfaos.
- Toda URL de upload/leitura proposta e temporaria, emitida por camada server-side e sem credenciais expostas ao cliente.
- Metadados e ownership ficam no Postgres/Supabase; R2 guarda apenas bytes, variantes e objetos temporarios.
- Acesso cruzado entre tenants deve falhar em teste documentado.
- Nenhuma midia infantil usa bucket publico ou URL publica permanente.
- O resultado do spike atualiza a ADR `decisions/0010-private-media-r2.md`.

## Testes Requeridos

- Teste de autorizacao de upload permitido.
- Teste de finalizacao com tamanho, MIME e checksum esperados.
- Teste de leitura permitida para usuario com vinculo.
- Teste de leitura negada para usuario sem vinculo, tenant errado ou membership removido.
- Teste de URL expirada solicitando nova autorizacao em vez de reutilizar assinatura antiga.
- Teste de upload orfao detectado e encaminhado para limpeza.
- Teste de ausencia de `service_role`, chave R2 ou segredo equivalente em qualquer cliente.

## Riscos

- R2 pode aumentar complexidade do MVP se o Media Gateway nao for simples e unico.
- Custos de midia podem crescer sem limites, compressao, thumbnails e lifecycle.
- Retencao juridica segue pendente e nao pode ser inventada pelo spike.
- URL temporaria com expiracao longa demais pode enfraquecer a privacidade.
- Falta de testes cruzados pode permitir vazamento entre tenants.

## Perguntas Abertas

- OQ-002: resultado do spike ainda precisa aprovar ou ajustar a decisao final de R2.
- OQ-003: revisao juridica segue necessaria antes de producao.
- OQ-009: limites de midia, transformacoes, expurgo e limpeza de orfaos precisam ser detalhados a partir das evidencias do spike.
