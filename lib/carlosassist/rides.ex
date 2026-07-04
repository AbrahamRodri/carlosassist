defmodule Carlosassist.Rides do
  @moduledoc """
  The Rides context: ride requests and the volunteer matching flow.

  Lifecycle: pending → confirmed → completed | cancelled. Volunteers offer via
  `VolunteerRequest`; `accept_volunteer_request/3` confirms the ride, rejects the
  other offers, and opens the chat conversation. Mutations take the caller's
  `user_scope` and enforce ride ownership, returning
  `{:error, :unauthorized | :invalid_status | :not_found}` when checks fail.
  """

  import Ecto.Query, warn: false
  alias Carlosassist.Repo

  alias Carlosassist.Rides.Ride
  alias Carlosassist.Rides.VolunteerRequest
  alias Carlosassist.Messages

  @doc """
  Returns the list of rides for a specific user.

  ## Examples

      iex> list_rides_for_user(user_scope)
      [%Ride{}, ...]

  """
  def list_rides_for_user(user_scope) do
    Ride
    |> where([r], r.user_id == ^user_scope.user.id)
    |> preload([:volunteer])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single ride.

  Raises `Ecto.NoResultsError` if the Ride does not exist.

  ## Examples

      iex> get_ride!(123)
      %Ride{}

      iex> get_ride!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ride!(id), do: Repo.get!(Ride, id)

  @doc """
  Gets a single ride for a specific user.

  Raises `Ecto.NoResultsError` if the Ride does not exist or doesn't belong to the user.

  ## Examples

      iex> get_ride_for_user!(123, user_scope)
      %Ride{}

      iex> get_ride_for_user!(456, user_scope)
      ** (Ecto.NoResultsError)

  """
  def get_ride_for_user!(id, user_scope) do
    Ride
    |> where([r], r.id == ^id and r.user_id == ^user_scope.user.id)
    |> Repo.one!()
  end

  @doc """
  Creates a ride.

  ## Examples

      iex> create_ride(%{field: value}, user_scope)
      {:ok, %Ride{}}

      iex> create_ride(%{field: bad_value}, user_scope)
      {:error, %Ecto.Changeset{}}

  """
  def create_ride(attrs \\ %{}, user_scope) do
    %Ride{}
    |> Ride.changeset(attrs, user_scope)
    |> Repo.insert()
  end

  @doc """
  Updates a ride.

  ## Examples

      iex> update_ride(ride, %{field: new_value})
      {:ok, %Ride{}}

      iex> update_ride(ride, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ride(%Ride{} = ride, attrs) do
    ride
    |> Ride.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ride, along with its volunteer requests.

  Only the ride's owner may delete it, and only while it is still `"pending"`
  (once a volunteer is attached, use `cancel_ride/2` so history is kept).

  ## Examples

      iex> delete_ride(ride, owner_scope)
      {:ok, %Ride{}}

      iex> delete_ride(ride, other_scope)
      {:error, :unauthorized}

  """
  def delete_ride(%Ride{} = ride, user_scope) do
    cond do
      ride.user_id != user_scope.user.id ->
        {:error, :unauthorized}

      ride.status != "pending" ->
        {:error, :invalid_status}

      true ->
        Repo.transaction(fn ->
          VolunteerRequest
          |> where([vr], vr.ride_id == ^ride.id)
          |> Repo.delete_all()

          case Repo.delete(ride) do
            {:ok, deleted} -> deleted
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ride changes.

  ## Examples

      iex> change_ride(ride)
      %Ecto.Changeset{data: %Ride{}}

  """
  def change_ride(%Ride{} = ride, attrs \\ %{}) do
    Ride.changeset(ride, attrs)
  end

  # Volunteer Request functions

  @doc """
  Returns the list of pending rides that volunteers can request to help with.
  """
  def list_pending_rides_for_volunteers do
    Ride
    |> where([r], r.status == "pending" and is_nil(r.volunteer_id))
    |> preload([:user])
    |> order_by([r], asc: r.ride_date)
    |> Repo.all()
  end

  @doc """
  Creates a volunteer request for a ride.
  """
  def create_volunteer_request(attrs \\ %{}) do
    %VolunteerRequest{}
    |> VolunteerRequest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the list of volunteer requests for a specific ride.
  """
  def list_volunteer_requests_for_ride(ride_id) do
    VolunteerRequest
    |> where([vr], vr.ride_id == ^ride_id and vr.status == "pending")
    |> preload([:volunteer_user])
    |> order_by([vr], asc: vr.inserted_at)
    |> Repo.all()
  end

  @doc """
  Accepts a volunteer request and assigns the volunteer to the ride.

  Only the ride's owner (via `user_scope`) may accept, the request must belong
  to that ride, and both must still be pending. Confirms the ride, rejects the
  other pending requests, and opens the chat conversation.

  Returns `{:ok, {accepted_request, updated_ride}}` or
  `{:error, :unauthorized | :not_found | :invalid_status}`.
  """
  def accept_volunteer_request(volunteer_request_id, ride_id, user_scope) do
    Repo.transaction(fn ->
      ride =
        Ride
        |> where([r], r.id == ^ride_id and r.user_id == ^user_scope.user.id)
        |> Repo.one()

      volunteer_request = Repo.get(VolunteerRequest, volunteer_request_id)

      cond do
        is_nil(ride) ->
          Repo.rollback(:unauthorized)

        is_nil(volunteer_request) or volunteer_request.ride_id != ride.id ->
          Repo.rollback(:not_found)

        ride.status != "pending" or volunteer_request.status != "pending" ->
          Repo.rollback(:invalid_status)

        true ->
          {:ok, accepted_request} =
            volunteer_request
            |> VolunteerRequest.changeset(%{status: "accepted"})
            |> Repo.update()

          {:ok, updated_ride} =
            ride
            |> Ride.changeset(%{
              volunteer_id: volunteer_request.volunteer_user_id,
              status: "confirmed"
            })
            |> Repo.update()

          {:ok, _conversation} =
            Messages.create_conversation(%{
              ride_id: ride.id,
              rider_user_id: ride.user_id,
              volunteer_user_id: volunteer_request.volunteer_user_id,
              status: "active"
            })

          # Reject all other pending requests for this ride
          VolunteerRequest
          |> where([vr], vr.ride_id == ^ride.id and vr.status == "pending")
          |> Repo.update_all(set: [status: "rejected"])

          {accepted_request, updated_ride}
      end
    end)
  end

  @doc """
  Rejects a volunteer request. Only the owner of the ride the request targets
  may reject it.
  """
  def reject_volunteer_request(volunteer_request_id, user_scope) do
    volunteer_request =
      VolunteerRequest
      |> join(:inner, [vr], r in Ride, on: r.id == vr.ride_id)
      |> where([vr, r], vr.id == ^volunteer_request_id and r.user_id == ^user_scope.user.id)
      |> Repo.one()

    case volunteer_request do
      nil ->
        {:error, :unauthorized}

      volunteer_request ->
        volunteer_request
        |> VolunteerRequest.changeset(%{status: "rejected"})
        |> Repo.update()
    end
  end

  @doc """
  Gets volunteer requests for a specific volunteer user.
  """
  def list_volunteer_requests_for_user(user_id) do
    VolunteerRequest
    |> where([vr], vr.volunteer_user_id == ^user_id)
    |> preload(ride: :user)
    |> order_by([vr], desc: vr.inserted_at)
    |> Repo.all()
  end

  @doc """
  Completes a confirmed ride and closes the associated conversation.
  Only the ride's owner may complete it.
  """
  def complete_ride(ride_id, user_scope) do
    Repo.transaction(fn ->
      ride = get_owned_ride(ride_id, user_scope)

      cond do
        is_nil(ride) ->
          Repo.rollback(:unauthorized)

        ride.status != "confirmed" ->
          Repo.rollback(:invalid_status)

        true ->
          {:ok, updated_ride} =
            ride
            |> Ride.changeset(%{status: "completed"})
            |> Repo.update()

          close_ride_conversation(ride.id)
          updated_ride
      end
    end)
  end

  @doc """
  Cancels a pending or confirmed ride: rejects outstanding volunteer requests,
  closes the conversation if one exists, and keeps the ride as history.
  Only the ride's owner may cancel.
  """
  def cancel_ride(ride_id, user_scope) do
    Repo.transaction(fn ->
      ride = get_owned_ride(ride_id, user_scope)

      cond do
        is_nil(ride) ->
          Repo.rollback(:unauthorized)

        ride.status not in ["pending", "confirmed"] ->
          Repo.rollback(:invalid_status)

        true ->
          VolunteerRequest
          |> where([vr], vr.ride_id == ^ride.id and vr.status == "pending")
          |> Repo.update_all(set: [status: "rejected"])

          {:ok, updated_ride} =
            ride
            |> Ride.changeset(%{status: "cancelled"})
            |> Repo.update()

          close_ride_conversation(ride.id)
          updated_ride
      end
    end)
  end

  defp get_owned_ride(ride_id, user_scope) do
    Ride
    |> where([r], r.id == ^ride_id and r.user_id == ^user_scope.user.id)
    |> Repo.one()
  end

  defp close_ride_conversation(ride_id) do
    case Messages.get_conversation_by_ride(ride_id) do
      nil -> :ok
      conversation -> Messages.close_conversation(conversation.id)
    end
  end
end
