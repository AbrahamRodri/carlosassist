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

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-w-4xl mx-auto">
      <!-- Chat Header -->
      <div class="bg-base-100 border-b border-base-300 p-4">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/dashboard/inbox"} class="btn btn-sm btn-ghost">
            ← Back to Inbox
          </.link>
          <.avatar src={@other_user.profile_pic_location} alt={@other_user.email} size="md" />
          <div class="flex-1">
            <h1 class="font-semibold text-lg">{@other_user.email}</h1>
            <p class="text-sm text-base-content/60">
              <span
                :if={@current_user.id == @conversation.rider_user_id}
                class="badge badge-primary badge-sm mr-2"
              >
                Volunteer
              </span>
              <span
                :if={@current_user.id == @conversation.volunteer_user_id}
                class="badge badge-secondary badge-sm mr-2"
              >
                Rider
              </span>
              {@conversation.ride.pickup_location} → {@conversation.ride.destination}
            </p>
          </div>
          <div class="text-right text-sm text-base-content/60">
            <p><strong>Ride Date:</strong></p>
            <p>{Calendar.strftime(@conversation.ride.ride_date, "%b %d, %Y")}</p>
            <p>{Calendar.strftime(@conversation.ride.ride_date, "%I:%M %p")}</p>
          </div>
        </div>
      </div>
      
    <!-- Messages Container -->
      <div
        id="messages-container"
        class="flex-1 overflow-y-auto p-4 space-y-4"
        phx-hook="ScrollToBottom"
      >
        <div
          :for={message <- @messages}
          class={[
            "chat",
            (message.sender_user_id == @current_user.id && "chat-end") || "chat-start"
          ]}
        >
          <div class="chat-image avatar">
            <div class="w-8 rounded-full">
              <.avatar
                src={message.sender_user.profile_pic_location}
                alt={message.sender_user.email}
                size="sm"
              />
            </div>
          </div>
          <div class="chat-header">
            {if message.sender_user_id == @current_user.id, do: "You", else: @other_user.email}
            <time class="text-xs opacity-50 ml-1">
              {Calendar.strftime(message.inserted_at, "%H:%M")}
            </time>
          </div>
          <div class={[
            "chat-bubble",
            (message.sender_user_id == @current_user.id && "chat-bubble-primary") ||
              "chat-bubble-secondary"
          ]}>
            {message.content}
          </div>
        </div>
      </div>
      
    <!-- Message Input -->
      <div class="bg-base-100 border-t border-base-300 p-4">
        <form phx-submit="send_message" class="flex gap-2">
          <input
            type="text"
            value={@new_message}
            phx-change="update_message"
            name="message"
            placeholder="Type your message..."
            class="input input-bordered flex-1"
            autocomplete="off"
          />
          <button type="submit" class="btn btn-primary" disabled={String.trim(@new_message) == ""}>
            Send
          </button>
        </form>
      </div>
    </div>
    """
  end
end
