---
source: referência visual canônica e plano aprovado de Publicação do Acontece
status: approved
generated_at: 2026-08-20
updated_at: 2026-08-31
---

# Publicação do Acontece

## Objetivo

Oferecer criação social segura de posts do Acontece com mídia dominante, legenda, contexto, audiência, rascunho, agendamento e prévia ao vivo.

## Superfícies e responsividade

A implementação executável fica no preview do Superadmin em `/dev/principal-happens/publish`. A proposta específica recebeu aprovação visual do Owner em 2026-08-31. Em largura compacta, o composer é linear e prioriza mídia, legenda, público e contexto. No tablet, o editor permanece linear e ganha respiro sem comprimir uma prévia concorrente. No desktop, rail, composer central e prévia lateral reproduzem a anatomia canônica.

Todos os fluxos `Publicar` do Principal compartilham o contrato externo aprovado
em 2026-08-31: shell e contêiner direito canônicos, insets tokenizados e rodapé
responsivo de Criar/Editar Instituição. No amplo, `Cancelar` fica à esquerda e
rascunho/continuidade mais a única ação primária ficam à direita; no compacto, a
primária vem primeiro em largura total. O conteúdo e o domínio continuam próprios
do Acontece.

Na execução, shell, contêiner direito, insets, raios e gaps devem reproduzir
literalmente a geometria canônica já aprovada. Essa ressalva faz parte do aceite
visual e não pode ser tratada como polimento posterior.

## Domínio e segurança

Um post pertence ao tenant e à instituição, pode restringir unidade e turma e guarda autoria global e membership contextual. Audiências permitidas são Famílias, Alunos, Equipe escolar e Somente responsáveis. Rascunho usa versão otimista. Publicação exige `happens.posts.create` e `happens.posts.publish`; RPCs derivam ator e tenant da sessão e mutações diretas ficam revogadas.

O consumo autorizado usa `happens.posts.read` e recebe apenas autor, contexto, legenda, horário e descritores de mídia ordenados. Contagens sociais e rótulos não pertencentes à projeção não são inventados pelo cliente. Cada descritor contém um ticket opaco e descartável, resolvido sob demanda pela Edge Function em URL assinada curta; falhas de mídia recarregam o feed para obter um novo ticket.

Até seis JPG, PNG, WebP ou MP4 podem ser selecionados. O MVP usa a exceção temporária da ADR 0026: Storage privado, gateway server-side, validação de assinatura e sem URL pública.

## Estados

Inicial, carregando, editando, autosalvando, salvo, enviando mídia, publicando, agendado, sucesso, conflito, erro recuperável e acesso negado.

Durante carregamento, o composer não expõe campos ou ações. Seleção de mídia,
remoção, autosave, save e publish compartilham exclusão mútua; enquanto uma
dessas intenções está pendente, navegação, ponteiro e foco do formulário ficam
bloqueados. Troca de repository ou contexto invalida respostas e seletores
pendentes, limpa o estado anterior e só então carrega o novo contexto. Falhas
operacionais preservam o draft e oferecem retry; falha de load usa uma
superfície de estado separada.

## Fora de escopo

Momentos, Agora, edição avançada, moderação completa e notificações de entrega.

## Aceite

- estrutura fiel em 375, 768 e 1440 px, sem overflow;
- mídia, legenda, contexto, audiência, agendamento, rascunho, CTA e prévia funcionais;
- troca de contexto não conserva posts, ações locais, draft ou callbacks do contexto anterior;
- acesso cross-tenant e por ID negado no backend;
- análise estática, testes Flutter, SQL/Edge e validadores Coelo executados quando o runtime estiver disponível.
