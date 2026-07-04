import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/carlosassist start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

if System.get_env("PHX_SERVER") do
  config :carlosassist, CarlosassistWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/carlosassist/carlosassist.db
      """

  config :carlosassist, Carlosassist.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :carlosassist, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Mapbox configuration
  config :carlosassist, :mapbox,
    public_key: System.get_env("MAPBOX_PUBLIC_KEY"),
    private_key: System.get_env("MAPBOX_PRIVATE_KEY")

  config :carlosassist, CarlosassistWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :carlosassist, CarlosassistWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :carlosassist, CarlosassistWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Mailer (Brevo — free tier, single verified sender, no domain required)
  #
  # Magic-link login and account confirmation depend on these emails, so both
  # env vars are required — fail loudly at boot instead of silently not sending.
  # The HTTP client is already configured in config/prod.exs (Swoosh.ApiClient.Req).
  brevo_api_key =
    System.get_env("BREVO_API_KEY") ||
      raise """
      environment variable BREVO_API_KEY is missing.
      Create a free account at https://www.brevo.com, generate an API key under
      SMTP & API → API Keys, then set it:
          fly secrets set BREVO_API_KEY=xkeysib-...
      """

  mail_from_address =
    System.get_env("MAIL_FROM_ADDRESS") ||
      raise """
      environment variable MAIL_FROM_ADDRESS is missing.
      Use the sender email address you verified in Brevo (Senders & Domains):
          fly secrets set MAIL_FROM_ADDRESS=you@example.com
      """

  config :carlosassist, Carlosassist.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: brevo_api_key

  config :carlosassist, :mail_from,
    name: System.get_env("MAIL_FROM_NAME") || "CarlosAssist",
    address: mail_from_address

  # Uploads must live on the mounted volume to survive deploys
  config :carlosassist, :uploads_dir, System.get_env("UPLOADS_DIR") || "/mnt/name/uploads"
end
