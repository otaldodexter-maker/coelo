---
source: planos aprovados de Publicação do Acontece e Publicação do Agora
status: accepted-temporary
generated_at: 2026-08-20
---

# ADR 0026 — Exceção temporária de Storage privado para publicação no MVP

## Decisão

Durante o MVP do composer do Acontece, a mídia pode usar o bucket privado `coelo-happens-mvp` do Supabase. O cliente nunca recebe `service_role`, não escolhe caminhos e não cria URL pública. Uma Edge Function autenticada valida autorização, MIME real, tamanho e checksum, gera o caminho e finaliza o vínculo do objeto com o post.

Durante o MVP do composer do Agora, mídia vertical e áudio próprio podem usar o bucket privado `coelo-now-mvp` sob o mesmo contrato. O limite-base de vídeo é 30 segundos e capacidades do plano podem ampliá-lo; duração e capacidade são sempre revalidadas no backend. O upload usa intenção autorizada e URL assinada direta, nunca base64 da mídia pela Edge Function.

Esta decisão substitui a ADR 0022 somente para este MVP. Metadados mantêm `storage_provider`, e o contrato do repositório não depende do provedor, para permitir migração ao Cloudflare R2.

## Limites

- bucket público permanece proibido;
- preview de rascunho e leitura pública usam autorizações server-side distintas e URLs de 60 segundos; a leitura pública resgata ticket opaco, individual e descartável após revalidar vínculo, audiência e expiração;
- operações são auditadas e isoladas por tenant/instituição;
- a migração para R2 é obrigatória antes do piloto ou produção;
- a exceção não se estende a Momentos nem a outras superfícies por analogia.

## Consequências

O MVP reduz integrações simultâneas, mas cria uma dívida deliberada e com prazo. Falhas de upload devem limpar objetos órfãos e nunca ampliar permissões diretas nas tabelas ou no Storage.
