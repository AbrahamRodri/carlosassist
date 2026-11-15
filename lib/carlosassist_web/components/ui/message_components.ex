defmodule CarlosassistWeb.UI.MessageComponents do
  @moduledoc """
  The messages pages' parts: the list of conversations and one conversation.
  """
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
    <div :if={@conversations != []} class="grid gap-5">
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
    assigns =
      assign(assigns, :other_user, get_other_user(assigns.conversation, assigns.current_user))

    ~H"""
    <article class="sheet">
      <div class="flex items-center gap-4">
        <.avatar src={@other_user.profile_pic_location} alt={@other_user.email} size="md" />
        <div class="min-w-0">
          <p class="data-label">
            <.other_role user_id={@current_user.id} conversation={@conversation} />
          </p>
          <h2 class="card-title break-words">{@other_user.email}</h2>
        </div>
      </div>

      <p class="mt-4">
        <strong>{@conversation.ride.pickup_name} to {@conversation.ride.destination_name}</strong>
        <br />
        <span class="muted">{format_ride_date(@conversation.ride.ride_date)}</span>
      </p>

      <.link navigate={~p"/dashboard/chat/#{@conversation.id}"} class="btn btn-gold mt-5">
        Open the conversation <.icon name="hero-arrow-right" class="size-6" />
      </.link>
    </article>
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
    <.link navigate={~p"/dashboard/inbox"} class="link mb-4">
      <.icon name="hero-arrow-left" class="size-5" /> Back to all conversations
    </.link>

    <div class="sheet">
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
    <div class="sheet text-center">
      <h2 class="section-title">No conversations yet</h2>
      <.divider />
      <p class="muted">
        A conversation opens here when a rider chooses a driver.
      </p>
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

  # The other person's part in the ride, as the current user sees it.
  defp other_role(assigns) do
    ~H"""
    <span :if={@user_id == @conversation.rider_user_id}>Your driver</span>
    <span :if={@user_id == @conversation.volunteer_user_id}>Your rider</span>
    """
  end

  defp chat_header(assigns) do
    ~H"""
    <div class="mb-5 flex flex-col gap-4 sm:flex-row sm:items-center">
      <div class="flex min-w-0 flex-1 items-center gap-4">
        <.avatar src={@other_user.profile_pic_location} alt={@other_user.email} size="lg" />
        <div class="min-w-0">
          <p class="data-label">
            <.other_role user_id={@current_user.id} conversation={@conversation} />
          </p>
          <h1 class="card-title break-words">{@other_user.email}</h1>
        </div>
      </div>
      <div class="sm:text-right">
        <p class="data-label sm:justify-end">The ride</p>
        <p class="font-semibold">
          {@conversation.ride.pickup_name} to {@conversation.ride.destination_name}
        </p>
        <p class="muted small">{format_ride_date(@conversation.ride.ride_date)}</p>
      </div>
    </div>
    """
  end

  defp messages_container(assigns) do
    ~H"""
    <div
      id="messages-container"
      class="chat-log"
      phx-hook="ScrollToBottom"
      role="log"
      aria-label="Messages"
    >
      <p :if={@messages == []} class="muted m-auto text-center">
        No messages yet. Write the first one below.
      </p>
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
    <div class={["chat-msg", @message.sender_user_id == @current_user.id && "chat-msg-mine"]}>
      <p class="chat-meta">
        {if @message.sender_user_id == @current_user.id, do: "You", else: @other_user.email}
        <span aria-hidden="true">·</span>
        <time>{Calendar.strftime(@message.inserted_at, "%-I:%M %p")}</time>
      </p>
      <div class="chat-bubble">{@message.content}</div>
    </div>
    """
  end

  defp message_input(assigns) do
    ~H"""
    <form phx-submit="send_message" class="mt-5">
      <label for="chat-message-input" class="field-label">Your message</label>
      <div class="flex flex-col gap-3 sm:flex-row">
        <input
          type="text"
          id="chat-message-input"
          value={@new_message}
          phx-change="update_message"
          name="message"
          placeholder="Write your message here"
          class="field-input sm:flex-1"
          autocomplete="off"
        />
        <button type="submit" class="btn btn-gold" disabled={String.trim(@new_message) == ""}>
          Send <.icon name="hero-paper-airplane" class="size-6" />
        </button>
      </div>
    </form>
    """
  end

  defp format_ride_date(datetime), do: Calendar.strftime(datetime, "%A, %B %-d at %-I:%M %p")
end
