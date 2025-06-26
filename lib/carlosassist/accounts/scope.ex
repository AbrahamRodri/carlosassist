defmodule Carlosassist.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Carlosassist.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Carlosassist.Accounts.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Checks if the current scope is a volunteer or admin (admins have volunteer privileges).
  """
  def volunteer?(%__MODULE__{user: %User{role: role}}) when role in ["volunteer", "admin"],
    do: true

  def volunteer?(_), do: false

  @doc """
  Checks if the current scope is a rider or admin (admins have rider privileges).
  """
  def rider?(%__MODULE__{user: %User{role: role}}) when role in ["rider", "admin"], do: true
  def rider?(_), do: false

  @doc """
  Checks if the current scope is an admin.
  """
  def admin?(%__MODULE__{user: %User{role: "admin"}}), do: true
  def admin?(_), do: false

  @doc """
  Gets the user's role as a string, or nil if no user.
  """
  def get_role(%__MODULE__{user: %User{role: role}}), do: role
  def get_role(_), do: nil
end
