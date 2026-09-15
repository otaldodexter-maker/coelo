# Catálogo de decisões

As ADRs registram decisões persistentes. O README é um roteador, não substitui
o texto da ADR. `accepted`/`approved` descreve a decisão editorial; não prova
que a implementação, RLS ou E2E exista. Para o trabalho atual, comece por
`docs/agent/current-state.md`.

## Overlays vigentes por tema

| Tema | ADR que deve ser conferida primeiro | Regra de leitura |
| --- | --- | --- |
| Aplicação remota e aceite do MVP | `0034-mvp-remote-application-and-acceptance-bar.md` | Régua de aceite, ambiente remoto e limites do MVP. |
| Mídia privada | `0032-mvp-private-media-r2.md` | R2 privado como master; catálogo e permissões no Postgres; Stream só quando aplicável. |
| Importação e exportação | `0031-mvp-import-export-buttons-only.md` | Controles podem aparecer; execução geral fica adiada, com a exceção de `forms.responses.export`. |
| Principal, host e controles de mídia | `0037-principal-host-context-and-media-controls.md` | Conferir junto da ADR 0032 e da spec da superfície. |
| Decisões registradas no fechamento da R13 | `0038-owner-decisions-etapa2-backlog-20260914.md` | Overlay de produto para a fila R14; não reabrir o que o Owner decidiu. |
| Escopo de Planos comerciais e recuperação de Auth | `0039-owner-scope-commercial-plans-auth-stage3-20260915.md` | Planos comerciais não entram no MVP; reader de Planos fica para V1/V2; recuperação/reset de Auth fica na Etapa 3; reader self da Conta permanece na R14. |
| Remoção explícita do Agora | `0040-agora-immediate-removal.md` | `agora.remove`: revogação lógica imediata, purge do objeto R2 e da cópia Stream, catálogo/recibo/auditoria preservados; implementação e aceite ainda pendentes. |
| Etapa 3 reservada | `0035-etapa3-mvp-contextual-access-and-app-delivery.md` | Planejamento aprovado; não iniciar automaticamente. |

## Base arquitetural

As ADRs `0001`–`0009` registram a base de monorepo, superfícies, tenancy,
permissões, dados, arquitetura Flutter/Astro e design. `0011`–`0019` registram
decisões de implementação e domínio que continuam sendo consultadas conforme
a spec da superfície. Não tratar a presença de uma ADR antiga como fila atual.

## Decisões substituídas ou com substituição parcial

`0010-private-media-r2.md`, `0026-happens-mvp-private-supabase-storage.md` e
`0030-mvp-private-media-supabase-storage.md` não devem orientar armazenamento
novo do MVP quando contradisserem a ADR 0032. ADRs `0022`, `0024`, `0025` e
`0027` podem conservar regras de domínio ou exceções; conferir a parte
específica antes de classificá-las como totalmente substituídas.

## Governança

- Em conflito, registrar as fontes em `docs/open-questions.md` e seguir a ADR
  explicitamente mais recente para o escopo afetado.
- Uma decisão do Owner que altera comportamento deve atualizar ADR, spec,
  estado corrente e projeção de conhecimento quando houver conhecimento
  durável.
- IDs ausentes no diretório são referências quebradas, não autorização para
  criar um documento com o mesmo número.
- Preservar histórico e proveniência; não deixar um histórico ser descoberto
  como instrução atual por falta de indicação de lifecycle.
