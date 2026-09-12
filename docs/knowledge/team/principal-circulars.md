---
title: "Circulares privadas no Principal"
knowledge_id: "principal-circulars"
source: "specs/037-principal-circulars.md"
status: "validated"
generated_at: "2026-08-21"
updated_at: "2026-09-12"
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

Os blocos de texto, mídia e perguntas simples são ordenados e intercaláveis:
perguntas e mídia podem aparecer no meio do texto, não apenas no final
(spec037, reafirmada pelo Owner na ADR0034 Decisão20). O autor, o preview e
o leitor preservam essa ordem. Uma imagem aprovada de um compositor de teste
não certifica outro host nem prova salvar/publicar em produção.

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
No Superadmin web e mobile, o detalhe preserva o shell/menu hospedeiro e abre
na sua área de conteúdo, com retorno contextual `‹ Circular`; fechar ou usar
Escape restaura foco e posição de origem. A decisão do Owner de 09/09/2026
substitui a exceção de fullscreen que removia o shell nesse hospedeiro. Aplica-se
também aos viewers Agora/Momentos no Superadmin, sem definir o app Principal independente.

Publicar Circular usa a mesma família de composição do Principal que Publicar no
Acontece, Agora e Momentos, adaptada para título, texto, anexos e perguntas. Não
usa a anatomia de wizard administrativo do Superadmin. A geometria externa
preserva shell, contêiner direito e espaçamentos canônicos; o rodapé segue a
hierarquia responsiva de Criar/Editar Instituição.

Respostas podem ser individuais, por funcionário ou por criança. A política
compartilhada permite que qualquer responsável autorizado responda pela criança
sem criar respostas duplicadas entre responsáveis. Prazo é opcional e o
encerramento manual é auditado.

Mídia nova de Circulares usa o R2 privado definido pela ADR 0032, igual às demais
superfícies do MVP, com upload e leitura autorizados pelo backend, validação de
MIME real, bytes e checksum, e metadados, permissões, vínculos e auditoria no
Postgres. A exceção de bucket Supabase privado que a ADR 0027 concedia a
Circulares está superada: não há mais provedor de mídia próprio desta superfície.
PDF nunca usa Cloudflare Stream.
