---
title: Protótipos operacionais do Superadmin
knowledge_id: superadmin-operational-prototypes
source: docs/superpowers/specs/2026-08-03-superadmin-operational-surfaces-prototype-design.md
status: validated
generated_at: 2026-08-03
updated_at: 2026-08-05
audience: team
surfaces: [superadmin, plans, imports, invites, notices, audit]
visibility: internal
review_owner: Coelo Product
---

# Protótipos operacionais do Superadmin

Planos, Importações, Convites, Avisos e Auditoria devem nascer primeiro como
experiências locais navegáveis em rotas `/dev` do Superadmin. Os dados ficam em
memória durante a sessão e reiniciam ao recarregar. Esse recorte não autoriza
Supabase, migrations, RLS, RPCs, envio, arquivos, aceite ou auditoria reais.

Os diretórios reutilizam a composição aprovada de Instituições. Não existe ação
de criar no cabeçalho: cards usam primeiro card tracejado e tabelas usam uma
faixa separada antes da tabela. Auditoria é somente leitura e não possui ação de
criação ou exportação.

Planos administra o catálogo, recursos e limites com os fixtures Coelo
Essencial, Coelo Conecta, Coelo Cuidado e Coelo Integral. Plano utilizado pode
ser arquivado, mas exclusão definitiva é reservada a plano nunca utilizado.

Importações demonstra Instituições, Unidades, Grupos, Pessoas e Usuários
internos em um wizard com mapeamento, estratégia, revisão, conflitos e resultado.
Convites atende todos os públicos identificados em um diretório exclusivamente
tabular. A busca usa destinatário mascarado e contexto/papel; os filtros locais
são status, público, canal e criação. A criação mantém sete etapas, validade de
48 ou 72 horas e revisão mascarada. Não existe edição sem operação de atualização
no repositório: convites emitidos usam detalhe somente leitura, sem token ou link
completo. Reenvio é permitido para pendentes ou expirados, invalidando o link
fake anterior; revogação é permitida somente para pendentes e exige confirmação
negativa. Em mobile e tablet claros, as superfícies de Convites usam fundo-base
simples em "colorScheme.surface".

Avisos cria popups globais ou segmentados por hierarquia e pessoa. Pode apenas
informar, exigir confirmação ou exigir checkbox de aceite. Aviso obrigatório
bloqueia a navegação no modo de simulação, permite sair do app e reaparece até o
aceite. Auditoria consulta eventos fictícios e minimizados gerados pelas demais
features, sem PII, mensagens integrais, tokens ou conteúdo de arquivos.

As composições respondem à largura disponível com `LayoutBuilder` e são
validadas em 375, 768, 1024 e 1440 px, light/dark, texto a 200%, teclado, foco,
semântica e reduced motion.
