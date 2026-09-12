select column_name, data_type, is_nullable, column_default from information_schema.columns where table_schema='supabase_migrations' and table_name='schema_migrations' order by ordinal_position;
