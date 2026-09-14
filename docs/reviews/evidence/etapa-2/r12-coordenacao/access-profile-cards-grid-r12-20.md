---
source: R12-perfis-permissoes-owner.md; access_profile_directory_page.dart
status: local-green; rota normal e aprovação visual pendentes
generated_at: 2026-09-14
---

# R12-20 — card de perfil em 2×2

Em `apps/superadmin > Acessos > Perfis e permissões > Perfis/Modelos`, o card
agora distribui as quatro informações já existentes em uma grade 2×2:
Status, Escopo máximo, Vínculos e Tipo. Não foi inventada métrica nova e o
diretório continua aceitando qualquer quantidade de registros. A largura de
cada célula é calculada pelo espaço disponível e o `Wrap` preserva leitura em
telas estreitas.

Os testes de layout existentes em 375/1440 px e escala 1/2 confirmam as quatro
métricas, altura/largura do card e ausência de exceção: 4/4 PASS. Analyze do
arquivo de produção PASS. FE local-green; BE inalterado; rota real, reload,
golden aprovado e negativa cross-tenant continuam pendentes.
