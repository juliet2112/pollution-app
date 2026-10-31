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

  def load_data(path \\ "data/AirlyData-ALL-50k.csv") do
    if pid = Process.whereis(:pollution_gen_server), do: Process.exit(pid, :kill)
    if pid = Process.whereis(:pollution_value_collector_gen_statem), do: Process.exit(pid, :kill)

    measures = path
               |> File.read!()
               |> String.trim()
               |> String.split("\n")
               |> Enum.map(&parse_line/1)

    measures
    |> Enum.uniq_by(fn m -> m.stationId end)
    |> Enum.each(fn s ->
      clean_name = String.trim(s.stationName)
      full_name = Integer.to_string(s.stationId) <> clean_name
      Pollutiondb.Station.add(full_name, elem(s.location, 0), elem(s.location, 1))
    end)

    grouped_by_id = Enum.group_by(measures, fn m -> m.stationId end)

    Enum.each(grouped_by_id, fn {station_id, station_measures} ->
      clean_name = String.trim(Enum.at(station_measures, 0).stationName)
      station_name = Integer.to_string(station_id) <> clean_name

      station = List.first(Pollutiondb.Station.find_by_name(station_name))
      Enum.each(station_measures, fn m ->
        {date_tuple, time_tuple} = m.datetime
        Pollutiondb.Reading.add(
          station,
          date_tuple,
          time_tuple,
          String.to_charlist(m.pollutionType),
          m.pollutionLevel
        )
      end)
    end)
  end
end