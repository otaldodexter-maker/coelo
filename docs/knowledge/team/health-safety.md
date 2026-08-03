---
title: Saúde e Segurança centrada na criança
knowledge_id: health-safety
source: specs/020-superadmin-health-safety.md
status: validated
generated_at: 2026-08-03
audience: team
surfaces: [superadmin, health-safety, permissions, database]
visibility: internal
review_owner: Coelo Product
---

# Saúde e Segurança centrada na criança

Medicamentos, alergias, restrições e Perfil de Cuidado pertencem à identidade
global da criança. Uma instituição só visualiza os dados globais autorizados
quando possui contexto infantil ativo e autorização familiar válida; registros
operacionais privados de outro tenant não se tornam globais.

Pessoa e Criança são filtros globais independentes. Instituição, Unidade e
Grupo/Atividade formam uma hierarquia contextual. Quando combinados, filtros
globais e contextuais produzem uma interseção sem tornar a identidade filha da
instituição.

Cada horário de medicamento tem exatamente um contexto responsável: uma
instituição ou a casa. A frequência diária é derivada dos horários. Alteração
relevante cria nova versão, invalida aprovações, retorna o medicamento para Em
análise e pausa doses institucionais futuras, sem alterar administrações
passadas. Claims evitam dose duplicada e são distintos dos recibos de ciência.

Alergias e restrições entram em vigor imediatamente e são inativadas, nunca
apagadas. O Perfil de Cuidado usa linguagem de apoio, não diagnóstica, e um
catálogo central extensível. Alterações nessas áreas geram nova ciência aos
perfis configurados.

No Superadmin, leitura sensível, aprovação, notificação, claim, resultado,
configuração, auditoria e correção excepcional são capacidades separadas. O
Owner pode corrigir com justificativa e trilha before/after, mas não pode
aprovar, assumir nem registrar doses em nome de uma instituição.

A implementação atual do Superadmin é demonstrativa e determinística. A
persistência produtiva depende da resolução de OQ-003, de autorização familiar
inversa explícita e do contrato futuro de documentos privados em R2.
