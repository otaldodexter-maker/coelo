---
title: "Convites — confirmação e negação no detalhe"
source: "Prompt 4 Etapa 2 E2E; contratos de isolamento existentes; revisão read-only e testes Flutter"
status: "local-green; decisões de emissão e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte

Detalhe de Convites no Superadmin: revogar, reenviar e resultado/link. Objetivo:
impedir que confirmação antiga comande outro contexto e descartar dados locais
após negação definitiva. Ordem: REDs, guards/purge, regressão, review e commit.
Não alterar issuer/capabilities, OQ039/spec047, SQL ou composição. O default
`allowCommands=false` continua intacto. Os testes habilitam comandos explicitamente.

# RED e correção

Cinco REDs reproduzidos antes do patch: confirmar revogação após troca de
repository, ida A→B→A e desabilitação de comandos ainda executava mutation;
negação em resend/revoke preservava detalhe/link anterior.

Os três casos de confirmação receberam segundo RED: além de impedir comando,
o diálogo antigo deve desaparecer. A página mantém referência da rota própria
e remove somente ela, depois do frame, nas trocas/dispose/negação. O builder
também rejeita contexto obsoleto antes da primeira montagem. Tema, scrim e foco
fechado são preservados; movimento reduzido é respeitado.

Comandos capturam repository e geração antes do await. Mudanças de ID,
repository ou allowCommands invalidam a geração e receipts locais. Negação
definitiva remove detalhe/link, request IDs e busy; falhas transitórias conservam
retry. Duas contraprovas adicionais: negação tardia não limpa B; indisponibilidade
transitória permite tentativa explícita posterior.

# Evidências e limites

- 58/58 testes não-golden de Convites GREEN, incluindo 15 do detalhe.
- Analyzer dos três arquivos: verificação final sem issues; um aviso de chaves
  no guard foi corrigido antes da entrega.
- Format, diff check e validador de contratos visuais GREEN.
- Review independente read-only: sem bloqueantes. Dispose com outra rota acima
  permanece cobertura complementar; remoção restrita revisada por inspeção.
- Nenhum PNG, baseline, segredo, SQL, recurso Supabase/Cloudflare ou rastreador
  oficial alterado. Não houve teste de revogação real, envio de convite ou e-mail.
- Não é correção de IDOR server-side nem prova de E2E. Políticas de emissão e
  gates de produção permanecem abertos; não habilitar comandos por esta evidência.
- Memória: restaura isolamento aprovado, nenhuma nova decisão/artigo durável.
