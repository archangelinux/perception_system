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
      port: nil
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

    schedule_next_frame()
    {:ok, %{state | port: port}}
  end

  @impl true
  def handle_info(:new_frame, state) do
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
        %{state | frame_idx: 0}
      end
    schedule_next_frame()
    {:noreply, new_state}
  end

  #handles python worker process stdout
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    result = Jason.decode!(data)
    IO.inspect(result, label: "Stereo result")
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
       current_frame: state.frame_idx # the image number
     },
     state}
  end

  defp schedule_next_frame do
    Process.send_after(self(), :new_frame, @frame_interval_ms)
  end
end
