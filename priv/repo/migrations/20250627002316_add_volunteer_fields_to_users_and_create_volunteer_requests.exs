defmodule Carlosassist.Repo.Migrations.AddVolunteerFieldsToUsersAndCreateVolunteerRequests do
  use Ecto.Migration

  def change do
    # Add volunteer fields to users table (role already exists)
    alter table(:users) do
      add :volunteer_license_plate, :string
      add :volunteer_car, :string
      add :volunteer_bio, :text
    end

    # Add indexes for better query performance
    create index(:users, [:role])

    # Add volunteer_id to rides table to track assigned volunteer
    alter table(:rides) do
      add :volunteer_id, references(:users, on_delete: :nilify_all)
    end

    create index(:rides, [:volunteer_id])

    # Create volunteer_requests table
    create table(:volunteer_requests) do
      add :ride_id, references(:rides, on_delete: :delete_all), null: false
      add :volunteer_user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "pending"
      add :message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:volunteer_requests, [:ride_id])
    create index(:volunteer_requests, [:volunteer_user_id])
    create index(:volunteer_requests, [:status])
    create unique_index(:volunteer_requests, [:ride_id, :volunteer_user_id])
  end
end
