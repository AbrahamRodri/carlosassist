defmodule Carlosassist.Repo.Migrations.AddProfilePicsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_pic_location, :string
    end
  end
end
