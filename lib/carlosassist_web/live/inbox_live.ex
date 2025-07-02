defmodule CarlosassistWeb.InboxLive do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Messages

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    conversations = Messages.list_conversations_for_user(current_user.id)

    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:current_user, current_user)}
  end

  # The render function is now handled by the corresponding .html.heex template
end
