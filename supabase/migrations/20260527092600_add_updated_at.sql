-- Migration to add updated_at columns and update triggers for LWW synchronization.

-- 1. Create function to update updated_at on modification if not exists
create or replace function update_modified_column()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- 2. Add updated_at columns to existing tables
alter table profiles add column if not exists updated_at timestamptz default now();
alter table subjects add column if not exists updated_at timestamptz default now();
alter table notes add column if not exists updated_at timestamptz default now();
alter table flashcards add column if not exists updated_at timestamptz default now();
alter table exam_sessions add column if not exists updated_at timestamptz default now();

-- 3. Create triggers to auto-update updated_at columns
drop trigger if exists update_profiles_modtime on profiles;
create trigger update_profiles_modtime before update on profiles for each row execute procedure update_modified_column();

drop trigger if exists update_subjects_modtime on subjects;
create trigger update_subjects_modtime before update on subjects for each row execute procedure update_modified_column();

drop trigger if exists update_notes_modtime on notes;
create trigger update_notes_modtime before update on notes for each row execute procedure update_modified_column();

drop trigger if exists update_flashcards_modtime on flashcards;
create trigger update_flashcards_modtime before update on flashcards for each row execute procedure update_modified_column();

drop trigger if exists update_exam_sessions_modtime on exam_sessions;
create trigger update_exam_sessions_modtime before update on exam_sessions for each row execute procedure update_modified_column();
