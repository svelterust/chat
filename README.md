# chat

Minimal chat server similar to IRC implemented in Elixir.

```
❯ mix chat.server
Compiling 1 file (.ex)
Generated chat app
Listening on port 4000
```

## Demo

### Server

```
❯ mix chat.server
Compiling 1 file (.ex)
Generated chat app
Listening on port 4000
User user_6026 has connected
User user_5680 has connected
```

### user_6026

```
❯ nc localhost 4000
Welcome to the chat! There are currently 0 other users online.
What's up guys!
User user_5680 has connected
user_5680: Hey there team
user_5680: Any updates?
Not yet, we need to update stuff
user_5680: Ok cool keep me updated
```

### user_5680

```
❯ nc localhost 4000
Welcome to the chat! There are currently 1 other user online.
Hey there team
Any updates?
user_6026: Not yet, we need to update stuff
Ok cool keep me updated
```
