# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
defmodule Uro.UserSocket do
  use Phoenix.Socket

  channel "zone:*", Uro.ZoneChannel

  def connect(_params, socket, _connect_info), do: {:ok, socket}
  def id(_socket), do: nil
end
