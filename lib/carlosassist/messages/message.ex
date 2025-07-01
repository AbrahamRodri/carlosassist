defmodule Carlosassist.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string

    belongs_to :conversation, Carlosassist.Messages.Conversation
    belongs_to :sender_user, Carlosassist.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :conversation_id, :sender_user_id])
    |> validate_required([:content, :conversation_id, :sender_user_id])
    |> validate_length(:content, min: 1, max: 1000)
  end
end
