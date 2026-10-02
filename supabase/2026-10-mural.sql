-- Atualização do mural: rode uma vez no SQL Editor do Supabase.
-- Cria a opção "Aparece no mural" para a equipe tirar uma resposta do mural sem apagar nada.
alter table public.respostas add column if not exists no_mural boolean not null default true;
grant update (no_mural) on public.respostas to authenticated;
