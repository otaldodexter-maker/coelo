---
source: "specs/013-ui-packages-componentization.md"
status: "reserved-package"
generated_at: "2026-07-22"
---

# coelo_ui_superadmin

Componentes Flutter especificos da operacao global Coelo no Superadmin:
shell global, navegacao de plataforma, suporte interno, auditoria global,
governanca e visoes acima dos tenants.

## Regra

Use este pacote somente quando o componente nao pertencer ao Admin e depender
do contexto global da plataforma Coelo. Um unico uso continua local enquanto o
padrao for experimental; um padrao oficial pode ser promovido sem segundo
consumidor quando uma spec aprovada exigir essa fronteira.

## Status

Pacote reservado. A shell atual permanece no app ate haver necessidade concreta
de extracao.
