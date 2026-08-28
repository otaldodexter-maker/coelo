---
title: Perfil e configurações do Superadmin
knowledge_id: superadmin-profile-settings
source: docs/superpowers/specs/2026-07-28-superadmin-profile-settings-design.md
status: validated
generated_at: 2026-07-28
updated_at: 2026-08-28
audience: team
surfaces: [superadmin, profile, settings]
visibility: internal
review_owner: Coelo Product
---

# Perfil e configurações do Superadmin

Enquanto o contrato produtivo não está disponível, `/profile` permanece em
`503` e `/dev/profile` usa repositório local isolado. O Perfil local permite
alterar nome, sobrenome e avatar e consultar papel, MFA e principais
capacidades. Papel e permissões são somente leitura e nunca concedem
autorização pelo cliente.

Alteração de senha fica indisponível e não monta campos de credenciais sem
capability e comando server-side reais. O formulário só habilita salvar ou
cancelar quando existe alteração; cancelar restaura integralmente o último
perfil confirmado.

O avatar usa uma foto enquadrada em círculo ou uma sigla de uma ou duas letras
com cor livre. A foto aceita PNG, JPG ou WebP de até 2 MB. Arraste e zoom são
preservados na prévia; sigla e cor continuam como fallback. O texto alterna
automaticamente entre preto e branco conforme o maior contraste.

Inserir ou trocar foto/avatar sempre reutiliza `AvatarCropDialog`: dialog
neutro, `X` vermelho, reset, recorte circular, zoom e ações
`Cancelar`/`Aplicar` em 50/50. Capa reutiliza essa anatomia com recorte
retangular 16:9; nunca recebe a máscara circular do avatar.

Trocar e-mail cria uma solicitação pendente na central de atividades e mantém o
e-mail atual ativo. Nesta versão do protótipo, qualquer Owner pode aprovar ou
recusar, inclusive o próprio solicitante.

Configurações oferece tema Sistema, Claro ou Escuro e a opção de reduzir
animações. Essas preferências pertencem ao dispositivo. Perfil, aprovação e
avatar ainda são protótipos locais; senha não é coletada. Persistência real,
mídia privada e autorização dependem de serviços server-side futuros.
