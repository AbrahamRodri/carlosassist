defmodule Carlosassist.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false
  alias Carlosassist.Repo

  alias Carlosassist.Messages.Conversation
  alias Carlosassist.Messages.Message

  # Conversation functions

  @doc """
  Creates a conversation between a rider and volunteer.
  """
  def create_conversation(attrs \\ %{}) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a conversation for a specific ride.
  """
  def get_conversation_by_ride(ride_id) do
    Conversation
    |> where([c], c.ride_id == ^ride_id)
    |> preload([:rider_user, :volunteer_user, :ride])
    |> Repo.one()
  end

  @doc """
  Lists all active conversations for a user (both as rider and volunteer).
  """
  def list_conversations_for_user(user_id) do
    Conversation
    |> where([c], c.status == "active")
    |> where([c], c.rider_user_id == ^user_id or c.volunteer_user_id == ^user_id)
    |> preload([:rider_user, :volunteer_user, :ride])
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc """
  Closes a conversation (when ride is completed).
  """
  def close_conversation(conversation_id) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        {:error, :not_found}

      conversation ->
        conversation
        |> Conversation.changeset(%{status: "closed"})
        |> Repo.update()
    end
  end

  @doc """
  Deletes a conversation and all its messages.
  """
  def delete_conversation(conversation_id) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        {:error, :not_found}

      conversation ->
        Repo.delete(conversation)
    end
  end

  # Message functions

  @doc """
  Creates a message in a conversation.
  """
  def create_message(attrs \\ %{}) do
    result =
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        # Update conversation's updated_at timestamp
        conversation = Repo.get!(Conversation, message.conversation_id)

        Conversation.changeset(conversation, %{})
        |> Repo.update()

        # Preload sender for real-time updates
        message = Repo.preload(message, :sender_user)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Lists messages for a conversation.
  """
  def list_messages_for_conversation(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> preload([:sender_user])
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single conversation with messages loaded.
  """
  def get_conversation_with_messages(conversation_id) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        {:error, :not_found}

      conversation ->
        conversation =
          conversation
          |> Repo.preload([:rider_user, :volunteer_user, :ride, messages: [:sender_user]])

        {:ok, conversation}
    end
  end

  @doc """
  Checks if a user is part of a conversation.
  """
  def user_in_conversation?(conversation_id, user_id) do
    Conversation
    |> where([c], c.id == ^conversation_id)
    |> where([c], c.rider_user_id == ^user_id or c.volunteer_user_id == ^user_id)
    |> Repo.exists?()
  end
end
