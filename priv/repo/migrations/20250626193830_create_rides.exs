defmodule Carlosassist.Repo.Migrations.CreateRides do
  use Ecto.Migration

  def change do
    create table(:rides) do
      add :pickup_location, :string
      add :destination, :string
      add :description, :text
      add :status, :string, default: "pending"
      add :ride_date, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:rides, [:user_id])
    create index(:rides, [:status])
    create index(:rides, [:ride_date])
  end
end
