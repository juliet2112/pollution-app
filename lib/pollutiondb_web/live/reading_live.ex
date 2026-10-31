defmodule PollutiondbWeb.ReadingLive do
  use PollutiondbWeb, :live_view

  alias Pollutiondb.Streamer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Pollutiondb.PubSub, Streamer.topic())
    {:ok,
    socket
    |> assign(current_datetime: nil, latest: [], stations: Pollutiondb.Station.get_all(), station_id: Streamer.current_station())
    |> stream(:log, [])}
  end

  @impl true
  def handle_info({:batch, datetime, readings}, socket) do
    dt_string = "#{datetime.date} #{datetime.time}"
    socket =
      Enum.reduce(readings, socket, fn r, acc ->
        stream_insert(acc, :log, %{id: "r-#{r.id}", type: r.type, value: r.value, datetime: dt_string}, at: 0)
      end)

    {:noreply, assign(socket, current_datetime: dt_string, latest: readings)}
  end

  @impl true
  def handle_info({:station_changed, station_id}, socket) do
    {:noreply, socket
    |> assign(current_station: station_id, current_datetime: nil)
    |> stream(:log, [], reset: true)}
  end

  @impl true
  def handle_event("select_station", %{"station_id" => id_str}, socket) do
    id = String.to_integer(id_str)
    Streamer.set_station(id)
    {:noreply, socket}
  end


@impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 space-y-8">
      <div class="bg-white rounded-xl shadow-md p-6 border border-zinc-200">
        <div class="flex items-center justify-between border-b border-zinc-200 pb-4 mb-6">
          <h1 class="text-xl font-bold text-zinc-900">Stacja Pomiarowa na Żywo</h1>
          <div :if={@current_datetime} class="text-xs font-mono bg-zinc-100 text-zinc-700 px-3 py-1.5 rounded-full border border-zinc-300">
            Aktualny pomiar: <%= @current_datetime %>
          </div>
        </div>

        <div :if={@latest == []} class="text-zinc-400 text-sm italic py-4">
          Oczekiwanie na pierwszy odczyt ze strumienia...
        </div>

        <form phx-change="select_station" class="mb-6">
          <label for="station_id" class="block text-xs font-mono font-medium text-zinc-600 mb-1.5 uppercase tracking-wide">
            Stacja pomiarowa
          </label>
          <div class="relative max-w-sm">
            <select
              name="station_id"
              id="station_id"
              class="w-full bg-zinc-100 hover:bg-zinc-200/70 border border-zinc-300 text-zinc-800 text-sm font-mono rounded-lg px-3.5 py-2 pr-8 shadow-sm transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-zinc-400 focus:border-zinc-400 cursor-pointer"
            >
              <option :for={s <- @stations} value={s.id} selected={s.id == @station_id}>
                <%= clean_station_name(s.name) %>
              </option>
            </select>
          </div>
        </form>

        <div class="space-y-2">
          <%= for r <- @latest do %>
            <div class="flex items-center gap-3">
              <div class="w-24 text-xs font-mono text-zinc-600"><%= r.type %></div>
              <div class="flex-1 bg-zinc-100 rounded h-6 overflow-hidden">
                <div
                  class={"h-full transition-all duration-700 ease-out #{bar_color(r.type)}"}
                  style={"width: #{bar_width(r.type, r.value)}%"}
                >
                </div>
              </div>
              <div class="w-20 text-right font-mono text-sm">
                <%= :erlang.float_to_binary(r.value, decimals: 2) %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 border border-zinc-200">
        <h2 class="text-lg font-bold text-zinc-900 mb-4">Dziennik Zdarzeń</h2>
        <div class="overflow-x-auto max-h-96 overflow-y-auto border border-zinc-200 rounded-lg">
          <table class="w-full text-left text-xs font-mono">
            <thead class="bg-zinc-100 border-b border-zinc-200 sticky top-0">
              <tr>
                <th class="py-2.5 px-4 font-semibold text-zinc-700">Typ parametru</th>
                <th class="py-2.5 px-4 font-semibold text-zinc-700">Wartość</th>
                <th class="py-2.5 px-4 font-semibold text-zinc-700">Data i czas</th>
              </tr>
            </thead>
            <tbody id="log" phx-update="stream" class="divide-y divide-zinc-100">
              <tr :for={{dom_id, entry} <- @streams.log} id={dom_id} class="hover:bg-zinc-50">
                <td class="py-2 px-4 font-semibold text-zinc-800"><%= entry.type %></td>
                <td class="py-2 px-4 text-zinc-700">
                  <%= :erlang.float_to_binary(entry.value, decimals: 2) %>
                </td>
                <td class="py-2 px-4 text-zinc-500"><%= entry.datetime %></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end


  defp bar_width("PM10", val), do: clamp_pct(val / 200.0 * 100)
  defp bar_width("PM25", val), do: clamp_pct(val / 100.0 * 100)
  defp bar_width("PM1", val), do: clamp_pct(val / 50.0 * 100)
  defp bar_width("PRESSURE", val), do: clamp_pct((val - 950.0) / (1100.0 - 950.0) * 100)
  defp bar_width("TEMPERATURE", val), do: clamp_pct((val + 20.0) / 60.0 * 100)
  defp bar_width("HUMIDITY", val), do: clamp_pct(val)
  defp bar_width(_type, val), do: clamp_pct(val)

  defp clamp_pct(pct) do
    pct
    |> max(5.0)
    |> min(100.0)
    |> Float.round(1)
  end

  defp bar_color("PM10"), do: "bg-rose-500"
  defp bar_color("PM25"), do: "bg-amber-500"
  defp bar_color("PM1"), do: "bg-orange-400"
  defp bar_color("TEMPERATURE"), do: "bg-emerald-500"
  defp bar_color("HUMIDITY"), do: "bg-sky-500"
  defp bar_color("PRESSURE"), do: "bg-indigo-500"
  defp bar_color(_type), do: "bg-zinc-400"

  defp clean_station_name(name) do
    case String.split(name, "-", parts: 2) do
      [_id_prefix, clean_name] -> clean_name
      [clean_name] -> clean_name
    end
  end
end
