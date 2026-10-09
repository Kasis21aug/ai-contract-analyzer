create table documents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  file_path text,
  status text not null default 'processing',
  page_count int default 0,
  error_message text,
  created_at timestamptz default now()
);

create table pages (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  page_number int not null,
  text text not null
);

create table chunks (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  chunk_index int not null,
  text text not null,
  start_page int,
  end_page int
);

alter table documents enable row level security;
alter table pages enable row level security;
alter table chunks enable row level security;