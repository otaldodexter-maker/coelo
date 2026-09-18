---
title: "Pacote revisavel - interface publica do catalogo de midia privada"
source: "Reserva da plataforma comum de midia, grupo publicacoes-midia, rodada noturna de 09-10/09/2026"
status: "design-only; NENHUM SQL escrito; bloqueado por autorizacao nominal ausente"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O que falta no catalogo de midia privada

Este documento existe porque duas frentes registraram dependencia da plataforma
comum de midia e o Owner esta ausente desde 18:26, sem conceder autorizacao
nominal nova. O contrato manda preparar o pacote ate revisavel, registrar o
bloqueio e seguir. Isto e a parte revisavel: o desenho, nao o SQL.

## O que ja existe

`20260908160000_private_media_catalog_r2_v1` acrescenta a `public.media_assets`
o discriminador `catalog_kind`, cria `public.media_variants` e
`public.media_bindings`, e instala guardas em `app_private` com triggers. As
regras fisicas ja estao la: bucket fixo em `coelo-media-prod`, MIME restrito a
JPEG, PNG e WebP nas variantes, teto de 4 MB por variante, checksum SHA-256
obrigatorio e formato de chave opaca.

`20260909215000_private_media_catalog_chat_kind_v1`, ainda candidato,
acrescenta `chat-attachment` ao dominio e define a forma bem-formada dessa
linha, herdando limites de `public.chat_attachment_metadata`.

## O que NAO existe, para nenhum kind

**Interface publica.** Nao ha RPC e nao ha grant. O catalogo hoje e integridade,
nao contrato: nenhum ator autenticado consegue inserir, finalizar, ler ou
remover uma linha, seja de Forms, de chat ou de qualquer outro kind.

Isso e coerente e deliberado — os arquivos declaram isso —, mas significa que
`chat.attach` nao espera um discriminador, espera um contrato inteiro.

## Forma minima do contrato, se for aprovado

Quatro funcoes, todas `security definer` com `search_path` vazio, todas
recebendo `catalog_kind` explicito e recusando kind que o ator nao possa
escrever:

1. `prepare` — valida ator, tenant, escopo e capacidade do kind; cria a linha
   `pending`; devolve identificador de ativo, provedor e janela assinada. Nunca
   devolve bucket nem chave.
2. `authorize_finalize` — emite bilhete de finalizacao curto para o gateway,
   como Circulares e Momentos ja fazem.
3. `finalize` — confere bytes, MIME real e checksum ja conferidos pelo gateway,
   e promove a linha para `ready`. Idempotente por estado, como
   `finalize_circular_media_upload`: linha ja `ready` com mesmo tamanho e MIME
   retorna sem refazer.
4. `authorize_read` — reautoriza e devolve o minimo para o gateway assinar.

Mais `remove`, se a exclusao logica de anexo entrar no escopo.

## Invariantes que o contrato nao pode afrouxar

- Autorizacao sempre no servidor, por kind, com o ator do JWT.
- Negacao mascarada: nao distinguir "nao existe" de "existe e nao e seu".
- Nenhum bucket, chave ou provedor atravessando a fronteira do cliente.
- Chave de idempotencia apresentada pelo chamador, retida entre tentativas.
- MIME real conferido nos bytes pelo gateway, nunca no cabecalho declarado.

## Por que isto nao virou SQL esta noite

Aplicacao remota esta bloqueada ate o Owner voltar, entao o SQL nao poderia ser
aplicado nem provado. E a cadeia canonica nao replica localmente, entao nem
pgTAP local seria possivel. Escrever SQL nao revisavel contra banco nenhum, as
duas da manha, para desbloquear acao de outra frente, trocaria um bloqueio
declarado por um pacote sem prova.

## Perguntas que a aprovacao precisa responder

1. O catalogo unificado substitui os caminhos por dominio que ja funcionam,
   como o de Formularios, ou convive com eles?
2. `chat.attach` entra pelo catalogo unificado ou por um caminho proprio, como
   Circulares e Momentos tem?
3. A exclusao logica de anexo entra no escopo do contrato?
