defmodule StereoDashboardWeb.StereoLive do
  use StereoDashboardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(500, self(), :update)
    end

    {:ok,
      assign(socket,
        stats: %{},
        fps: 0.0,
        frame_count: 0,
        mean_disparity: 0.0,
        images: %{}
      )}
  end

  @impl true
  def handle_info(:update, socket) do
    stats = StereoDashboard.CameraServer.get_stats()
    images = StereoDashboard.CameraServer.get_latest_images()


    {:noreply,
      assign(socket,
        stats: stats,
        fps: stats[:fps] || 0.0,
        frame_count: stats[:frame_count] || 0,
        mean_disparity: stats[:mean_disparity] || 0.0,
        images: images || %{}
      )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 bg-white ">
      <h1 class="text-3xl font-bold mb-6 text-gray-700">Stereo Vision Dashboard</h1>

      <div class="grid grid-cols-3 gap-4 mb-6">
        <div class="bg-blue-100 p-4 rounded">
          <div class="text-sm text-gray-600">FPS</div>
          <div class="text-2xl font-bold text-blue-900"><%= Float.round(@fps, 1) %></div>
        </div>

        <div class="bg-green-50 p-4 rounded">
          <div class="text-sm text-gray-600">Frames</div>
          <div class="text-2xl font-bold text-green-900"><%= @frame_count %></div>
        </div>

        <div class="bg-purple-100 p-4 rounded">
          <div class="text-sm text-gray-600">Mean Disparity</div>
          <div class="text-2xl font-bold text-purple-900"><%= Float.round(@mean_disparity, 3) %></div>
        </div>
      </div>

      <div class="bg-gray-50 p-4 rounded mb-6">
        <div class="text-sm text-gray-600 mb-2">Raw Stats</div>
        <pre class="text-xs text-gray-700"><%= inspect(@stats, pretty: true) %></pre>
      </div>

      <div class="bg-gray-100 p-4 rounded">
      <h2 class="text-xl font-bold mb-4">Full Matplotlib Visualization</h2>
      <%= if @images[:full_figure] do %>
      <img src={"data:image/png;base64,#{@images.full_figure}"}
         alt="Full Analysis"
         class="w-full max-w-4xl mx-auto" />
      <% end %>
    </div>
    </div>
    """
  end
end
