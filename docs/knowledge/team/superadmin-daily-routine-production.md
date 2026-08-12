---
title: Rotina diária produtiva no Superadmin
knowledge_id: superadmin-daily-routine-production
source: specs/025-superadmin-daily-routine-models-applications-launches.md
status: validated
generated_at: 2026-08-12
audience: team
surfaces: [superadmin, daily-routine]
visibility: internal
review_owner: Coelo Product
---

# Rotina diária produtiva no Superadmin

Rotina diária separa três agregados: `Modelo` versionado, `Rotina aplicada` com
herança instituição → unidade → turma e `Lançamento` cotidiano auditável. Origem,
valor herdado, valor efetivo e personalização reversível são explícitos.

Campos aceitam texto curto, texto longo, número, sim/não, escolha única e escolha
múltipla. Opções têm identidade e ordem próprias, nunca são CSV. O valor inicial
é tipado; número respeita mínimo/máximo. Ramificações aceitam sim/não e escolhas,
rejeitam ciclos e terminam no quarto nível.

O diretório usa as abas `Modelos`, `Rotinas` e `Lançamentos`. O editor reutiliza
o frame canônico de Instituições e mantém reordenação equivalente por ponteiro,
teclado e toque. Mídia, fotos e imagens de apoio não pertencem a este contrato.

Toda leitura e escrita parte do escopo autorizado no Supabase. RLS, grants,
hierarquia, membership, capability, versão otimista, idempotência e auditoria são
recalculados no backend. Publicação e correção exigem AAL2. O Flutter não autoriza
operações e falha fechado com estados loading, empty, no-results, failure,
unauthorized, not-found e conflict.

Importação e exportação, quando habilitadas, são exclusivamente da configuração
XLSX v1 (`Modelos`, `Seções`, `Campos`, `Opções`, `Condições`, `Aplicações`).
Lançamentos, respostas e dados infantis nunca entram no arquivo.
