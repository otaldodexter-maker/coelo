---
title: "Perfil e configurações do Superadmin"
source: "Plano aprovado pelo usuário em 2026-07-28; docs/design/design-system.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md"
status: "implemented"
generated_at: "2026-07-28"
---

# Perfil e configurações do Superadmin

## Objetivo

Oferecer ao usuário interno uma área pessoal para atualizar sua identidade,
entender o próprio alcance de acesso e ajustar preferências do dispositivo sem
permitir autoedição de papel ou permissões.

## Perfil

`/profile` reúne dados pessoais, acesso e segurança. Nome, sobrenome, avatar e
senha são simulados localmente. Alterar o e-mail cria uma solicitação pendente:
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

## Configurações

`/settings` oferece `Sistema`, `Claro` e `Escuro`, além de “Reduzir animações”.
As preferências são persistidas no dispositivo. Redução manual de movimento é
combinada com a preferência do sistema, nunca a substitui.

## Limites

Não fazem parte desta versão Supabase, R2, senha real, e-mail transacional,
sessões ativas, MFA real ou auditoria server-side. Nenhuma senha do protótipo é
persistida. Os contratos locais permitem substituir os repositórios sem alterar
as telas.
