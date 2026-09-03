---
title: "Perfil e configurações do Superadmin"
source: "Plano aprovado pelo usuário em 2026-07-28; docs/design/design-system.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; ADR 0032 e decisão Etapa 2 em 2026-09-03"
status: "implemented"
generated_at: "2026-07-28"
updated_at: "2026-09-03"
---

# Perfil e configurações do Superadmin

## Objetivo

Oferecer ao usuário interno uma área pessoal para atualizar sua identidade,
entender o próprio alcance de acesso e ajustar preferências do dispositivo sem
permitir autoedição de papel ou permissões.

## Perfil

Enquanto o contrato produtivo não está disponível, `/profile` permanece
fail-closed em `503` e `/dev/profile` reúne dados pessoais, acesso e segurança
com repositório local isolado. Nome, sobrenome e avatar são simulados
localmente. Alterar o e-mail cria uma solicitação pendente:
o e-mail atual permanece ativo até um Owner aprovar pela central de atividades.
Qualquer Owner pode decidir, inclusive o próprio solicitante nesta primeira
versão do protótipo.

O avatar aceita foto PNG, JPG ou WebP de até 2 MB, com enquadramento circular,
arraste e zoom. Sem foto, usa uma sigla configurável de uma ou duas letras e
uma cor livre. O texto do avatar alterna automaticamente entre preto e branco
conforme o maior contraste. A sigla e a cor permanecem como fallback ao remover
a foto.

“Meu acesso” mostra papel, MFA e resumo de capacidades somente para leitura.
Autorização real continua obrigatoriamente server-side.

Alteração de senha permanece indisponível e a interface não solicita nem monta
campos de credenciais enquanto não houver capability e comando server-side
reais. Alterações locais do formulário possuem estado dirty explícito;
`Cancelar alterações` restaura integralmente o último perfil confirmado.

## Configurações

`/settings` oferece `Sistema`, `Claro` e `Escuro`, além de “Reduzir animações”.
As preferências são persistidas no dispositivo. Redução manual de movimento é
combinada com a preferência do sistema, nunca a substitui.

## Limites

Não fazem parte desta versão local histórica Supabase, R2, senha real, e-mail transacional,
sessões ativas, MFA real ou auditoria server-side. O protótipo não solicita nem
persiste senha. Os contratos locais permitem substituir os repositórios sem
alterar as telas.

Na Etapa 2, a limitação de mídia foi supersedida pela ADR 0032: o avatar deve
ser integrado ao `coelo-media-prod` pelo Media Gateway, com JPEG/PNG/WebP,
conversão de HEIC/HEIF, master 1:1 até 1024 x 1024 e 2 MiB e variantes
64/128/256/512. A conta Superadmin não possui capa própria aprovada; não criar
esse campo por analogia com o Perfil Principal.
