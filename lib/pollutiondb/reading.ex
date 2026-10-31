defmodule Pollutiondb.Reading do
  use Ecto.Schema
  require Ecto.Query

  schema "readings" do
    field :date, :date
    field :time, :time
    field :type, :string
    field :value, :float
    belongs_to :station, Pollutiondb.Station
  end

  def add_now(station, type, value) do
    %Pollutiondb.Reading{} |>
    changeset(%{date: Date.utc_today, time: Time.utc_now,
      type: type, value: value, station_id: station.id})|> Pollutiondb.Repo.insert()
  end

  def add(station, {year, month, day}, {hour, minute, second}, type, value) do
    {:ok, elixir_date} = Date.new(year, month, day)
    {:ok, elixir_time} = Time.new(hour, minute, second)
    %Pollutiondb.Reading{} |>
      changeset(%{date: elixir_date, time: elixir_time,
        type: type, value: value, station_id: station.id})|> Pollutiondb.Repo.insert()
  end

  def changeset(reading, changemap) do
    reading
    |> Ecto.Changeset.cast(changemap, [:date, :time, :type, :value, :station_id])
    |> Ecto.Changeset.validate_required([:date, :time, :type, :value, :station_id])
    |> Ecto.Changeset.unique_constraint(:name)
  end
  def find_by_date(date) do
    Pollutiondb.Repo.all(
      Ecto.Query.where(Pollutiondb.Reading, date: ^date) )
  end
end
