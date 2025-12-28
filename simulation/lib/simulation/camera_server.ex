defmodule Simulation.CameraServer do
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
      dataset_path: "data/kitti/image_2", # dataset of 200 images from left and right stereo cameras
      start_time: System.monotonic_time(:millisecond)
    }

    schedule_next_frame()
    {:ok, state}
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
