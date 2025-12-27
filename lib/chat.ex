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
        register(name)
        greet(client, name)
        IO.puts("User #{name} has connected")
        serve(client, name)
      end)

    :gen_tcp.controlling_process(client, pid)
    handle(socket)
  end

  defp serve(client, name) do
    receive do
      {:tcp, _socket, msg} ->
        trimmed_msg = msg |> String.trim()

        case String.split(trimmed_msg, " ", parts: 3, trim: true) do
          ["/help"] ->
            help(client)

          ["/who"] ->
            who(client)

          ["/msg", user, text] ->
            msg(client, name, user, text)

          ["/nick", new_name] ->
            nick(client, new_name)
            serve(client, new_name)

          _ ->
            broadcast({:message, name, trimmed_msg})
        end

        serve(client, name)

      {:message, from_name, msg} ->
        message(client, "#{from_name}: #{msg}")
        serve(client, name)

      {:private_message, from_name, msg} ->
        message(client, "[private] #{from_name}: #{msg}")
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

  defp help(client) do
    message(
      client,
      "/who (lists users)\n/nick <name> (changes your name)\n/msg <user> <text> (sends private message to user)"
    )
  end

  defp who(client) do
    names =
      Registry.lookup(:chat, "lobby") |> Enum.map(fn {_, name} -> name end) |> Enum.join("\n")

    message(client, names)
  end

  defp msg(client, from_user, to_user, msg) do
    result = Registry.lookup(:chat, "lobby") |> Enum.find(fn {_, name} -> to_user == name end)

    case result do
      {pid, _} ->
        send(pid, {:private_message, from_user, msg})

      _ ->
        message(client, "User not found")
    end
  end

  defp nick(client, new_name) do
    Registry.unregister(:chat, "lobby")
    Registry.register(:chat, "lobby", new_name)
    message(client, "Your name is now #{new_name}")
  end

  defp greet(client, name) do
    users = Registry.lookup(:chat, "lobby") |> length()

    message(
      client,
      "Welcome #{name}! There #{if users == 1, do: "is", else: "are"} currently #{users} #{if users == 1, do: "user", else: "users"} online. To view commands, type /help."
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
