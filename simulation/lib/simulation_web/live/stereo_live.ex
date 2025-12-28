defmodule SimulationWeb.StereoLive do
  use SimulationWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Simulation.PubSub, "stereo_updates")
      :timer.send_interval(500, self(), :poll_stats)
    end

    {:ok,
     assign(socket,
       fps: 0.0,
       frame_count: 0,
       current_frame: 0,
       running: false,
       # Aggregated statistics across ALL processed frames
       disparity_min: nil,
       disparity_max: nil,
       disparity_sum: 0.0,
       latency_sum: 0.0,
       valid_pixels_sum: 0,
       processed_count: 0,
       history: [],
       max_history: 100
     )}
  end

  @impl true
  def handle_info(:poll_stats, socket) do
    stats = Simulation.CameraServer.get_stats()

    {:noreply,
     assign(socket,
       fps: stats[:fps] || 0.0,
       frame_count: stats[:frame_count] || 0,
       current_frame: stats[:current_frame] || 0,
       running: stats[:running] || false
     )}
  end

  @impl true
  def handle_event("start", _params, socket) do
    Simulation.CameraServer.start_processing()
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop", _params, socket) do
    Simulation.CameraServer.stop_processing()
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    Simulation.CameraServer.reset()

    # Reset LiveView stats too
    {:noreply,
     assign(socket,
       disparity_min: nil,
       disparity_max: nil,
       disparity_sum: 0.0,
       latency_sum: 0.0,
       valid_pixels_sum: 0,
       processed_count: 0,
       history: []
     )}
  end

  @impl true
  def handle_info({:stereo_result, result}, socket) do
    new_history = [result | socket.assigns.history] |> Enum.take(socket.assigns.max_history)

    # Update aggregated statistics
    mean_disp = result["mean_disparity"] || 0.0
    new_min = if socket.assigns.disparity_min, do: min(socket.assigns.disparity_min, mean_disp), else: mean_disp
    new_max = if socket.assigns.disparity_max, do: max(socket.assigns.disparity_max, mean_disp), else: mean_disp
    new_count = socket.assigns.processed_count + 1

    {:noreply,
     assign(socket,
       history: new_history,
       disparity_min: new_min,
       disparity_max: new_max,
       disparity_sum: socket.assigns.disparity_sum + mean_disp,
       latency_sum: socket.assigns.latency_sum + (result["latency_ms"] || 0.0),
       valid_pixels_sum: socket.assigns.valid_pixels_sum + (result["valid_pixels"] || 0),
       processed_count: new_count
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100" data-theme="autumn">
      <div class="container mx-auto p-8">
        <!-- Header -->
        <div class="mb-8">
          <div class="flex justify-between items-center mb-4">
            <div>
              <h1 class="text-5xl font-bold text-primary mb-2">Stereo Vision Dashboard</h1>
              <p class="text-base-content/70">Real-time stereo processing • KITTI 2015 Dataset</p>
            </div>

            <!-- Control Buttons -->
            <div class="flex gap-3">
              <%= if @current_frame >= 200 do %>
                <!-- Only show Reset when complete -->
                <button phx-click="reset" class="btn btn-primary btn-lg gap-2">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Reset
                </button>
              <% else %>
                <%= if @running do %>
                  <button phx-click="stop" class="btn btn-warning btn-lg gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Stop
                  </button>
                <% else %>
                  <button phx-click="start" class="btn btn-success btn-lg gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Start
                  </button>
                <% end %>

                <button phx-click="reset" class="btn btn-outline btn-lg gap-2">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Reset
                </button>
              <% end %>
            </div>
          </div>

          <!-- Status Badge -->
          <div class="flex gap-2 items-center">
            <%= if @running do %>
              <span class="badge badge-success badge-lg gap-2">
                <span class="animate-pulse">●</span> Processing
              </span>
            <% else %>
              <span class="badge badge-warning badge-lg">○ Stopped</span>
            <% end %>
            <%= if @current_frame >= 200 do %>
              <span class="badge badge-info badge-lg">✓ Complete</span>
            <% end %>
          </div>
        </div>

        <!-- Main Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <!-- FPS Card -->
          <div class="stats shadow-lg bg-secondary/30 text-secondary-content backdrop-blur-sm">
            <div class="stat">
              <div class="stat-figure">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  class="inline-block w-8 h-8 stroke-current"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13 10V3L4 14h7v7l9-11h-7z"
                  >
                  </path>
                </svg>
              </div>
              <div class="stat-title text-secondary-content/70">Frame Rate</div>
              <div class="stat-value"><%= Float.round(@fps, 1) %></div>
              <div class="stat-desc text-secondary-content/60">Hz (target: 30.0)</div>
            </div>
          </div>

          <!-- Frame Count Card -->
          <div class="stats shadow-lg bg-accent/30 text-accent-content backdrop-blur-sm">
            <div class="stat">
              <div class="stat-figure">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  class="inline-block w-8 h-8 stroke-current"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z"
                  >
                  </path>
                </svg>
              </div>
              <div class="stat-title text-accent-content/70">Progress</div>
              <div class="stat-value"><%= @frame_count %></div>
              <div class="stat-desc text-accent-content/60">
                Frame <%= @current_frame %> / 200
              </div>
            </div>
          </div>

          <!-- Avg Disparity Card -->
          <div class="stats shadow-lg bg-info/30 text-info-content backdrop-blur-sm">
            <div class="stat">
              <div class="stat-figure">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  class="inline-block w-8 h-8 stroke-current"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                  >
                  </path>
                </svg>
              </div>
              <div class="stat-title text-info-content/70">Avg Disparity</div>
              <div class="stat-value text-3xl"><%= avg_disparity_all(@disparity_sum, @processed_count) %></div>
              <div class="stat-desc text-info-content/60">pixels (all frames)</div>
            </div>
          </div>

          <!-- Avg Latency Card -->
          <div class="stats shadow-lg bg-success/30 text-success-content backdrop-blur-sm">
            <div class="stat">
              <div class="stat-figure">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  class="inline-block w-8 h-8 stroke-current"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
              </div>
              <div class="stat-title text-success-content/70">Avg Latency</div>
              <div class="stat-value text-3xl"><%= avg_latency_all(@latency_sum, @processed_count) %></div>
              <div class="stat-desc text-success-content/60">ms per frame</div>
            </div>
          </div>
        </div>

        <!-- Stereo Processing Summary -->
        <div class="card bg-base-200 shadow-lg mb-8">
          <div class="card-body">
            <h2 class="card-title text-primary text-2xl mb-4">
              Stereo Matching Summary
            </h2>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <!-- Disparity Range -->
              <div class="stat bg-base-100 rounded-lg p-4">
                <div class="stat-title">Disparity Range</div>
                <div class="stat-value text-primary text-2xl">
                  <%= format_range(@disparity_min, @disparity_max) %>
                </div>
                <div class="stat-desc">min → max across dataset</div>
              </div>

              <!-- Total Depth Pixels -->
              <div class="stat bg-base-100 rounded-lg p-4">
                <div class="stat-title">Total Valid Pixels</div>
                <div class="stat-value text-accent text-2xl">
                  <%= format_number(@valid_pixels_sum) %>
                </div>
                <div class="stat-desc">depth estimates computed</div>
              </div>

              <!-- Frames Processed -->
              <div class="stat bg-base-100 rounded-lg p-4">
                <div class="stat-title">Stereo Matches</div>
                <div class="stat-value text-primary text-2xl">
                  <%= @processed_count %>
                </div>
                <div class="stat-desc">frame pairs processed</div>
              </div>
            </div>

            <div class="divider"></div>

            <!-- Performance Metrics Table -->
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Metric</th>
                    <th>Min</th>
                    <th>Average</th>
                    <th>Max</th>
                    <th>Latest</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="font-semibold">Disparity (px)</td>
                    <td><%= format_float(@disparity_min) %></td>
                    <td><%= avg_disparity_all(@disparity_sum, @processed_count) %></td>
                    <td><%= format_float(@disparity_max) %></td>
                    <td><%= latest_disparity(@history) %></td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Latency (ms)</td>
                    <td><%= min_latency(@history) %></td>
                    <td><%= avg_latency_all(@latency_sum, @processed_count) %></td>
                    <td><%= max_latency(@history) %></td>
                    <td><%= latest_latency(@history) %></td>
                  </tr>
                  <tr>
                    <td class="font-semibold">Valid Pixels</td>
                    <td><%= min_valid_pixels(@history) %></td>
                    <td><%= avg_valid_pixels(@valid_pixels_sum, @processed_count) %></td>
                    <td><%= max_valid_pixels(@history) %></td>
                    <td><%= latest_valid_pixels(@history) %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Image Viewer Section (placeholder for future) -->
        <div class="card bg-base-200 shadow-lg">
          <div class="card-body">
            <h2 class="card-title text-secondary text-2xl mb-4">
              Frame Viewer
              <span class="badge badge-warning">Coming Soon</span>
            </h2>
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
              <div class="bg-base-300 rounded-lg p-8 text-center">
                <p class="text-base-content/50">Left Camera</p>
                <div class="aspect-video bg-base-100 rounded mt-2 flex items-center justify-center">
                  <span class="text-base-content/30">Image Preview</span>
                </div>
              </div>
              <div class="bg-base-300 rounded-lg p-8 text-center">
                <p class="text-base-content/50">Right Camera</p>
                <div class="aspect-video bg-base-100 rounded mt-2 flex items-center justify-center">
                  <span class="text-base-content/30">Image Preview</span>
                </div>
              </div>
              <div class="bg-base-300 rounded-lg p-8 text-center">
                <p class="text-base-content/50">Disparity Map</p>
                <div class="aspect-video bg-base-100 rounded mt-2 flex items-center justify-center">
                  <span class="text-base-content/30">Disparity Heatmap</span>
                </div>
              </div>
            </div>
            <div class="mt-4 flex justify-center">
              <input
                type="range"
                min="0"
                max="200"
                value={@current_frame}
                class="range range-primary w-full max-w-2xl"
                disabled
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for aggregated stats
  defp avg_disparity_all(_sum, 0), do: "—"

  defp avg_disparity_all(sum, count) do
    Float.round(sum / count, 2)
  end

  defp avg_latency_all(_sum, 0), do: "—"

  defp avg_latency_all(sum, count) do
    Float.round(sum / count, 1)
  end

  defp avg_valid_pixels(_sum, 0), do: "—"

  defp avg_valid_pixels(sum, count) do
    format_number(div(sum, count))
  end

  defp format_range(nil, nil), do: "—"
  defp format_range(min, max), do: "#{Float.round(min, 1)} → #{Float.round(max, 1)}"

  defp format_float(nil), do: "—"
  defp format_float(num), do: Float.round(num, 2)

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: to_string(num)

  # Latest values from history
  defp latest_disparity([]), do: "—"
  defp latest_disparity([h | _]), do: Float.round(h["mean_disparity"] || 0, 2)

  defp latest_latency([]), do: "—"
  defp latest_latency([h | _]), do: Float.round(h["latency_ms"] || 0, 1)

  defp latest_valid_pixels([]), do: "—"
  defp latest_valid_pixels([h | _]), do: format_number(h["valid_pixels"] || 0)

  # Min/Max from history
  defp min_latency([]), do: "—"

  defp min_latency(history) do
    history
    |> Enum.map(& &1["latency_ms"])
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> "—"
      values -> values |> Enum.min() |> Float.round(1)
    end
  end

  defp max_latency([]), do: "—"

  defp max_latency(history) do
    history
    |> Enum.map(& &1["latency_ms"])
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> "—"
      values -> values |> Enum.max() |> Float.round(1)
    end
  end

  defp min_valid_pixels([]), do: "—"

  defp min_valid_pixels(history) do
    history
    |> Enum.map(& &1["valid_pixels"])
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> "—"
      values -> values |> Enum.min() |> format_number()
    end
  end

  defp max_valid_pixels([]), do: "—"

  defp max_valid_pixels(history) do
    history
    |> Enum.map(& &1["valid_pixels"])
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> "—"
      values -> values |> Enum.max() |> format_number()
    end
  end
end
