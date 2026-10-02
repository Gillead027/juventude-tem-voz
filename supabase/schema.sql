-- =====================================================================
-- JUVENTUDE TEM VOZ – CRJ Flexal, outubro de 2026
-- Banco do quiz avaliativo + Memória Jovem do CRJ.
--
-- Quem pode o quê:
--   * Jovens (site público, sem login): só ENVIAM. Não leem nada.
--     O envio passa pela função registrar_resposta, que confere e corrige
--     o quiz no servidor e devolve o código do comprovante.
--   * Fotos: jovens só ENVIAM para o bucket privado "memoria-fotos".
--   * Equipe (logada no painel): lê tudo, vê as fotos e marca o brinde.
--     Cadastros abertos ficam DESLIGADOS; a equipe é convidada pelo painel do Supabase.
-- =====================================================================

-- ---------- tabela ----------
create table if not exists public.respostas (
  numero            bigint generated always as identity primary key,
  codigo            text generated always as ('JTV-' || lpad(numero::text, 3, '0')) stored,
  criado_em         timestamptz not null default now(),
  nome              text not null check (char_length(nome) between 3 and 80),
  oficinas          text[] not null default '{}',
  encontros         text[] not null default '{}',
  escolhas          smallint[] not null,
  resultado         boolean[] not null,
  acertos           smallint not null check (acertos between 0 and 8),
  escala_opiniao    smallint check (escala_opiniao between 1 and 5),
  escala_decisoes   smallint check (escala_decisoes between 1 and 5),
  atividade_marcou  text,
  se_a_decisao      text,
  crj_representa    text not null,
  aprendizados      text,
  momento_marcante  text,
  foto_path         text,
  foto_sobre        text,
  autorizacao       text not null check (autorizacao in ('Sim, com meu nome', 'Sim, mas sem meu nome', 'Não autorizo')),
  brinde_entregue   boolean not null default false,
  brinde_em         timestamptz,
  observacao        text
);

create index if not exists respostas_criado_em_idx on public.respostas (criado_em desc);

alter table public.respostas enable row level security;

-- Nenhuma política para "anon": o público não lê nem grava direto na tabela.
drop policy if exists "equipe le respostas" on public.respostas;
create policy "equipe le respostas" on public.respostas
  for select to authenticated using (true);

drop policy if exists "equipe atualiza respostas" on public.respostas;
create policy "equipe atualiza respostas" on public.respostas
  for update to authenticated using (true) with check (true);

-- A equipe só altera brinde e observação.
revoke update on public.respostas from authenticated;
grant select on public.respostas to authenticated;
grant update (brinde_entregue, brinde_em, observacao) on public.respostas to authenticated;
revoke all on public.respostas from anon;

-- ---------- função de envio (única porta de entrada do site) ----------
create or replace function public.registrar_resposta(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Posição da resposta certa de cada pergunta (0 = primeira opção).
  -- Se mudar a resposta certa no site, mude aqui também.
  gabarito  smallint[] := array[1, 2, 1, 1, 2, 0, 1, 1];
  esc       smallint[];
  res       boolean[] := '{}';
  ac        smallint := 0;
  k         int;
  v_nome    text;
  v_aut     text;
  v_repr    text;
  r         public.respostas;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception 'envio vazio';
  end if;

  select array_agg(x::smallint order by ord)
    into esc
    from jsonb_array_elements_text(coalesce(p->'escolhas', '[]'::jsonb)) with ordinality as t(x, ord)
   where x ~ '^[0-3]$';
  if coalesce(array_length(esc, 1), 0) <> 8 then
    raise exception 'quiz incompleto';
  end if;
  for k in 1..8 loop
    res := res || (esc[k] = gabarito[k]);
    if esc[k] = gabarito[k] then ac := ac + 1; end if;
  end loop;

  v_nome := left(regexp_replace(btrim(coalesce(p->>'nome', '')), '\s+', ' ', 'g'), 80);
  if char_length(v_nome) < 3 then raise exception 'nome obrigatorio'; end if;

  v_repr := left(btrim(coalesce(p->>'representa', '')), 1200);
  if v_repr = '' then raise exception 'memoria obrigatoria'; end if;

  v_aut := p->>'autorizacao';
  if v_aut is null or v_aut not in ('Sim, com meu nome', 'Sim, mas sem meu nome', 'Não autorizo') then
    raise exception 'autorizacao obrigatoria';
  end if;

  insert into public.respostas (
    nome, oficinas, encontros, escolhas, resultado, acertos,
    escala_opiniao, escala_decisoes, atividade_marcou, se_a_decisao,
    crj_representa, aprendizados, momento_marcante,
    foto_path, foto_sobre, autorizacao
  ) values (
    v_nome,
    coalesce(array(select left(x, 60) from jsonb_array_elements_text(coalesce(p->'oficinas', '[]'::jsonb)) x limit 12), '{}'),
    coalesce(array(select left(x, 60) from jsonb_array_elements_text(coalesce(p->'atividades', '[]'::jsonb)) x limit 6), '{}'),
    esc, res, ac,
    case when p->>'escala1' ~ '^[1-5]$' then (p->>'escala1')::smallint end,
    case when p->>'escala2' ~ '^[1-5]$' then (p->>'escala2')::smallint end,
    nullif(left(btrim(coalesce(p->>'marcou', '')), 80), ''),
    nullif(left(btrim(coalesce(p->>'decisao', '')), 600), ''),
    v_repr,
    nullif(left(btrim(coalesce(p->>'aprendeu', '')), 1200), ''),
    nullif(left(btrim(coalesce(p->>'momento', '')), 1200), ''),
    case when p->>'foto_path' ~ '^[0-9a-zA-Z-]{10,64}\.jpg$' then p->>'foto_path' end,
    nullif(left(btrim(coalesce(p->>'fotoSobre', '')), 200), ''),
    v_aut
  )
  returning * into r;

  return jsonb_build_object('codigo', r.codigo, 'data', r.criado_em, 'acertos', r.acertos);
end;
$$;

revoke all on function public.registrar_resposta(jsonb) from public;
grant execute on function public.registrar_resposta(jsonb) to anon, authenticated;

-- ---------- fotos ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('memoria-fotos', 'memoria-fotos', false, 5242880, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg'];

drop policy if exists "jovens enviam foto" on storage.objects;
create policy "jovens enviam foto" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'memoria-fotos');

drop policy if exists "equipe ve fotos" on storage.objects;
create policy "equipe ve fotos" on storage.objects
  for select to authenticated
  using (bucket_id = 'memoria-fotos');
