defmodule Carlosassist.Rides.Ride do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rides" do
    field :pickup_name, :string
    field :pickup_address, :string
    field :pickup_lat, :decimal
    field :pickup_long, :decimal
    field :destination_name, :string
    field :destination_address, :string
    field :destination_lat, :decimal
    field :destination_long, :decimal
    field :description, :string
    field :status, :string
    field :ride_date, :utc_datetime
    belongs_to :user, Carlosassist.Accounts.User
    belongs_to :volunteer, Carlosassist.Accounts.User

    has_many :volunteer_requests, Carlosassist.Rides.VolunteerRequest

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ride, attrs, user_scope \\ nil) do
    ride
    |> cast(attrs, [
      :pickup_name,
      :pickup_address,
      :pickup_lat,
      :pickup_long,
      :destination_name,
      :destination_address,
      :destination_lat,
      :destination_long,
      :description,
      :status,
      :ride_date,
      :volunteer_id
    ])
    |> validate_required([:pickup_name, :destination_name, :description, :ride_date])
    |> validate_length(:pickup_name, min: 3, max: 200)
    |> validate_length(:destination_name, min: 3, max: 200)
    |> validate_length(:pickup_address, max: 500)
    |> validate_length(:destination_address, max: 500)
    |> validate_length(:description, min: 10, max: 1000)
    |> validate_inclusion(:status, ["pending", "confirmed", "completed", "cancelled"])
    |> validate_future_date(:ride_date)
    |> validate_coordinates()
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

  defp validate_coordinates(changeset) do
    changeset
    |> validate_coordinate_range(:pickup_lat, -90, 90)
    |> validate_coordinate_range(:pickup_long, -180, 180)
    |> validate_coordinate_range(:destination_lat, -90, 90)
    |> validate_coordinate_range(:destination_long, -180, 180)
  end

  defp validate_coordinate_range(changeset, field, min, max) do
    case get_change(changeset, field) do
      nil -> changeset
      value when is_number(value) ->
        if value >= min and value <= max do
          changeset
        else
          add_error(changeset, field, "must be between #{min} and #{max}")
        end
      _ -> changeset
    end
  end
end
