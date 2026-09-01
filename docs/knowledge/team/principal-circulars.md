---
title: "Circulares privadas no Principal"
knowledge_id: "principal-circulars"
source: "specs/050-principal-ui-ux-closure.md"
status: "validated"
generated_at: "2026-08-21"
updated_at: "2026-09-01"
audience: "team"
surfaces: [principal, perfil, acontece, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Circulares privadas no Principal

Circulares são comunicações institucionais privadas e versionadas. Possuem
título de até 120 caracteres, texto total de até 10.000, quatro anexos e dez
perguntas simples de escolha única ou múltipla. Não são posts comuns, popups ou
formulários completos.

No diretório administrativo, mobile usa tile de criação e cards compactos;
tablet e desktop usam faixa de criação e tabela no padrão de Instituições. Não
há botão laranja isolado no topo nem seletor manual de visualização. As tabs
separam Todas, Rascunhos, Agendadas, Publicadas e Encerradas.

Uma Circular publicada aparece na aba `Circulares` do Perfil e como projeção no
Acontece, sem duplicar o conteúdo canônico. Revisões publicadas são imutáveis;
uma correção preserva o histórico, mantém a posição original no feed e exige
novas respostas.

A entrada de Circulares pertence à área Coelo (Principal), e não à seção
Comunicação do Superadmin. A mudança de navegação não altera as regras privadas
de autoria, audiência, versionamento ou resposta.

No web, a prévia da projeção no Acontece fica oculta por padrão e abre em popup
somente por ação explícita. Ela não reserva uma coluna lateral permanente nem
comprime o conteúdo do Perfil. Essa decisão é específica da consulta da Circular
no Perfil e não remove o preview lateral dos fluxos de publicação aprovados.
Em compacto, o detalhe abre fullscreen sem cabeçalho ou dock global e apresenta
retorno contextual `‹ Circular`; fechar ou usar Escape restaura foco e posição
de origem.

Publicar Circular usa a mesma família de composição do Principal que Publicar no
Acontece, Agora e Momentos, adaptada para título, texto, anexos e perguntas. Não
usa a anatomia de wizard administrativo do Superadmin. A geometria externa
preserva shell, contêiner direito e espaçamentos canônicos; o rodapé segue a
hierarquia responsiva de Criar/Editar Instituição.

Respostas podem ser individuais, por funcionário ou por criança. A política
compartilhada permite que qualquer responsável autorizado responda pela criança
sem criar respostas duplicadas entre responsáveis. Prazo é opcional e o
encerramento manual é auditado.

Mídia usa o bucket Supabase privado definido pela ADR 0027, com upload e leitura
assinados pelo backend, validação do arquivo e metadados no Postgres. A exceção
é exclusiva de Circulares e não muda o provedor das outras superfícies.
