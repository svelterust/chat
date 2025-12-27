FROM elixir:1.19-alpine

WORKDIR /app

COPY mix.exs ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

COPY . .

ENV MIX_ENV=prod

RUN mix do compile

EXPOSE 4000

CMD ["mix", "chat.server"]
