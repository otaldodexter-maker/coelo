# Worker de publicação de comunicações

Materializa, em páginas limitadas, a audiência congelada por
`publish_notice_for_superadmin`. A materialização cria `notice_receipts`, mas
não preenche `delivered_at`: esse instante pertence ao runtime que efetivamente
entregar ou exibir a comunicação.

Configuração necessária:

- Edge Function: segredo `COELO_NOTICE_WORKER_SECRET`.
- Vault: `notice_publication_worker_secret` com o mesmo valor.
- Vault: `notice_publication_worker_url` apontando para a URL implantada da
  função `notice-publication-worker`.

O cron versionado chama apenas o dispatcher SQL. Sem os dois segredos no
Vault, o dispatcher retorna `null` e não envia requisição. A função rejeita
métodos diferentes de `POST` e segredo ausente ou divergente.
