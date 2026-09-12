# Revisao G7 - P51: usuario interno

- Data: 2026-09-12
- Escopo: leitura do roteiro/evidencia G5 1548780e1.
- Acao canonica: internal-users.create.

## Resultado

A prova mede uma unica criacao sintetica com preflight anti-duplicidade,
perfil global minimo support, escopo platform, releitura por detail/list e
logout local. A autorizacao acontece antes da chamada e a Edge Function a
repete com o token do operador; o cliente nao e a fonte de autoridade.

O link de setup e validado pela funcao quanto a HTTPS, origem do projeto,
authority sem credenciais e path. O destino de recuperacao e constante
canonica da funcao, independente da origem CORS.

## Limite do verificador

O resultado agregado password_setup_link_contract=false nao registra qual
subcheck falhou. A leitura case-sensitive dos headers explica o falso
negativo, mas nao demonstra por si o valor da query do action link. Portanto
nao ha falha de produto medida e tampouco certificacao dinamica do
redirect_to.

O complemento minimo e gerar um recovery link para a mesma identidade ja
criada, inspeciona-lo apenas em memoria e registrar somente booleans. Nao criar
outra identidade nem registrar URL, query ou token.
