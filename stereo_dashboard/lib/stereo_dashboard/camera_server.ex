defmodule StereoDashboard.CameraServer do
    use GenServer

    #declare module attribute (like a global var)
    @frame_interval_ms 33  #~30Hz

    #starts the GenServer process, registering it globally
    #underscore means argument is unused
    # // [] default argument value
    def start_link(_opts \\ []) do
        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    #when any process runs this line, OTP sends a message to CameraServer, the caller blocks; OTP remembers who made the call
    #internally, OTP automatically passes a hidden 'from' value: {caller_pid, unique_ref}
    def get_stats do
        GenServer.call(__MODULE__, :get_stats) #synchronous request
    end

    #callbacks (@impl true for compiler)
    @impl true
    def init(_state) do
        #map
        state = %{
            frame_count: 0,
            frames: [],
            max_window: 100,
            start_time: System.monotonic_time(:millisecond)
        }
        #elixir rule: state is immutable, but new version can be created

        schedule_next_frame() #schedules the first frame
        {:ok, state} #return tuple value
    end

    @impl true
    #:new_frame is an atom, which is a constant symbol (like enums)
    #this function runs when the process receives a message
    def handle_info(:new_frame, state) do
        #random data placeholders
        #left = :rand.uniform()
        #right = :rand.uniform()
        #disparity = abs(left - right)
        {output, 0} = System.cmd("python3", [
            "../stereo_processor.py",
            "../stereo_kitti_images/aloeL.jpg",
            "../stereo_kitti_images/aloeR.jpg"
        ])

        result = Jason.decode!(output)

        frame = %{
            left: 0,
            right: 0,
            disparity: result["mean"]
        }

        #rolling window logic
        frames = [frame | state.frames] |> Enum.take(state.max_window)
        #prepends frame to the list (O(1) operation, linked list)
        # |>

        new_state = %{
          state | frame_count: state.frame_count + 1,
            frames: frames
        }

        schedule_next_frame()
        {:noreply, new_state} #dont reply just keep running with the new state
    end


    @impl true
    #triggered by GenServer.call
    #_from contains caller infor (unused)
    def handle_call(:get_stats, _from, state) do
        elapsed_ms = System.monotonic_time(:millisecond) - state.start_time

        fps =
          if elapsed_ms > 0 do
            state.frame_count / (elapsed_ms / 1000) #returns this value
          else
            0.0
          end
        #if statements in elixir return values (is an expression, not a statement)

        mean_disparity =
          case state.frames do
            [] -> 0.0 #if not frames then mean = 0.0
            frames -> #else mean = sum(f["disparity"] for f in frames)/len(frames)
            frames
            |> Enum.map(& &1.disparity) #anonymous function with &1 as first argument
            |> Enum.sum()
            |> Kernel./(length(frames)) #explicit division function
            #data transformation pipeline structure value |> function(arg) --> function (value, arg)
          end

        {:reply,
        %{frame_count: state.frame_count, fps: fps, mean_disparity: mean_disparity},
         state}
         #tell OTP to send a reply
         #return tuple structure: {:reply, reply_data, state} --> {reply or noreply, what the caller recieves, new internal state }
    end

    #private function to schedule for OTP timer
    #self() is current process PID
    #sends new frame to itself after delay
    defp schedule_next_frame do
        Process.send_after(self(), :new_frame, @frame_interval_ms)
    end
end
