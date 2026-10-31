defmodule Pollutiondb.Loader do
  def parse_line(line) do
    [date, type, value, id, name, loc] = line |> String.split(";")
    day = date |> String.slice(0..9) |> String.split("-") |> Enum.map(& String.to_integer/1) |> List.to_tuple()
    time = date |> String.slice(11..18) |> String.split(":") |> Enum.map(& String.to_integer/1) |> List.to_tuple()
    %{:datetime => {day,time},
      :location => loc |> String.split(",") |> Enum.map(& String.to_float/1) |> List.to_tuple(),
      :stationId => id |> String.to_integer(),
      :stationName => name,
      :pollutionType => type,
      :pollutionLevel => value |> String.to_float()}
  end

  def load_all() do
    load_data("data/AirlyData-ALL-50k.csv")
  end

  def load_data(path \\ "data/AirlyData-ALL-50k.csv",limit \\1000) do
    if pid = Process.whereis(:pollution_gen_server), do: Process.exit(pid, :kill)
    if pid = Process.whereis(:pollution_value_collector_gen_statem), do: Process.exit(pid, :kill)

    measures =
      File.stream!(path)
      |> Stream.take(limit)
      |> Stream.map(&String.trim/1)
      |> Enum.map(&parse_line/1)

    stations_map =
      measures
      |> Enum.uniq_by(fn m -> m.stationId end)
      |> Enum.map(fn s ->
        clean_name = String.trim(s.stationName)
        full_name = Integer.to_string(s.stationId) <> "-" <> clean_name
        Pollutiondb.Station.add(full_name, elem(s.location, 0), elem(s.location, 1))
        station = List.first(Pollutiondb.Station.find_by_name(full_name))
        {s.stationId, station}
      end)
      |> Map.new()

    grouped_by_id = Enum.group_by(measures, fn m -> m.stationId end)

    Enum.each(grouped_by_id, fn {station_id, station_measures} ->
      station = Map.get(stations_map, station_id)
      if station do
        Enum.each(station_measures, fn m ->
          {date_tuple, time_tuple} = m.datetime
          Pollutiondb.Reading.add(
            station,
            date_tuple,
            time_tuple,
            m.pollutionType,
            m.pollutionLevel
          )
        end)
      end
    end)
  end
end
