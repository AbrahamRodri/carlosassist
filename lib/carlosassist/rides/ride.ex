defmodule Carlosassist.Rides.Ride do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rides" do
    field :pickup_location, :string
    field :destination, :string
    field :description, :string
    field :status, :string
    field :ride_date, :utc_datetime
    belongs_to :user, Carlosassist.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ride, attrs, user_scope \\ nil) do
    ride
    |> cast(attrs, [:pickup_location, :destination, :description, :status, :ride_date])
    |> validate_required([:pickup_location, :destination, :description, :ride_date])
    |> validate_length(:pickup_location, min: 3, max: 200)
    |> validate_length(:destination, min: 3, max: 200)
    |> validate_length(:description, min: 10, max: 1000)
    |> validate_inclusion(:status, ["pending", "confirmed", "completed", "cancelled"])
    |> validate_future_date(:ride_date)
    |> maybe_put_user_id(user_scope)
    |> maybe_put_default_status()
  end

  defp validate_future_date(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      date ->
        if DateTime.compare(date, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, field, "must be in the future")
        end
    end
  end

  defp maybe_put_user_id(changeset, %{user: %{id: user_id}}) do
    put_change(changeset, :user_id, user_id)
  end

  defp maybe_put_user_id(changeset, _), do: changeset

  defp maybe_put_default_status(changeset) do
    case get_field(changeset, :status) do
      nil -> put_change(changeset, :status, "pending")
      _ -> changeset
    end
  end
end
