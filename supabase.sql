-- Radar Belchior 80: banco das notas e listas dos fãs.
-- Cole tudo no Supabase em SQL Editor > New query e clique em Run.

-- Notas de 1 a 5 estrelas, uma por fã e por lançamento
create table if not exists public.notas (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id text not null check (char_length(item_id) <= 64),
  nota smallint not null check (nota between 1 and 5),
  atualizado_em timestamptz not null default now(),
  primary key (user_id, item_id)
);

-- Minha lista: o que cada fã quer ver, ir ou ter, se já fez e a anotação
create table if not exists public.lista (
  user_id uuid not null references auth.users (id) on delete cascade,
  item_id text not null check (char_length(item_id) <= 64),
  feito boolean not null default false,
  anotacao text check (char_length(anotacao) <= 280),
  criado_em timestamptz not null default now(),
  primary key (user_id, item_id)
);

grant select, insert, update, delete on public.notas, public.lista to authenticated;

alter table public.notas enable row level security;
alter table public.lista enable row level security;

-- Cada fã só lê e mexe nas próprias linhas
create policy "notas: ler as minhas" on public.notas for select to authenticated using (auth.uid() = user_id);
create policy "notas: criar as minhas" on public.notas for insert to authenticated with check (auth.uid() = user_id);
create policy "notas: mudar as minhas" on public.notas for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notas: apagar as minhas" on public.notas for delete to authenticated using (auth.uid() = user_id);

create policy "lista: ler a minha" on public.lista for select to authenticated using (auth.uid() = user_id);
create policy "lista: criar na minha" on public.lista for insert to authenticated with check (auth.uid() = user_id);
create policy "lista: mudar a minha" on public.lista for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "lista: apagar da minha" on public.lista for delete to authenticated using (auth.uid() = user_id);

-- Números públicos (sem dizer quem votou ou marcou): médias, contagens e total de fãs
create or replace view public.media_notas as
  select item_id, round(avg(nota)::numeric, 2) as media, count(*) as n
  from public.notas group by item_id;

create or replace view public.contagem_lista as
  select item_id, count(*) as n from public.lista group by item_id;

create or replace view public.resumo_fas as
  select count(distinct user_id) as fas from public.notas;

grant select on public.media_notas, public.contagem_lista, public.resumo_fas to anon, authenticated;

-- Sugestões de artistas para os próximos radares (só a dona do projeto lê, pelo painel do Supabase)
create table if not exists public.sugestoes (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  artista text not null check (char_length(trim(artista)) between 2 and 80),
  motivo text check (char_length(motivo) <= 280),
  criado_em timestamptz not null default now()
);

grant insert on public.sugestoes to authenticated;
alter table public.sugestoes enable row level security;
create policy "sugestoes: enviar as minhas" on public.sugestoes for insert to authenticated with check (auth.uid() = user_id);

-- Para consultar no SQL Editor: artistas mais pedidos
create or replace view public.sugestoes_ranking as
  select initcap(lower(trim(artista))) as artista, count(*) as pedidos, max(criado_em) as ultimo_pedido
  from public.sugestoes group by lower(trim(artista)) , initcap(lower(trim(artista))) order by pedidos desc;
revoke all on public.sugestoes_ranking from anon, authenticated;
