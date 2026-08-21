---
title: "Circulares privadas no Principal"
knowledge_id: "principal-circulars"
source: "specs/037-principal-circulars.md"
status: "validated"
generated_at: "2026-08-21"
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

Uma Circular publicada aparece na aba `Circulares` do Perfil e como projeção no
Acontece, sem duplicar o conteúdo canônico. Revisões publicadas são imutáveis;
uma correção preserva o histórico, mantém a posição original no feed e exige
novas respostas.

Respostas podem ser individuais, por funcionário ou por criança. A política
compartilhada permite que qualquer responsável autorizado responda pela criança
sem criar respostas duplicadas entre responsáveis. Prazo é opcional e o
encerramento manual é auditado.

Mídia usa o bucket Supabase privado definido pela ADR 0027, com upload e leitura
assinados pelo backend, validação do arquivo e metadados no Postgres. A exceção
é exclusiva de Circulares e não muda o provedor das outras superfícies.
