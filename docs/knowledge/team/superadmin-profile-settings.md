---
title: Perfil e configurações do Superadmin
knowledge_id: superadmin-profile-settings
source: docs/superpowers/specs/2026-07-28-superadmin-profile-settings-design.md
status: validated
generated_at: 2026-07-28
audience: team
surfaces: [superadmin, profile, settings]
visibility: internal
review_owner: Coelo Product
---

# Perfil e configurações do Superadmin

O Perfil permite alterar localmente nome, sobrenome e avatar, consultar o papel,
MFA e principais capacidades, e simular a troca de senha. Papel e permissões
são somente leitura e nunca concedem autorização pelo cliente.

O avatar usa uma foto enquadrada em círculo ou uma sigla de uma ou duas letras
com cor livre. A foto aceita PNG, JPG ou WebP de até 2 MB. Arraste e zoom são
preservados na prévia; sigla e cor continuam como fallback. O texto alterna
automaticamente entre preto e branco conforme o maior contraste.

Trocar e-mail cria uma solicitação pendente na central de atividades e mantém o
e-mail atual ativo. Nesta versão do protótipo, qualquer Owner pode aprovar ou
recusar, inclusive o próprio solicitante.

Configurações oferece tema Sistema, Claro ou Escuro e a opção de reduzir
animações. Essas preferências pertencem ao dispositivo. Perfil, aprovação,
senha e avatar ainda são protótipos locais; persistência real, mídia privada e
autorização dependem de serviços server-side futuros.
