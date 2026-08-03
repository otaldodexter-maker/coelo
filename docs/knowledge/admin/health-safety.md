---
title: Operação de Saúde e Segurança
knowledge_id: health-safety
source: specs/020-superadmin-health-safety.md
status: validated
generated_at: 2026-08-03
audience: admin
surfaces: [admin, health-safety, child-care]
visibility: internal
review_owner: Coelo Product
---

# Operação de Saúde e Segurança

Os dados de saúde e cuidado acompanham a criança, mas a instituição somente os
acessa quando possui contexto infantil ativo e autorização familiar válida.
Esse acesso não revela vínculos nem registros operacionais privados de outras
instituições.

Medicamentos enviados pelo responsável passam por Solicitado, Em análise,
Aprovado ou Recusado, Ativo e Encerrado. Notificações institucionais começam
somente após aprovação. Mudanças de dose, via, horários, período, instruções
relevantes ou instituição exigem nova análise e pausam doses futuras, preservando
o histórico.

Para administrar uma dose, um profissional autorizado primeiro assume a
tarefa. Os demais veem quem assumiu, e somente essa pessoa pode registrar o
resultado. Não administrado e Recusado exigem motivo. Lembretes, tolerância,
atraso e escalonamento pertencem à política institucional, não ao medicamento.
Alergias e restrições medicamentosas ativas devem permanecer destacadas, sem
diagnóstico automático por comparação de texto.

Alergias, restrições e itens do Perfil de Cuidado entram em vigor imediatamente,
preservam histórico e geram nova ciência aos perfis configurados. Perfil de
Cuidado organiza apoios, sinais e adaptações; não diagnostica nem descreve
neurodivergência, deficiência ou altas habilidades como doença. A ciência usa
Marcar como ciente e nunca o fluxo de assumir administração.

As telas institucionais futuras devem reproduzir essas regras sem importar
widgets administrativos do Superadmin. A central existente nesta fase é uma
demonstração local e não substitui autorização nem persistência server-side.
