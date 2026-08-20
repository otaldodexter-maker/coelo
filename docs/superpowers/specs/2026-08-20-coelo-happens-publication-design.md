---
source: referência visual canônica e plano aprovado de Publicação do Acontece
status: approved
generated_at: 2026-08-20
---

# Publicação do Acontece

## Objetivo

Oferecer criação social segura de posts do Acontece com mídia dominante, legenda, contexto, audiência, rascunho, agendamento e prévia ao vivo.

## Superfícies e responsividade

A implementação executável fica no preview do Superadmin em `/dev/principal-happens/publish`. Em largura compacta, o composer é linear e a prévia permanece após os campos. No tablet, composer e prévia ficam lado a lado. No desktop, rail, composer central e prévia lateral reproduzem a anatomia canônica.

## Domínio e segurança

Um post pertence ao tenant e à instituição, pode restringir unidade e turma e guarda autoria global e membership contextual. Audiências permitidas são Famílias, Alunos, Equipe escolar e Somente responsáveis. Rascunho usa versão otimista. Publicação exige `happens.posts.create` e `happens.posts.publish`; RPCs derivam ator e tenant da sessão e mutações diretas ficam revogadas.

Até seis JPG, PNG, WebP ou MP4 podem ser selecionados. O MVP usa a exceção temporária da ADR 0026: Storage privado, gateway server-side, validação de assinatura e sem URL pública.

## Estados

Inicial, carregando, editando, autosalvando, salvo, enviando mídia, publicando, agendado, sucesso, conflito, erro recuperável e acesso negado.

## Fora de escopo

Momentos, Agora, edição avançada, moderação completa e notificações de entrega.

## Aceite

- estrutura fiel em 375, 768 e 1440 px, sem overflow;
- mídia, legenda, contexto, audiência, agendamento, rascunho, CTA e prévia funcionais;
- acesso cross-tenant e por ID negado no backend;
- análise estática, testes Flutter, SQL/Edge e validadores Coelo executados quando o runtime estiver disponível.
