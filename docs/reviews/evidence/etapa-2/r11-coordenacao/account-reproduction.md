---
source: R11 C0; UI normal 127.0.0.1:3000; RPC atual lida via MCP
status: regressão de persistência reproduzida; correção em andamento
generated_at: 2026-09-13
---

# Conta — reprodução R11

Build preservado01833e90b. Login normal QA-R03 com Manter sessão; rota produtiva /profile. Após selecionar #336699 e Salvar, UI mostrou Perfil atualizado e cabeçalho/editor azuis (account-color-after-save.png). Após reload, ambos voltaram a #FFF1EB (account-color-reload.png). Falha confirmada de persistência, não apenas prévia. Rodapé só visível após rolagem de toda a extensa lista Meu acesso (captura privada r11-before-save.png).

Repository save envia apenas p_avatar_initials; ignora foto/cor. RPC remota public.superadmin_account_profile_save valida sigla mas não a persiste; grava apenas nome/celular e solicitação de e-mail. Projeção remota força initials e #FFF1EB. Controller assume o objeto enviado como confirmado depois de Future<void>save, sem ler o retorno autoritativo. Nenhuma mudança de banco na reprodução. Nome ainda não testado; foto tem lacuna causal confirmada por código/contrato, prova pelo picker ainda pendente. Não chamar estes achados de aceite corrigido.

C0: corrigir contrato e confirmação do controller, rodapé compartilhado e busca/grupos somente conforme dados reais. FE/BE/E2E de account.profile reabertos pela regressão; manter provas históricas como histórico. Não há nova aprovação visual Owner.
