defmodule Simulation.CameraServer do
  @moduledoc """
    processes input data stream of 200 images from left and right stereo cameras at 30 Hz
    testing dataset from KITTI stereo/scene flow 2015
  """
  use GenServer

  @frame_interval_ms 33 # 30 fps

  # public API
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def start_processing do
    GenServer.call(__MODULE__, :start_processing)
  end

  def stop_processing do
    GenServer.call(__MODULE__, :stop_processing)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # callbacks

  @impl true
  def init(_state) do
    state = %{
      frame_idx: 0,
      frame_count: 0,
      frames: [],
      max_window: 100,
      dataset_path: "data/kitti/image_2",
      start_time: System.monotonic_time(:millisecond),
      port: nil,
      running: false,  # Start in stopped state
      timer_ref: nil
    }

    #spawn stereo worker python script
    python_path = System.find_executable("python3") || "/opt/homebrew/bin/python3"
    worker_path = Path.join([File.cwd!(), "workers", "stereo_worker.py"])

    port = Port.open({:spawn_executable, python_path},
      [
        :binary,
        :exit_status,
        args: [worker_path]
      ])

    # Don't auto-start processing
    {:ok, %{state | port: port}}
  end

  @impl true
  def handle_info(:new_frame, state) do
    if not state.running do
      # If stopped, don't process or schedule next frame
      {:noreply, state}
    else
      idx =
        state.frame_idx
        |> Integer.to_string()
        |> String.pad_leading(6, "0")

      left_path = "#{state.dataset_path}/#{idx}_10.png"
      right_path = "#{state.dataset_path}/#{idx}_11.png"

      new_state =
        if File.exists?(left_path) and File.exists?(right_path) do
          # pass paths/references
          frame = %{
            idx: state.frame_idx,
            left: left_path,
            right: right_path
          }
          payload = Jason.encode!(%{
            left: frame.left,
            right: frame.right
          })
          Port.command(state.port, payload <> "\n") # writes data to python process's stdin

          %{
            state
            | frame_idx: state.frame_idx + 1,
              frame_count: state.frame_count + 1,
              frames: [frame | state.frames] |> Enum.take(state.max_window)
          }

        else
          # Reached end of dataset - stop processing
          IO.puts("[camera_server] Finished processing all frames")
          %{state | running: false}
        end

      if new_state.running do
        schedule_next_frame()
      end

      {:noreply, new_state}
    end
  end

  #handles python worker process stdout
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    result = Jason.decode!(data)
    IO.inspect(result, label: "Stereo result")

    # Broadcast to LiveView subscribers
    Phoenix.PubSub.broadcast(Simulation.PubSub, "stereo_updates", {:stereo_result, result})

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    elapsed_ms =
      System.monotonic_time(:millisecond) - state.start_time

    fps =
      if elapsed_ms > 0 do
        state.frame_count / (elapsed_ms / 1000)
      else
        0.0
      end

    {:reply,
     %{
       frame_count: state.frame_count,
       fps: fps,
       current_frame: state.frame_idx, # the image number
       running: state.running
     },
     state}
  end

  @impl true
  def handle_call(:start_processing, _from, state) do
    if not state.running do
      schedule_next_frame()
      {:reply, :ok, %{state | running: true, start_time: System.monotonic_time(:millisecond)}}
    else
      {:reply, {:error, :already_running}, state}
    end
  end

  @impl true
  def handle_call(:stop_processing, _from, state) do
    {:reply, :ok, %{state | running: false}}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    # Reset to initial state (but keep port alive)
    {:reply, :ok,
     %{
       state
       | frame_idx: 0,
         frame_count: 0,
         frames: [],
         running: false,
         start_time: System.monotonic_time(:millisecond)
     }}
  end

  defp schedule_next_frame do
    Process.send_after(self(), :new_frame, @frame_interval_ms)
  end
end
