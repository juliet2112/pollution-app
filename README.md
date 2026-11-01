# Real-Time Environmental Telemetry Platform

> A reactive web application built with **Elixir & Phoenix LiveView** for streaming and visualizing data from measurement stations in real-time.

---

## Demo

![Real-Time Dashboard Demo](assets/demo.gif)

---

## Tech Stack

* **Language:** Elixir 1.20+
* **Framework:** Phoenix Framework & Phoenix LiveView (v0.20+)
* **Asynchronous Architecture:** OTP `GenServer`, `Phoenix.PubSub`, WebSockets
* **Data Layer:** Ecto & SQLite3
* **User Interface:** Phoenix HEEx & Tailwind CSS

---

## System Architecture

The system is based on the Erlang/BEAM platform's distributed actor model:

```text
[ SQLite3 Database ]
       │
       ▼ (Ecto Queries: cursor sorting & limit)
[ Pollutiondb.Streamer (GenServer) ]
       │
       ▼ (Phoenix.PubSub broadcast: "readings", {:batch, datetime, readings})
[ Phoenix.Channel / WebSocket Connection ]
       │
       ▼ (LiveView DOM Diffing: append-only stream)
[ Client Browser (LiveView Streams & CSS Animations) ]
 ```

1. **Telemetry Engine (`Pollutiondb.Streamer`):**
   * Stateful `GenServer` process managing a virtual clock and a database timeline cursor.
   * Periodic broadcasting of reading batches (`:batch`) via `Phoenix.PubSub` every 1 second (`Process.send_after/3`).
   * Seamless timeline looping upon reaching the end of available historical data.
2. **Reactive View (`PollutiondbWeb.ReadingLive`):**
   * Asynchronous PubSub event handling using `handle_info/2`.
   * Stateless, append-only log stream implemented via `phx-update="stream"`, eliminating memory overhead in the browser DOM.
   * Dynamic station selector (`handle_event/3`) that triggers asynchronous parameter updates in the `Streamer` and clears the interface (`reset: true`).

---

## Local Setup

### Prerequisites
* **Elixir** and **Erlang/OTP** installed
* The `mix` build tool

### Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/juliet2112/pollution-app.git
   cd pollution-app
   ```

2. **Fetch dependencies and initialize the database:**
   ```bash
   mix setup
   ```

3. **Start the Phoenix server:**
   ```bash
   mix phx.server
   ```

4. **Open the application in your browser:**
   Navigate to: [`http://localhost:4000`](http://localhost:4000)
