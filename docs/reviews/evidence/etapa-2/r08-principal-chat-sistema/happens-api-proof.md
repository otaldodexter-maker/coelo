---
fonte: happens_api_smoke.py; contrato produtivo happens-media e RPCs; autorizacao C0 R08
status: medido-api-sem-aceite-ui
data: 2026-09-12
---

# Acontece — PNG privado por API

apps/superadmin → Coelo (Principal) → Acontece → publicar/ler/retirar →
acontece.create e subaceites de leitura/retirada. Prova serial autenticada em
producao, de 15:17:29 a 15:18:39 UTC, processo exit0. **Nao e prova pela UI**.

`happens-api-manifest.json` registra 23 verificacoes/operacoes aprovadas,
incluindo reconsultas; nao sao 23 testes ou action_ids distintos.

- PNG sintetico 16×16, 82 bytes, sem dados pessoais; prepare R2, PUT sem
  redirecionamento e finalize retornaram 200. MIME assinado foi preservado.
- Publicacao retornou 200; listagem nova recuperou a publicacao e seu ticket.
- Leitura autorizada retornou 200; GET privado recuperou SHA-256 identico ao
  original. Uma nova consulta ao servidor manteve a publicacao.
- Leitura anonima retornou 401; ticket aleatorio com ator autenticado retornou
  403. Nenhum segundo ator com escopo realmente negado estava disponivel:
  usuarios qa-r06-* sao Owner/platform. **Cross-tenant nao executado**.
- URL de leitura com TTL de 60 segundos passou a retornar 403 apos a espera
  real. URL/ticket/chave e senha nao foram registrados.
- Retirada pela RPC normal retornou 200; nova listagem nao continha o post.
  O master privado segue a retencao existente. Nao foi feita exclusao direta
  de banco, bucket ou auditoria. Sessao propria encerrada com 204.

Post sintetico: `f143a25d-c5ff-41e0-ac99-92d41c11e2b8`.
Ativo sintetico: `10e88d97-ee48-4453-ac01-b7a62c639d46`.
IDs preservados no manifest para reconciliacao do C0 ao fim da Etapa 2.

## Contexto medido antes da mutacao

O grupo `368a5cea-2bcf-4fa4-ad1f-18da58694551` retornou em consulta autenticada
200 a instituicao `d0c40000-0000-4000-8000-000000000001` e unidade
`d0c40000-0000-4000-8000-000000000002`. A referencia historica
`190dd028.../f5284f2f...` estava desatualizada. C0 confirmou nominalmente o
trio medido; o script conferiu a hierarquia novamente antes de gravar.

Usou-se o arquivo privado QA existente e a configuracao cliente do runtime
G0, apenas em memoria. Nenhuma senha, identidade, permissao ou fixture
estrutural foi criada/alterada. Audiencia sintetica: school_staff no grupo QA.

## Limites e proximo gate

Esta prova confirma transporte/persistencia/reautorizacao basica e retirada
por API, preservando o bloqueio de UI. Ainda faltam selecao do PNG, publicacao,
abertura, reload e retirada pelo fluxo visual normal. Nao ha proposta de
promocao E2E nem mudanca dos rastreadores por G4.
