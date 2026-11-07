-- Agent v2 makes parser_mode = 'regex' really mean "Tanpa AI" (no LLM at all).
-- Until now the app hid that option, so every stored 'regex' is just the old
-- column default, not a choice: move those users to the server AI they had.
UPDATE public.users SET parser_mode = 'server_key' WHERE parser_mode = 'regex' OR parser_mode IS NULL;
ALTER TABLE public.users ALTER COLUMN parser_mode SET DEFAULT 'server_key';
