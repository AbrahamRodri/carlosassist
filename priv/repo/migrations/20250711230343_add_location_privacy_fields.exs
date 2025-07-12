defmodule Carlosassist.Repo.Migrations.AddLocationPrivacyFields do
  use Ecto.Migration

  def change do
    alter table(:rides) do
      # Add location privacy fields
      add :pickup_address, :string
      add :pickup_lat, :decimal, precision: 10, scale: 6
      add :pickup_long, :decimal, precision: 10, scale: 6
      add :destination_address, :string
      add :destination_lat, :decimal, precision: 10, scale: 6
      add :destination_long, :decimal, precision: 10, scale: 6
    end

    # Add indexes for coordinate queries
    create index(:rides, [:pickup_lat, :pickup_long])
    create index(:rides, [:destination_lat, :destination_long])
  end
end
