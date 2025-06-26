defmodule Carlosassist.Rides do
  @moduledoc """
  The Rides context.
  """

  import Ecto.Query, warn: false
  alias Carlosassist.Repo

  alias Carlosassist.Rides.Ride

  @doc """
  Returns the list of rides for a specific user.

  ## Examples

      iex> list_rides_for_user(user_scope)
      [%Ride{}, ...]

  """
  def list_rides_for_user(user_scope) do
    Ride
    |> where([r], r.user_id == ^user_scope.user.id)
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
end
