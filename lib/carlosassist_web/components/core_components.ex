defmodule CarlosassistWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS plus the app's own component
  classes in `assets/css/app.css` (`btn`, `sheet`, `field`, `badge`, `notice`
  and so on): one look for the whole app, taken from Lumen Viae. Night
  ground, vellum sheets for anything read closely or filled in, gilt for the
  primary action, Cormorant Garamond headings and EB Garamond text. Here are
  useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: CarlosassistWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={["flash", @kind == :error && "flash-error"]}
      {@rest}
    >
      <.icon :if={@kind == :info} name="hero-check-circle" class="flash-icon" />
      <.icon :if={@kind == :error} name="hero-exclamation-circle" class="flash-icon" />
      <div class="flex-1 min-w-0">
        <p :if={@title} class="font-semibold">{@title}</p>
        <p>{msg}</p>
      </div>
      <button type="button" class="flash-close" aria-label={gettext("close")}>
        <.icon name="hero-x-mark" class="size-6" />
      </button>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  A capsule at least 52px tall. `variant="primary"` is the gilt primary
  action, one per screen region; the default is the outline; `"danger"`
  removes or refuses something.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method type disabled name value form data-confirm)

  attr :variant, :string, values: ~w(primary outline danger)
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-gold",
      "outline" => "btn-outline",
      "danger" => "btn-danger",
      nil => "btn-outline"
    }

    assigns = assign(assigns, :variant_class, Map.fetch!(variants, assigns[:variant]))

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["btn", @variant_class, @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={["btn", @variant_class, @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :help, :string, default: nil, doc: "a line of help shown under the field"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="field">
      <label class="field-check">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input type="checkbox" id={@id} name={@name} value="true" checked={@checked} {@rest} />
        <span>{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="field">
      <label :if={@label} for={@id} class="field-label">{@label}</label>
      <select
        id={@id}
        name={@name}
        class={["field-input", @errors != [] && "field-input-error"]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <p :if={@help} class="field-help">{@help}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="field">
      <label :if={@label} for={@id} class="field-label">{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={["field-input", @errors != [] && "field-input-error"]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <p :if={@help} class="field-help">{@help}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="field">
      <label :if={@label} for={@id} class="field-label">{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={["field-input", @errors != [] && "field-input-error"]}
        {@rest}
      />
      <p :if={@help} class="field-help">{@help}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="field-error">
      <.icon name="hero-exclamation-circle" class="size-6 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a page header: an optional small label, the page title, an
  optional line under it and optional actions beside it.
  """
  attr :class, :string, default: nil
  attr :kicker, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      "mb-8",
      @actions != [] && "flex flex-col gap-5 md:flex-row md:items-end md:justify-between",
      @class
    ]}>
      <div>
        <p :if={@kicker} class="kicker mb-2">{@kicker}</p>
        <h1 class="page-title">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="lead mt-3">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  The ornament between parts of a page: a hairline, a diamond, a small
  cross, a diamond, a hairline.
  """
  attr :class, :any, default: nil

  def divider(assigns) do
    ~H"""
    <div class={["divider", @class]} aria-hidden="true">
      <span class="divider-line"></span>
      <span class="divider-diamond"></span>
      <svg viewBox="0 0 9 13" class="divider-cross">
        <path d="M3.24 0 H5.76 V2.64 H9 V5.16 H5.76 V13 H3.24 V5.16 H0 V2.64 H3.24 Z" />
      </svg>
      <span class="divider-diamond"></span>
      <span class="divider-line"></span>
    </div>
    """
  end

  @doc """
  A label and its value, as on a ride: "Pickup", then the place.
  """
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :note

  def datum(assigns) do
    ~H"""
    <div class={@class}>
      <p class="data-label">
        <.icon :if={@icon} name={@icon} class="size-5" />
        {@label}
      </p>
      <p class="data-value">{render_slot(@inner_block)}</p>
      <p :for={note <- @note} class="data-note">{render_slot(note)}</p>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="rows">
      <li :for={item <- @item} class="py-3">
        <div class="data-label">{item.title}</div>
        <div>{render_slot(item)}</div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-6"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(CarlosassistWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(CarlosassistWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders an avatar with optional placeholder.

  ## Examples

      <.avatar src="/uploads/profile.jpg" alt="User Profile" />
      <.avatar src="/uploads/profile.jpg" alt="User Profile" size="lg" />
      <.avatar alt="User Profile" size="sm" />
  """
  attr :src, :string, default: nil, doc: "the source URL of the avatar image"
  attr :alt, :string, default: "Profile", doc: "the alt text for the avatar image"

  attr :size, :string,
    default: "md",
    values: ~w(xs sm md lg xl 2xl),
    doc: "the size of the avatar"

  attr :class, :string, default: "", doc: "additional CSS classes for the avatar container"
  attr :rest, :global, doc: "arbitrary HTML attributes to add to the avatar container"

  def avatar(assigns) do
    ~H"""
    <div class={["avatar", avatar_size_class(@size), @class]} {@rest}>
      <img :if={@src && @src != ""} src={@src} alt={@alt} />
      <.icon :if={!@src || @src == ""} name="hero-user" class={avatar_icon_size_class(@size)} />
    </div>
    """
  end

  defp avatar_size_class("xs"), do: "w-10 h-10"
  defp avatar_size_class("sm"), do: "w-12 h-12"
  defp avatar_size_class("md"), do: "w-14 h-14"
  defp avatar_size_class("lg"), do: "w-16 h-16"
  defp avatar_size_class("xl"), do: "w-20 h-20"
  defp avatar_size_class("2xl"), do: "w-24 h-24"
  defp avatar_size_class(_), do: "w-12 h-12"

  defp avatar_icon_size_class("xs"), do: "size-5"
  defp avatar_icon_size_class("sm"), do: "size-6"
  defp avatar_icon_size_class("md"), do: "size-7"
  defp avatar_icon_size_class("lg"), do: "size-8"
  defp avatar_icon_size_class("xl"), do: "size-10"
  defp avatar_icon_size_class("2xl"), do: "size-12"
  defp avatar_icon_size_class(_), do: "size-6"
end
