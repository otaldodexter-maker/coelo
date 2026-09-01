---
title: Dados determinísticos do preview Superadmin
knowledge_id: superadmin-development-dataset
source: apps/superadmin/lib/app/router/README.md
status: validated
generated_at: 2026-09-01
updated_at: 2026-09-01
audience: team
surfaces: [superadmin, development-preview, fixtures, navigation]
visibility: internal
review_owner: Coelo Product
---

# Dados determinísticos do preview Superadmin

As rotas `/dev` usam dados exclusivamente locais, determinísticos e reiniciáveis.
O catálogo contém 5 instituições, de uma a quatro unidades por instituição, de
uma a vinte e oito turmas por unidade, 30 atividades, 12 modelos de atividade, 400
pessoas e 6 modelos de rotina diária. Pessoas incluem crianças, responsáveis,
educadores e serviços, com exemplos de múltiplos filhos e de educador que também
é responsável.

Instituições, unidades, turmas e pessoas compartilham os mesmos identificadores
hierárquicos. Os filtros do diretório de Pessoas são derivados dessa hierarquia,
em vez de manter uma lista paralela reduzida.

Toda busca visível nas superfícies deste dataset filtra os dados locais de
verdade. Isso inclui instituições, unidades, turmas, modelos, atividades,
avaliações e conversas. O preview inclui turmas com e sem atividades e uma
caixa de conversas local que preserva envio e leitura apenas durante a sessão.

O dataset não representa Supabase, autorização, persistência ou dados reais.
Produção reutiliza as mesmas páginas e componentes visuais, recebe apenas fontes
autorizadas e permanece fail-closed quando a integração não está disponível.
Fixtures nunca podem ser usadas como fallback de uma falha produtiva.
