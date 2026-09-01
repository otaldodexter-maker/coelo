---
source: planos aprovados de Publicação do Acontece e Publicação do Agora
status: superseded-by-adr-0030
generated_at: 2026-08-20
---

# ADR 0026 — Exceção temporária de Storage privado para publicação no MVP

> **Substituída pela ADR 0030.** Supabase Storage privado deixa de ser exceção
> temporária e passa a ser o provedor de toda mídia privada durante o MVP. R2
> não é gate de piloto, produção ou encerramento do MVP; sua avaliação somente
> poderá começar se o Owner optar por isso no encerramento formal do MVP.

## Decisão

Durante o MVP do composer do Acontece, a mídia pode usar o bucket privado `coelo-happens-mvp` do Supabase. O cliente nunca recebe `service_role`, não escolhe caminhos e não cria URL pública. Uma Edge Function autenticada valida autorização, MIME real, tamanho e checksum, gera o caminho e finaliza o vínculo do objeto com o post.

Durante o MVP do composer do Agora, mídia vertical e áudio próprio podem usar o bucket privado `coelo-now-mvp` sob o mesmo contrato. O limite-base de vídeo é 30 segundos e capacidades do plano podem ampliá-lo; duração e capacidade são sempre revalidadas no backend. O upload usa intenção autorizada e URL assinada direta, nunca base64 da mídia pela Edge Function.

Esta decisão substitui a ADR 0022 somente para este MVP. Metadados mantêm `storage_provider`, e o contrato do repositório não depende do provedor, para permitir migração ao Cloudflare R2.

## Limites

- bucket público permanece proibido;
- preview de rascunho e leitura pública usam autorizações server-side distintas e URLs de 60 segundos; a leitura pública resgata ticket opaco, individual e descartável após revalidar vínculo, audiência e expiração;
- operações são auditadas e isoladas por tenant/instituição;
- não há migração obrigatória para R2 durante o MVP;
- o contrato de Supabase Storage privado se estende às demais superfícies de
  mídia do MVP, conforme ADR 0030.

## Consequências

O MVP reduz integrações simultâneas sem criar um prazo obrigatório para R2.
Falhas de upload devem limpar objetos órfãos e nunca ampliar permissões diretas
nas tabelas ou no Storage.
