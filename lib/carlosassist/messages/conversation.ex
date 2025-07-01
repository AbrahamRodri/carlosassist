defmodule Carlosassist.Messages.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :status, :string

    belongs_to :ride, Carlosassist.Rides.Ride
    belongs_to :rider_user, Carlosassist.Accounts.User
    belongs_to :volunteer_user, Carlosassist.Accounts.User

    has_many :messages, Carlosassist.Messages.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :ride_id, :rider_user_id, :volunteer_user_id])
    |> validate_required([:ride_id, :rider_user_id, :volunteer_user_id])
    |> validate_inclusion(:status, ["active", "closed"])
    |> unique_constraint(:ride_id, name: :conversations_ride_id_unique)
  end
end
