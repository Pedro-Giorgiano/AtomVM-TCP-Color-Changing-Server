-module(myapp).

-define(NEOPIXEL_PIN, 4).
-define(NUM_PIXELS, 4).

-export([start/0, accept/2, handle_client/2, set_led_color/2, process_message/2]).

start() ->
    %% Wifi and pass
    Creds = [
        {ssid, "NameOfYourNetwork"},
        {psk, "PassOfYourNetwork"}
    ],
    
    %% Connect to wifi
    case network:wait_for_sta(Creds, 30000) of
        {ok, {Address, Netmask, Gateway}} ->
            io:format("Wi-Fi connected! IP: ~s, Netmask: ~s, Gateway: ~s~n",
                      [to_string(Address), to_string(Netmask), to_string(Gateway)]),
            %% Init tcp server after wifi connection
            start_tcp_server();
        Error ->
            io:format("Error connecting to Wi-Fi: ~p~n", [Error])
    end.

start_tcp_server() ->
    {ok, ListenSocket} = gen_tcp:listen(80, [{active, false}, {reuseaddr, true}]),
    io:format("TCP server listening on port 80~n"),
    {ok, NeoPixel} = neopixel:start(?NEOPIXEL_PIN, ?NUM_PIXELS),
    ok = neopixel:clear(NeoPixel),
    accept(NeoPixel ,ListenSocket).

accept(NeoPixel, ListenSocket) ->
    io:format("Esperando por conexões...~n"),
    {ok, ClientSocket} = gen_tcp:accept(ListenSocket),
    PeernameStr = peer_address(ClientSocket),
    io:format("Conexão aceita de ~s~n", [PeernameStr]),
    spawn(fun() -> handle_client(NeoPixel, ClientSocket) end),
    accept(NeoPixel ,ListenSocket).
    

handle_client(NeoPixel, Socket) ->
    io:format("Waiting for client data ...~n"),
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            process_message(NeoPixel, Data),
            handle_client(NeoPixel ,Socket);
        {error, closed} ->
            io:format("Connection closed by client ~n"),
            gen_tcp:close(Socket),
            ok
    end.



process_message(NeoPixel, Data) ->
    
    case string:split(Data, "\r\n\r\n", all) of
        [Headers, Body] ->
            io:format("Headers: ~p~n", [Headers]),
            io:format("Body: ~p~n", [Body]),

            CleanBody = string:trim(Body),
            io:format("CleanBody: ~p~n", [CleanBody]),

            % Verify if req body is empty before decode it
            case CleanBody of
                "" ->
                    io:format("req body is empty~n"),
                    ok;
                _ ->
                    BinaryBody = list_to_binary(CleanBody),
                    io:format("BinBody: ~p~n", [BinaryBody]),

                    Json = jsx:decode(BinaryBody),
                    R = maps:get(<<"r">>, Json),
                    G = maps:get(<<"g">>, Json),
                    B = maps:get(<<"b">>, Json),
                    RGB_Tuple = {R, G, B},
                    io:format("Tupla RGB: ~p~n", [RGB_Tuple]),
                    set_led_color(NeoPixel,RGB_Tuple)
            end;
        _ ->
            io:format("Invalid request format~n"),
            ok
    end.



set_led_color(NeoPixel, {R, G, B}) ->
    neopixel:set_pixel_rgb(NeoPixel,0, R, G, B),
    neopixel:set_pixel_rgb(NeoPixel,1, R, G, B),
    neopixel:set_pixel_rgb(NeoPixel,2, R, G, B), 
    neopixel:set_pixel_rgb(NeoPixel,3, R, G, B),  
    neopixel:refresh(NeoPixel),
    io:format("LED color changed to R:~p, G:~p, B:~p~n", [R, G, B]),
    ok.

peer_address(Socket) ->
    {ok, Peername} = inet:peername(Socket),
    to_string(Peername).

to_string({{A, B, C, D}, Port}) ->
    io_lib:format("~p.~p.~p.~p:~p", [A, B, C, D, Port]);
to_string({A, B, C, D}) ->
    io_lib:format("~p.~p.~p.~p", [A, B, C, D]).