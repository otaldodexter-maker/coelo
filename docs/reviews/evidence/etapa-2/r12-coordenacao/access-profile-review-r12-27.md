---
source: R12-perfis-permissoes-owner.md; access_profile_form_page.dart
status: local-green; cobertura de catálogo e E2E pendentes
generated_at: 2026-09-13
---

# R12-27 — Revisão de permissões

apps/superadmin > Acessos > Perfis e permissões > Criar/Editar > Revisão:
access-profiles.create e access-profiles.edit.

Adições/remoções usam catálogo do perfil original e do rascunho, exibindo
módulo → tela → nome da ação. O nome completo preserva próprias/todas e
outras ações específicas, sem reduzir para CRUD. Estado indisponível inclui
motivo; o escopo máximo permanece visível e a explicação distingue configuração
de autorização efetiva por vínculo/contexto. Identificador sem entrada no
catálogo tem fallback explícito; não se inventa nome ou autorização.

17 testes de contexto/continuação/recibo PASS; mais um teste focal PASS para
Estrutura → Atividades → Editar próprias atividades e ausência do código como
texto principal. Analyze do arquivo de produção sem issues.

FE local-green. BE inalterado. E2E pendente: catálogo real pode conter nomes
técnicos/inglês; conferir cobertura e traduções na rota normal, permissões
indisponíveis/adiadas, alcance efetivo e persistência/reload. R12-23 (contrato
Principal profissional) não é resolvido por essa apresentação.
