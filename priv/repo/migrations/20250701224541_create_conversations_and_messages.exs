defmodule Carlosassist.Repo.Migrations.CreateConversationsAndMessages do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :ride_id, references(:rides, on_delete: :delete_all), null: false
      add :rider_user_id, references(:users, on_delete: :delete_all), null: false
      add :volunteer_user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :sender_user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:ride_id])
    create index(:conversations, [:rider_user_id])
    create index(:conversations, [:volunteer_user_id])
    create unique_index(:conversations, [:ride_id], name: :conversations_ride_id_unique)

    create index(:messages, [:conversation_id])
    create index(:messages, [:sender_user_id])
    create index(:messages, [:inserted_at])
  end
end
