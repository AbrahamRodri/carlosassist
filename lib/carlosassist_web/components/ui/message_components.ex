defmodule CarlosassistWeb.UI.MessageComponents do
  use Phoenix.Component
  import CarlosassistWeb.CoreComponents
  use CarlosassistWeb, :verified_routes

  @doc """
  Renders a list of conversations for the inbox.
  """
  attr :conversations, :list, required: true
  attr :current_user, :map, required: true

  def conversations_list(assigns) do
    ~H"""
    <.empty_conversations_state :if={@conversations == []} />
    <div :if={@conversations != []} class="space-y-4 mt-6">
      <.conversation_card
        :for={conversation <- @conversations}
        conversation={conversation}
        current_user={@current_user}
      />
    </div>
    """
  end

  @doc """
  Renders a single conversation card.
  """
  attr :conversation, :map, required: true
  attr :current_user, :map, required: true

  def conversation_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow hover:shadow-lg transition-shadow">
      <div class="card-body p-4">
        <.link navigate={~p"/dashboard/chat/#{@conversation.id}"} class="block">
          <div class="flex items-start gap-4">
            <% other_user = get_other_user(@conversation, @current_user) %>
            <.avatar src={other_user.profile_pic_location} alt={other_user.email} size="md" />

            <div class="flex-1 min-w-0">
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="font-medium text-base-content">
                    {other_user.email}
                  </h3>
                  <p class="text-sm text-base-content/60">
                    <.user_role_badge user_id={@current_user.id} conversation={@conversation} />
                    {@conversation.ride.pickup_location} → {@conversation.ride.destination}
                  </p>
                </div>
                <time class="text-xs text-base-content/50">
                  {Calendar.strftime(@conversation.updated_at, "%b %d, %Y")}
                </time>
              </div>

              <div class="mt-2">
                <p class="text-sm text-base-content/80">
                  <strong>Ride Date:</strong>
                  {Calendar.strftime(@conversation.ride.ride_date, "%B %d, %Y at %I:%M %p")}
                </p>
              </div>
            </div>

            <div class="flex-shrink-0">
              <svg
                class="h-5 w-5 text-base-content/40"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 5l7 7-7 7"
                />
              </svg>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Renders the chat interface.
  """
  attr :conversation, :map, required: true
  attr :other_user, :map, required: true
  attr :current_user, :map, required: true
  attr :messages, :list, required: true
  attr :new_message, :string, required: true

  def chat_interface(assigns) do
    ~H"""
    <div class="flex flex-col h-screen max-w-4xl mx-auto">
      <.chat_header
        conversation={@conversation}
        other_user={@other_user}
        current_user={@current_user}
      />
      <.messages_container messages={@messages} current_user={@current_user} other_user={@other_user} />
      <.message_input new_message={@new_message} />
    </div>
    """
  end

  # Private helper components

  defp empty_conversations_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="text-base-content/60">
        <svg
          class="mx-auto h-12 w-12 mb-4 opacity-40"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-3.582 8-8 8a8.959 8.959 0 01-4.906-1.471c-1.11 1.302-2.79 2.471-4.094 2.471a1 1 0 01-.894-1.447L5.382 16.9A7.962 7.962 0 013 12c0-4.418 3.582-8 8-8s8 3.582 8 8z"
          />
        </svg>
        <p class="text-lg font-medium">No conversations yet</p>
        <p class="text-sm">Conversations will appear here once you accept volunteer requests</p>
      </div>
    </div>
    """
  end

  defp get_other_user(conversation, current_user) do
    if current_user.id == conversation.rider_user_id do
      conversation.volunteer_user
    else
      conversation.rider_user
    end
  end

  defp user_role_badge(assigns) do
    ~H"""
    <span :if={@user_id == @conversation.rider_user_id} class="badge badge-primary badge-sm mr-2">
      Volunteer
    </span>
    <span
      :if={@user_id == @conversation.volunteer_user_id}
      class="badge badge-secondary badge-sm mr-2"
    >
      Rider
    </span>
    """
  end

  defp chat_header(assigns) do
    ~H"""
    <div class="bg-base-100 border-b border-base-300 p-4">
      <div class="flex items-center gap-4">
        <.link navigate={~p"/dashboard/inbox"} class="btn btn-sm btn-ghost">
          ← Back to Inbox
        </.link>
        <.avatar src={@other_user.profile_pic_location} alt={@other_user.email} size="md" />
        <div class="flex-1">
          <h1 class="font-semibold text-lg">{@other_user.email}</h1>
          <p class="text-sm text-base-content/60">
            <.user_role_badge user_id={@current_user.id} conversation={@conversation} />
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
    """
  end

  defp messages_container(assigns) do
    ~H"""
    <div
      id="messages-container"
      class="flex-1 overflow-y-auto p-4 space-y-4"
      phx-hook="ScrollToBottom"
    >
      <.chat_message
        :for={message <- @messages}
        message={message}
        current_user={@current_user}
        other_user={@other_user}
      />
    </div>
    """
  end

  defp chat_message(assigns) do
    ~H"""
    <div class={[
      "chat",
      (@message.sender_user_id == @current_user.id && "chat-end") || "chat-start"
    ]}>
      <div class="chat-image avatar">
        <div class="w-8 rounded-full">
          <.avatar
            src={@message.sender_user.profile_pic_location}
            alt={@message.sender_user.email}
            size="sm"
          />
        </div>
      </div>
      <div class="chat-header">
        {if @message.sender_user_id == @current_user.id, do: "You", else: @other_user.email}
        <time class="text-xs opacity-50 ml-1">
          {Calendar.strftime(@message.inserted_at, "%H:%M")}
        </time>
      </div>
      <div class={[
        "chat-bubble",
        (@message.sender_user_id == @current_user.id && "chat-bubble-primary") ||
          "chat-bubble-secondary"
      ]}>
        {@message.content}
      </div>
    </div>
    """
  end

  defp message_input(assigns) do
    ~H"""
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
    """
  end
end
