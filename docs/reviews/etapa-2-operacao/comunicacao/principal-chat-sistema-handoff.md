---
title: "Handoff — grupo principal-chat-sistema, Rodada 3"
grupo: "principal-chat-sistema"
branch: "work/etapa2-r03-principal-chat-sistema"
generated_at: "2026-09-10"
---

# Handoff — principal-chat-sistema

## Feito

**Cardápios.** A família inteira estava inalcançável no banco: as três
permissões existiam no catálogo mas nenhuma migration as concedia a papel algum,
e o bypass do Owner já tinha sido removido. A concessão foi aplicada em produção
pelo coordenador. Depois, com a baseline publicada, ficou visível que a cadeia
de Cardápios em produção para antes de `20260820230000`: entreguei a cadeia
faltante com carimbos novos (`20260910190000`, `190100`, `190200`), incluindo
`meal_plan_delete`, que o menu passou a oferecer. Apagar imagem deixou de aceitar
exclusão sem revisão — havia uma sobrecarga que lia a revisão do próprio banco e
a passava como esperada, anulando o controle otimista.

**Chat.** Fixar conversa e bandeira voltaram, agora persistidas por identidade
interna, com RPCs que revalidam contexto, capacidade e escopo. Criar grupo não
entrou: exige criar conversa e membros, que é pacote próprio.

**Acontece.** O feed pagina de verdade. No caminho misto, que é o de produção, o
servidor já devolvia `nextCursor` desde 09/09 e a tela descartava — o resto do
feed era inalcançável com o backend pronto. As mensagens de prévia saíram (D3):
ação sem destino fica visível e inerte, em vez de anunciar indisponibilidade.
Regra MAIS aplicada.

**Shell.** Os cinco `action_id` ganharam um caso nominal cada, sobre router e
sessão reais. O gate aberto era mapeamento, não implementação.

**Goldens.** Owner decidiu os 26 em 10/09 pela página de comparação. Os 10 do
feed do Acontece foram regravados no SDK registrado; o do flyout de Cardápios
também, depois de o menu ganhar arquivar e excluir.

## Achados que valem mais que os pacotes

1. **`anon` tinha SELECT em `public.meal_plans` e EXECUTE em `meal_plan_list`**
   na baseline de produção. A RLS ainda barra, então não há vazamento conhecido,
   mas o grant não deveria existir. Revogado no pacote `190100`.
2. **`20260901101500_superadmin_internal_chat_v2` é inaplicável em base
   recriada**: insere em `platform_permissions` sem os três labels que
   `20260811215451` tornou `NOT NULL` sem default. A baseline confirma: produção
   não tem `superadmin_chat_inbox_v2`. O chat interno v2 nunca chegou lá.
3. **Os pgTAP das três famílias estavam vermelhos** por fixture ou asserção
   desatualizada, alguns desde 09/09 — a suíte SQL não vinha sendo executada.
4. **A concessão de permissões vira no-op** se rodar antes dos dados. Em produção
   funcionou porque os dados já existiam; num projeto descartável, migrations
   rodam antes do seed e o insert não encontra as permissões.

## Pendências e primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| Preferências de chat (fixar/bandeira) | Bloqueado: dependem de `superadmin_chat_inbox_v2`, que produção não tem. Decisão de arquitetura sobre trazer o chat interno v2 para a baseline. |
| Paginação de `list_visible_happens_posts` | Pacote foi para o histórico. O caminho misto já pagina em produção, então isto é o caminho legado; refazer sobre a baseline quando houver decisão. |
| Galeria do Acontece (10 goldens R) | Owner pediu: paginação à direita, compartilhar/salvar/baixar à esquerda, conferir distorção da imagem, e repensar o mobile "mais como Instagram". Não iniciado. |
| Curtir e comentar no Acontece | Não existem no banco: nenhuma tabela de reação ou comentário. Pacote próprio. |
| Momentos, Perfil, Agora, Importações, Catálogo, erros | Não iniciados. |

## Testes

- pgTAP Cardápios sobre a baseline: **58 PASS / 0 FAIL** (`db reset` com baseline
  + seed, depois o pacote).
- pgTAP Chat: 31 PASS sobre replay da cadeia antiga; **não revalidado** sobre a
  baseline, porque a dependência não existe lá.
- pgTAP Acontece: 92 PASS sobre replay da cadeia antiga; idem.
- `flutter analyze lib test`: sem problemas.
- Suítes do recorte na base integrada: 536 PASS / 27 FAIL antes das decisões dos
  goldens; as falhas eram exclusivamente goldens, agora regravados conforme
  aprovação.

## WIP não commitado

Nenhum. Tudo na branch.
