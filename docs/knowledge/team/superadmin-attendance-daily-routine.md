---
title: Assiduidade e Rotina Diária produtivas no Superadmin
knowledge_id: superadmin-attendance-daily-routine-production
source: docs/superpowers/specs/2026-07-24-contextual-people-access-activities-attendance-design.md
status: validated
generated_at: 2026-08-11
revised_at: 2026-08-25
audience: team
surfaces: [superadmin, attendance, daily-routine]
visibility: internal
review_owner: Coelo Product
---

# Assiduidade e Rotina Diária produtivas no Superadmin

Assiduidade usa somente dados reais e autorização recalculada no Supabase. A
landing combina `Nova chamada` com dashboard analítico e operacional autorizado,
sem avisos de demonstração. Métricas, rankings, série temporal e tabela são
calculados no servidor dentro do escopo efetivo. Exportação real está fora do
MVP pela ADR 0031; o botão permanece visível e informa disponibilidade futura.
O wizard segue
`Contexto → Rotina diária → Chamada` e aceita hoje ou data anterior, nunca futuro.

Presença considera somente registros ativos de chamadas oficiais fechadas ou
corrigidas. Chamadas abertas, reabertas, canceladas, participantes ainda sem
registro e avisos familiares não entram no denominador. Sem registro oficial
válido, a interface apresenta `Dados insuficientes`. Chamadas pendentes são
sessões reais ainda não concluídas; o sistema não presume agenda inexistente.

O dashboard adapta a hierarquia ao escopo: plataforma pode descer por
instituição, unidade, turma, atividade, aluno e professor; escopos institucionais
ou profissionais começam no primeiro nível autorizado; família recebe apenas as
próprias crianças. A capability e o job auditado de exportação permanecem como
contrato futuro e não são implementados no MVP. Enquanto Admin, Professor e Principal não possuírem host produtivo, a
integração permanece somente no contrato compartilhado e no backend, sem tela
ou dados simulados.

A chamada separa o status da sessão do status de presença. Correção é revisão auditada, não status. Uma sessão fechada mostra seu snapshot e só pode ser reaberta com motivo, capability e versão esperada. Marcar todos afeta apenas alunos ainda não marcados; desmarcar todos desfaz somente o último lote ainda intacto e preserva exceções ou edições posteriores.

A rotina vinculada guarda versão imutável, origem e valor efetivo. Valores explícitos prevalecem sobre padrão do aluno, padrão da turma e valor inicial do modelo. Padrões são compartilhados no escopo autorizado e registram autor, versão e histórico. Campos obrigatórios pendentes bloqueiam o fechamento.

Pessoa é global e papéis são vínculos contextuais. Toda leitura e escrita valida tenant, instituição, unidade, turma ou atividade, criança, membership e capability no banco. `platform.read` nunca autoriza mutação; o Flutter apenas coleta intenção e renderiza estados reais.

No layout compacto do Superadmin, o header usa a superfície do tema, wordmark Coelo oficial, hamburger, utilidades e perfil. Drawer é usado em 375/768 e sidebar a partir de 840. A lista de alunos é contínua e empilha ações quando largura ou texto a 200% não comportam a linha.
