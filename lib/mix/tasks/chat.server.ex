defmodule Mix.Tasks.Chat.Server do
  use Mix.Task

  @shortdoc "Starts the chat server"

  def run(_argv), do: Chat.listen()
end
