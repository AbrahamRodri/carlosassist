defmodule Carlosassist.Rides do
  @moduledoc """
  The Rides context.
  """

  import Ecto.Query, warn: false
  alias Carlosassist.Repo

  alias Carlosassist.Rides.Ride
  alias Carlosassist.Rides.VolunteerRequest

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
  Deletes a ride.

  ## Examples

      iex> delete_ride(ride)
      {:ok, %Ride{}}

      iex> delete_ride(ride)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ride(%Ride{} = ride) do
    Repo.delete(ride)
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
  """
  def accept_volunteer_request(volunteer_request_id, ride_id) do
    Repo.transaction(fn ->
      volunteer_request = Repo.get!(VolunteerRequest, volunteer_request_id)

      # Update the accepted volunteer request status
      {:ok, accepted_request} =
        volunteer_request
        |> VolunteerRequest.changeset(%{status: "accepted"})
        |> Repo.update()

      # Assign volunteer to ride and update status to confirmed
      ride = Repo.get!(Ride, ride_id)

      {:ok, updated_ride} =
        ride
        |> Ride.changeset(%{
          volunteer_id: volunteer_request.volunteer_user_id,
          status: "confirmed"
        })
        |> Repo.update()

      # Reject all other pending requests for this ride
      VolunteerRequest
      |> where([vr], vr.ride_id == ^ride_id and vr.status == "pending")
      |> Repo.update_all(set: [status: "rejected"])

      {accepted_request, updated_ride}
    end)
  end

  @doc """
  Rejects a volunteer request.
  """
  def reject_volunteer_request(volunteer_request_id) do
    volunteer_request = Repo.get!(VolunteerRequest, volunteer_request_id)

    volunteer_request
    |> VolunteerRequest.changeset(%{status: "rejected"})
    |> Repo.update()
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
end
