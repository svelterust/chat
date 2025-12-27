defmodule Chat do
  @opts [:binary, packet: :line, reuseaddr: true, active: true]

  def listen(port \\ 4000) do
    Registry.start_link(keys: :duplicate, name: :chat)
    {:ok, socket} = :gen_tcp.listen(port, @opts)
    IO.puts("Listening on port #{port}")
    handle(socket)
  end

  defp handle(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    name = "user_#{1000 + :rand.uniform(8999)}"

    pid =
      spawn(fn ->
        Registry.register(:chat, "lobby", name)
        count = Registry.lookup(:chat, "lobby") |> length()
        msg(client, "Welcome #{name}! Online: #{count}. Type /help.")
        broadcast({:info, "#{name} joined"})
        serve(client, name)
      end)

    :gen_tcp.controlling_process(client, pid)
    handle(socket)
  end

  defp serve(client, name) do
    receive do
      {:tcp, _, data} ->
        case String.split(String.trim(data), " ", parts: 3, trim: true) do
          ["/help"] ->
            msg(client, "/who\n/nick <name>\n/msg <user> <text>")

          ["/who"] ->
            names =
              Registry.lookup(:chat, "lobby")
              |> Enum.map_join("\n", fn {_, name} -> name end)

            msg(client, names)

          ["/nick", new_name] ->
            Registry.unregister(:chat, "lobby")
            Registry.register(:chat, "lobby", new_name)
            broadcast({:info, "#{name} is now #{new_name}"})
            msg(client, "Name changed to #{new_name}")
            serve(client, new_name)

          ["/msg", to, text] ->
            case Enum.find(Registry.lookup(:chat, "lobby"), fn {_, name} -> name == to end) do
              {pid, _} -> send(pid, {:info, "[private] #{name}: #{text}"})
              _ -> msg(client, "User not found")
            end

          _ ->
            broadcast({:chat, name, String.trim(data)})
        end

        serve(client, name)

      {:chat, from, text} ->
        msg(client, "#{from}: #{text}")
        serve(client, name)

      {:info, text} ->
        msg(client, "* #{text}")
        serve(client, name)

      {:tcp_closed, _} ->
        broadcast({:info, "#{name} left"})
    end
  end

  defp msg(socket, text), do: :gen_tcp.send(socket, "#{text}\r\n")

  defp broadcast(message) do
    Registry.dispatch(:chat, "lobby", fn entries ->
      for {pid, _} <- entries, pid != self(), do: send(pid, message)
    end)
  end
end
