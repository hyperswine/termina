defmodule Terminalphx.Repo do
  use Ecto.Repo,
    otp_app: :terminalphx,
    adapter: Ecto.Adapters.Postgres
end
