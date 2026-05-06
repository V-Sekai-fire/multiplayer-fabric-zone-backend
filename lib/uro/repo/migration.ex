# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.Repo.Migration do
  @moduledoc """
  Separate Ecto repo used exclusively for DDL migrations.
  Connects as gateway_admin (which holds CREATE/DDL privileges) so that the
  main Uro.Repo can run as gateway_writer (DML only), respecting ReBAC.
  """
  use Ecto.Repo,
    otp_app: :uro,
    adapter: Ecto.Adapters.Postgres,
    migration_lock: false
end
