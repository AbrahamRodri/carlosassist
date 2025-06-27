defmodule Carlosassist.Rides.VolunteerRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "volunteer_requests" do
    field :status, :string
    field :message, :string

    belongs_to :ride, Carlosassist.Rides.Ride
    belongs_to :volunteer_user, Carlosassist.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(volunteer_request, attrs) do
    volunteer_request
    |> cast(attrs, [:status, :message, :ride_id, :volunteer_user_id])
    |> validate_required([:ride_id, :volunteer_user_id])
    |> validate_inclusion(:status, ["pending", "accepted", "rejected"])
    |> validate_length(:message, max: 1000)
    |> unique_constraint([:ride_id, :volunteer_user_id],
      message: "You have already requested to help with this ride"
    )
  end
end
