defmodule Chat do
  @opts [:binary, packet: :line, reuseaddr: true, active: true]

  def listen(port \\ 4000) do
    IO.puts("Listening on port #{port}")
    Registry.start_link(keys: :duplicate, name: :chat)
    {:ok, socket} = :gen_tcp.listen(port, @opts)
    handle(socket)
  end

  defp handle(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    name = "user_#{1000 + :rand.uniform(8999)}"

    pid =
      spawn(fn ->
        greet(client)
        register(name)
        IO.puts("User #{name} has connected")
        serve(client, name)
      end)

    :gen_tcp.controlling_process(client, pid)
    handle(socket)
  end

  defp serve(client, name) do
    receive do
      {:tcp, _socket, msg} ->
        broadcast({:message, name, msg})
        serve(client, name)

      {:message, from_name, msg} ->
        message(client, "#{from_name}: #{String.trim(msg)}")
        serve(client, name)

      {:connected, from_name} ->
        message(client, "User #{from_name} has connected")
        serve(client, name)

      {:disconnected, from_name} ->
        message(client, "User #{from_name} has disconnected")
        serve(client, name)

      {:tcp_closed, _socket} ->
        IO.puts("User #{name} has disconnected")
        broadcast({:disconnected, name})
    end
  end

  defp greet(client) do
    users = Registry.lookup(:chat, "lobby") |> length()

    :gen_tcp.send(
      client,
      "Welcome to the chat! There are currently #{users} other #{if users == 1, do: "user", else: "users"} online.\r\n"
    )
  end

  defp register(name) do
    Registry.register(:chat, "lobby", name)
    broadcast({:connected, name})
  end

  defp message(client, msg) do
    :gen_tcp.send(client, "#{msg}\r\n")
  end

  defp broadcast(message) do
    Registry.dispatch(:chat, "lobby", fn entries ->
      for {pid, _} <- entries, pid != self(), do: send(pid, message)
    end)
  end
end
