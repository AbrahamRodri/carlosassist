defmodule CarlosassistWeb.ChatLive do
  use CarlosassistWeb, :live_view

  alias Carlosassist.Messages
  alias Phoenix.PubSub

  def mount(%{"id" => conversation_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    conversation_id = String.to_integer(conversation_id)

    # Check if user has access to this conversation
    if Messages.user_in_conversation?(conversation_id, current_user.id) do
      case Messages.get_conversation_with_messages(conversation_id) do
        {:ok, conversation} ->
          # Subscribe to real-time updates for this conversation
          PubSub.subscribe(Carlosassist.PubSub, "conversation:#{conversation_id}")

          other_user =
            if current_user.id == conversation.rider_user_id do
              conversation.volunteer_user
            else
              conversation.rider_user
            end

          {:ok,
           socket
           |> assign(:conversation, conversation)
           |> assign(:other_user, other_user)
           |> assign(:current_user, current_user)
           |> assign(:new_message, "")
           |> assign(:messages, conversation.messages)}

        {:error, :not_found} ->
          {:ok,
           socket
           |> put_flash(:error, "Conversation not found")
           |> redirect(to: ~p"/dashboard/inbox")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this conversation")
       |> redirect(to: ~p"/dashboard/inbox")}
    end
  end

  def handle_event("send_message", %{"message" => message_content}, socket) do
    if String.trim(message_content) != "" do
      case Messages.create_message(%{
             conversation_id: socket.assigns.conversation.id,
             sender_user_id: socket.assigns.current_user.id,
             content: String.trim(message_content)
           }) do
        {:ok, message} ->
          # Broadcast the new message to all subscribers
          PubSub.broadcast(
            Carlosassist.PubSub,
            "conversation:#{socket.assigns.conversation.id}",
            {:new_message, message}
          )

          {:noreply, assign(socket, :new_message, "")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => message_content}, socket) do
    {:noreply, assign(socket, :new_message, message_content)}
  end

  def handle_info({:new_message, message}, socket) do
    messages = socket.assigns.messages ++ [message]
    {:noreply, assign(socket, :messages, messages)}
  end

  # The render function is now handled by the corresponding .html.heex template
end
