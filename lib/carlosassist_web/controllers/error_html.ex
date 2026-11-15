defmodule CarlosassistWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.

  Error pages are rendered without the root layout, so `page/1` is a whole
  document: the same night ground, vellum sheet and type as the rest of the
  app, with a plain sentence and a way back to the home page.
  """
  use CarlosassistWeb, :html

  def render("404.html", assigns) do
    assigns
    |> Map.put(:title, "Not Found")
    |> Map.put(:heading, "We could not find that page")
    |> Map.put(:message, "The address may be wrong, or the page may have been moved.")
    |> page()
  end

  def render("500.html", assigns) do
    assigns
    |> Map.put(:title, "Internal Server Error")
    |> Map.put(:heading, "Something went wrong on our side")
    |> Map.put(:message, "Please wait a moment and try again.")
    |> page()
  end

  # Any other status gets its standard name, for example "Forbidden".
  def render(template, assigns) do
    assigns
    |> Map.put(:title, Phoenix.Controller.status_message_from_template(template))
    |> Map.put(:heading, Phoenix.Controller.status_message_from_template(template))
    |> Map.put(:message, "This page could not be shown.")
    |> page()
  end

  defp page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#070E1F" />
        <title>{@title} · CarlosAssist</title>
        <link rel="icon" href={~p"/favicon.ico"} sizes="any" />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <header class="site-header">
          <div class="wrap site-header-row">
            <a href={~p"/"} class="brand" aria-label="CarlosAssist home">
              <img
                src={~p"/images/carlosassist-mark.webp"}
                alt=""
                width="48"
                height="48"
                class="brand-mark"
              />
              <span>
                <span class="brand-name">CarlosAssist</span>
                <span class="brand-line">Rides from parish volunteers</span>
              </span>
            </a>
          </div>
        </header>
        <main id="main" class="site-main">
          <div class="wrap wrap-narrow page">
            <div class="sheet text-center">
              <p class="kicker mb-2">{@title}</p>
              <h1 class="page-title">{@heading}</h1>
              <.divider />
              <p class="mb-8">{@message}</p>
              <a href={~p"/"} class="btn btn-gold">Go to the home page</a>
            </div>
          </div>
        </main>
      </body>
    </html>
    """
  end
end
