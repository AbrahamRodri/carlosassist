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

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <.header>
        Inbox
        <:subtitle>Your conversations with riders and volunteers</:subtitle>
      </.header>

      <div :if={@conversations == []} class="text-center py-12">
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

      <div :if={@conversations != []} class="space-y-4 mt-6">
        <div
          :for={conversation <- @conversations}
          class="card bg-base-100 shadow hover:shadow-lg transition-shadow"
        >
          <div class="card-body p-4">
            <.link navigate={~p"/dashboard/chat/#{conversation.id}"} class="block">
              <div class="flex items-start gap-4">
                <% other_user =
                  if @current_user.id == conversation.rider_user_id,
                    do: conversation.volunteer_user,
                    else: conversation.rider_user %>
                <.avatar src={other_user.profile_pic_location} alt="#{other_user.email}" size="md" />

                <div class="flex-1 min-w-0">
                  <div class="flex justify-between items-start">
                    <div>
                      <h3 class="font-medium text-base-content">
                        {other_user.email}
                      </h3>
                      <p class="text-sm text-base-content/60">
                        <span
                          :if={@current_user.id == conversation.rider_user_id}
                          class="badge badge-primary badge-sm mr-2"
                        >
                          Volunteer
                        </span>
                        <span
                          :if={@current_user.id == conversation.volunteer_user_id}
                          class="badge badge-secondary badge-sm mr-2"
                        >
                          Rider
                        </span>
                        {conversation.ride.pickup_location} → {conversation.ride.destination}
                      </p>
                    </div>
                    <time class="text-xs text-base-content/50">
                      {Calendar.strftime(conversation.updated_at, "%b %d, %Y")}
                    </time>
                  </div>

                  <div class="mt-2">
                    <p class="text-sm text-base-content/80">
                      <strong>Ride Date:</strong>
                      {Calendar.strftime(conversation.ride.ride_date, "%B %d, %Y at %I:%M %p")}
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
      </div>
    </div>
    """
  end
end
