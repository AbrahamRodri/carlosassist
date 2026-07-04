defmodule Carlosassist.Repo.Migrations.MakeUserEmailCaseInsensitive do
  use Ecto.Migration

  # SQLite has no citext (this migration set was converted from Postgres), so
  # Bob@x.com and bob@x.com could register as two accounts. Enforce uniqueness
  # case-insensitively; emails are also downcased at the changeset level.
  def change do
    drop unique_index(:users, [:email])
    create unique_index(:users, ["email COLLATE NOCASE"], name: :users_email_index)
  end
end
