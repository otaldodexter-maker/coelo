---
source: R10 C0; apontamento Owner; UI normal
status: verified delta
generated_at: 2026-09-13
---

# Cabe?alho da sess?o ? account.profile / shell.load

Build B3F3C8C8, Chrome3000. Sess?o QA R06 mostrou OE / Operador interno e7e907bc / Owner. Menu > Sair > confirmar > login normal QA R03 alterou para O / Operador interno 41462594 / Owner; nenhum OC ou nome da sess?o anterior permaneceu. Com Manter sess?o aberta selecionado, reload completo manteve a segunda identidade. Logout/login normal de volta ao QA R06 restaurou OE e o primeiro nome.

Provas: header-session-profile.png, header-second-identity.png, header-second-identity-reload.png, header-original-restored.png. Credenciais fora do Git e sem exposi??o. Dois perfis de plataforma reais sint?ticos; n?o s?o prova de tenants distintos. Sem nova contagem de shell.load/account.profile, j? aceitos historicamente.

Sem Manter sess?o aberta, reload voltou ao login; a prova de persist?ncia foi executada com a op??o selecionada. N?o se atribui uma regress?o de autentica??o ao cabe?alho.
