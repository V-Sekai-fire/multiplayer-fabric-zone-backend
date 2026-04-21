defmodule Uro.VSekai.ZoneJanitor do
  use GenServer
  alias Uro.Repo
  import Ecto.Query, only: [from: 2]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  def handle_info(:cleanup, state) do
    cleanup_stale_zones()
    schedule_cleanup()
    {:noreply, state}
  end

  defp cleanup_stale_zones() do
    stale_zone_cutoff = Application.get_env(:uro, :stale_shard_cutoff)

    query =
      from z in "zones",
        where:
          z.updated_at >
            from_now(^stale_zone_cutoff[:amount], ^stale_zone_cutoff[:calendar_type]),
        select: z.id

    Repo.delete_all(query)
  end

  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, Application.get_env(:uro, :stale_shard_interval))
  end
end
