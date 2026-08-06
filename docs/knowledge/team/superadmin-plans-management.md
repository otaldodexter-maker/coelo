---
title: Gestão de Planos do Superadmin
knowledge_id: superadmin-plans-management
source: specs/022-superadmin-plans-ui.md
status: validated
generated_at: 2026-08-05
audience: team
surfaces: [superadmin, admin, principal, plans]
visibility: internal
review_owner: Coelo Product
---

# Gestão de Planos do Superadmin

O catálogo de planos é global ao Coelo e sua operação permanece manual no MVP.
A experiência local do Superadmin possui diretório em Cards e Tabela, busca por
nome ou código, segmentos **Todos**, **Ativos** e **Arquivados**, paginação e
ações auditáveis de arquivar e restaurar. Não existe exclusão permanente nessa
superfície.

Criar plano usa **Identificação**, **Capacidades incluídas**, **Limites** e
**Revisão**. Editar acrescenta **Instituições vinculadas** antes da revisão. O
código é estável e não pode ser alterado na edição. Instituições vinculadas,
status da subscription, datas e overrides de unidade são somente leitura; uma
troca de plano continua pertencendo ao fluxo da instituição.

Plano e entitlement descrevem a oferta contratada. Perfil e permissão autorizam
a pessoa, e o escopo contextual restringe onde ela pode agir. A interface de
Planos não concede autorização a pessoas e não reproduz ações de permissão como
Ver, Editar ou Excluir por analogia. Capacidades usa uma matriz privada orientada
pelo catálogo comercial. Uma variação de ação só pode aparecer quando for um
entitlement comercial canônico; até existir catálogo granular aprovado, a
matriz mostra apenas **Incluído no plano**. O acesso efetivo depende da
interseção desses domínios.

Os limites exibidos são informativos e não causam bloqueio automático no
Flutter. A quantidade de responsáveis por criança não é limite técnico ou
comercial vigente. Preço, moeda, cobrança, pagamento, importação e exportação
ficam fora da experiência.

Capacidades e limites do protótipo continuam fixtures locais. Elas não formam
catálogo comercial produtivo e não autorizam schema, RLS, policies ou
enforcement. A integração produtiva depende de catálogo canônico de
entitlements, contrato físico de limites e autorização server-side específica.

Criar, editar, arquivar e restaurar exigem motivo de auditoria. Conflitos
preservam o draft. Planos em uso exibem impacto, mas arquivamento não altera
subscriptions nem experiências operacionais automaticamente.
