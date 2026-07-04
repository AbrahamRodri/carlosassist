defmodule CarlosassistWeb.UI.MessageComponents do
  use Phoenix.Component
  import CarlosassistWeb.CoreComponents
  use CarlosassistWeb, :verified_routes

  alias Carlosassist.Accounts.User

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
    assigns = assign(assigns, :other_user, get_other_user(assigns.conversation, assigns.current_user))

    ~H"""
    <.link navigate={~p"/dashboard/chat/#{@conversation.id}"} class="block parish-card hover:border-primary/50">
      <div class="p-5">
        <div class="flex items-center gap-4">
          <.avatar src={@other_user.profile_pic_location} alt={"#{User.display_name(@other_user)}'s photo"} size="lg" />

          <div class="flex-1 min-w-0">
            <p class="text-xl font-bold text-base-content">
              {User.display_name(@other_user)}
              <span class="text-base font-normal text-base-content/70">
                — your {other_user_role(@conversation, @current_user)}
              </span>
            </p>
            <p class="text-base text-base-content/80 mt-1">
              {@conversation.ride.pickup_name}
              <.icon name="hero-arrow-right" class="w-4 h-4 inline mx-0.5 text-base-content/50" />
              {@conversation.ride.destination_name}
            </p>
            <p class="text-base text-base-content/70">
              Ride on {Calendar.strftime(@conversation.ride.ride_date, "%A, %B %d at %I:%M %p")}
            </p>
          </div>

          <span class="btn btn-primary hidden sm:inline-flex">
            <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" /> Open
          </span>
          <.icon name="hero-chevron-right" class="w-6 h-6 text-base-content/50 sm:hidden" />
        </div>
      </div>
    </.link>
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
    <div class="flex flex-col max-w-3xl w-full mx-auto flex-1">
      <.chat_header
        conversation={@conversation}
        other_user={@other_user}
        current_user={@current_user}
      />
      <.messages_container messages={@messages} current_user={@current_user} other_user={@other_user} />
      <.message_input new_message={@new_message} other_user={@other_user} />
    </div>
    """
  end

  # Private helper components

  defp empty_conversations_state(assigns) do
    ~H"""
    <div class="text-center py-14">
      <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
        <.icon name="hero-chat-bubble-left-right" class="w-8 h-8 text-primary" />
      </div>
      <p class="text-2xl text-base-content mb-2 font-display">No messages yet</p>
      <p class="text-lg text-base-content/75 max-w-md mx-auto">
        When a ride is confirmed, you and your ride partner can talk here to
        settle the details.
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

  defp other_user_role(conversation, current_user) do
    if current_user.id == conversation.rider_user_id, do: "driver", else: "rider"
  end

  defp chat_header(assigns) do
    assigns = assign(assigns, :role, other_user_role(assigns.conversation, assigns.current_user))

    ~H"""
    <div class="bg-base-100 border-b-2 border-base-300 p-4">
      <div class="mb-3">
        <.link navigate={~p"/dashboard/inbox"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="w-5 h-5" /> All messages
        </.link>
      </div>
      <div class="flex items-center gap-4">
        <.avatar
          src={@other_user.profile_pic_location}
          alt={"#{User.display_name(@other_user)}'s photo"}
          size="lg"
        />
        <div class="flex-1 min-w-0">
          <h1 class="text-2xl text-base-content">{User.display_name(@other_user)}</h1>
          <p class="text-base text-base-content/75">
            Your {@role} · {@conversation.ride.pickup_name}
            <.icon name="hero-arrow-right" class="w-3.5 h-3.5 inline mx-0.5 text-base-content/50" />
            {@conversation.ride.destination_name}
          </p>
          <p class="text-base text-base-content/70">
            Ride on {Calendar.strftime(@conversation.ride.ride_date, "%A, %B %d at %I:%M %p")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp messages_container(assigns) do
    ~H"""
    <div
      id="messages-container"
      class="flex-1 min-h-[50vh] overflow-y-auto p-4 space-y-4 bg-base-200/40"
      phx-hook="ScrollToBottom"
    >
      <p :if={@messages == []} class="text-center text-base text-base-content/70 py-8">
        No messages yet. Say hello!
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
    <div class={[
      "chat",
      (@message.sender_user_id == @current_user.id && "chat-end") || "chat-start"
    ]}>
      <div class="chat-image avatar">
        <div class="w-10 rounded-full">
          <.avatar
            src={@message.sender_user.profile_pic_location}
            alt={"#{User.display_name(@message.sender_user)}'s photo"}
            size="sm"
          />
        </div>
      </div>
      <div class="chat-header text-base text-base-content/80">
        {if @message.sender_user_id == @current_user.id,
          do: "You",
          else: User.first_name(@other_user)}
        <time class="text-sm opacity-70 ml-1">
          {Calendar.strftime(@message.inserted_at, "%I:%M %p")}
        </time>
      </div>
      <div class={[
        "chat-bubble text-lg",
        (@message.sender_user_id == @current_user.id && "chat-bubble-primary") ||
          "bg-base-100 text-base-content border-2 border-base-300"
      ]}>
        {@message.content}
      </div>
    </div>
    """
  end

  defp message_input(assigns) do
    ~H"""
    <div class="bg-base-100 border-t-2 border-base-300 p-4">
      <form phx-submit="send_message" class="flex gap-3">
        <label for="chat-message-input" class="sr-only">Your message</label>
        <input
          id="chat-message-input"
          type="text"
          value={@new_message}
          phx-change="update_message"
          name="message"
          placeholder={"Write to #{User.first_name(@other_user)}..."}
          class="input input-bordered flex-1 text-lg"
          autocomplete="off"
        />
        <button type="submit" class="btn btn-primary btn-lg" disabled={String.trim(@new_message) == ""}>
          <.icon name="hero-paper-airplane" class="w-5 h-5" /> Send
        </button>
      </form>
    </div>
    """
  end
end
