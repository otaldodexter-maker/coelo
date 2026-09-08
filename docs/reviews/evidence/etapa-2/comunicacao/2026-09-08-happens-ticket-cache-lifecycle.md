---
title: "Acontece — validade de leitura e cache da imagem"
source: "Recorte nominal do Coordenador; seis REDs root e revisão independente"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Reprodução e correção

Três respostas HTTP200 sintéticas com expires_in0/-1/0.5 eram aceitas, gerando
duração nula/negativa após truncamento. O adapter passa a rejeitar duração
inutilizável/não finita. Não foi inventado máximo TTL ou alterado servidor.

Mais três REDs comprovaram imagem retida após TTL e cache Flutter keepAlive após
troca de contexto/dispose. O consumidor captura o provider NetworkImage, remove
sua entrada no update/dispose/expiração e substitui a leitura vencida por estado
indisponível com retry explícito. Timer usa o expiresIn recebido; resume confere
a data calculada. Respostas tardias passam pela geração também sem callback de
contexto. Não há novo resgate automático ao vencer.

# Evidências

- Seis testes novos: três negativos do adapter e três de imagem/cache com
  fixture sintética já decodificada4×4 e controle positivo antes da transição.
- 56/56 não-golden da feature Acontece; 10/10 goldens de galeria/vídeo
  indisponível; analyzer4, format, diff e validador visual passaram.
- Revisão read-only sem P1/P2. Nenhum PNG atualizado; dez divergências históricas
  do feed completo continuam abertas e não foram reexecutadas para este delta.
- Assert intermediário setState retornando Future foi corrigido com bloco
  síncrono antes do GREEN; não foi ignorado nem reclassificado como baseline.

# Limites

TTL contado localmente a partir da resposta não prova expiração/revogação do
servidor. Testes não exercitam resume após suspensão real, bytes HTTP/decode
pendentes, cache HTTP/browser ou logout produtivo. Eviction é assíncrona do
provider; não é zeroização de todas as cópias de memória. Vídeo continua estado
indisponível, sem player novo. Sem SQL/Scope/decoder/entitlement/R2/Stream real.
Nenhuma nova decisão durável de produto para memória de conhecimento.
