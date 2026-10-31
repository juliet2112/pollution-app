defmodule Pollutiondb.Streamer do
  use GenServer
  import Ecto.Query

  alias Pollutiondb.{Reading, Repo, Station, Loader}
  @topic "readings"
  @tick_ms 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def topic, do: @topic

  @impl true
  def init(:ok) do
    ensure_data_loaded()
    station = Repo.one(from s in Station, order_by: s.id, limit: 1)
    schedule_tick()
    {:ok, %{station_id: station && station.id, cursor: nil}}
  end

  @impl true
  def handle_info(:tick, %{station_id: nil} = state) do
    schedule_tick()
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    schedule_tick()
    dt = next_datetime(state.station_id, state.cursor)
    new_cursor = dt || next_datetime(state.station_id,dt)

    if new_cursor do
      readings = readings_at(state.station_id, new_cursor)
      Phoenix.PubSub.broadcast(Pollutiondb.PubSub, @topic, {:batch, new_cursor, readings})
      {:noreply, %{state | cursor: new_cursor}}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:set_station, id}, state) do
     Phoenix.PubSub.broadcast(Pollutiondb.PubSub, @topic, {:station_changed, id} )
     {:noreply, %{state | station_id: id, cursor: nil}}
  end

  @impl true
  def handle_call(:current_station, _from, state) do
    {:reply, state.station_id, state}
  end

  def current_station, do: GenServer.call(__MODULE__, :current_station)

  def set_station(station_id) when is_integer(station_id) do
    GenServer.cast(__MODULE__, {:set_station, station_id})
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)

  def ensure_data_loaded() do
    if Repo.aggregate(Reading, :count, :id) == 0 do
      Loader.load_all()
    end
  end

  def readings_at(station_id, dt) do
    Repo.all(from r in Reading,
    where: r.station_id == ^station_id and r.time == ^dt.time and r.date == ^dt.date
    )
  end
  def next_datetime(station_id, nil) do
    Repo.one(from r in Reading, where:
    r.station_id == ^station_id,
    order_by: [asc: r.date, asc: r.time],
    select: %{date: r.date, time: r.time},
    limit: 1
    )
  end
  def next_datetime(station_id, cursor) do
    Repo.one(from r in Reading, where:
    r.station_id == ^station_id and
      (r.date > ^cursor.date or (r.date == ^cursor.date and r.time > ^cursor.time)),
    order_by: [asc: r.date, asc: r.time],
    select: %{date: r.date, time: r.time},
    limit: 1
    )
  end
end
