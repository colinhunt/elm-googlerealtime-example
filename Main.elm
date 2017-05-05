port module Main exposing (main)

import Html exposing (..)
import Dict exposing (Dict)
import Json.Decode as Decode
import Types exposing (Model, Msg(..))
import View exposing (view)
import Gapi
import Todos exposing (Todo)


-- Init


initModel : ( Model, Cmd msg )
initModel =
    let
        ( gapiState, gapiCmd ) =
            Gapi.init
    in
        { todos = Dict.empty
        , gapiState = gapiState
        , newTodoText = ""
        }
            ! [ gapiCmd ]



-- Update


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case Debug.log "msg" msg of
        ReceiveItem ( id, todo ) ->
            { model | todos = Dict.insert id todo model.todos } ! []

        ReceiveAllData todoItems ->
            { model | todos = Dict.fromList todoItems } ! []

        SignIn ->
            ( model, Gapi.signIn )

        SignOut ->
            ( model, Gapi.signOut )

        TodosMsg msg_ ->
            updateTodos msg_ model

        GapiMsg gapiMsg ->
            Gapi.update gapiMsg model.gapiState
                |> (\( state, cmd ) ->
                        { model | gapiState = state } ! [ cmd ]
                   )


updateTodos : Todos.Msg -> Model -> ( Model, Cmd msg )
updateTodos msg model =
    case msg of
        Todos.Input text ->
            { model | newTodoText = text } ! []

        Todos.New ->
            addTodo model

        Todos.Toggle id ->
            toggleTodo model id

        Todos.Delete id ->
            deleteTodo model id

        Todos.Cancel ->
            { model | newTodoText = "" } ! []


addTodo : Model -> ( Model, Cmd msg )
addTodo model =
    let
        id =
            1 + ((List.maximum <| Dict.keys model.todos) |> Maybe.withDefault 0)

        todo =
            Todo model.newTodoText False
    in
        { model | todos = Dict.insert id todo model.todos }
            ! [ persistTodo ( id, todo ) ]


toggleTodo : Model -> Int -> ( Model, Cmd msg )
toggleTodo model id =
    case Dict.get id model.todos of
        Just todo ->
            let
                newTodo =
                    Todo todo.text (not todo.completed)
            in
                { model | todos = Dict.insert id newTodo model.todos }
                    ! [ persistTodo ( id, newTodo ) ]

        Nothing ->
            model ! []


deleteTodo : Model -> Int -> ( Model, Cmd msg )
deleteTodo model id =
    { model | todos = Dict.remove id model.todos } ! [ removeTodo id ]



-- Ports


port persistTodo : ( Int, Todo ) -> Cmd msg


port removeTodo : Int -> Cmd msg


port receiveItem : (Decode.Value -> msg) -> Sub msg


port receiveAllData : (List ( Int, Todo ) -> msg) -> Sub msg



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Gapi.subscriptions model |> Sub.map GapiMsg
        , receiveItem itemDecoder
        , receiveAllData ReceiveAllData
        ]


itemDecoder : Decode.Value -> msg
itemDecoder json =
    case Decode.decodeValue decode json of
        Ok item ->
            ReceiveTodo item

        Err reason ->
            ReceiveItemError reason



-- Main


main : Program Never Model Msg
main =
    Html.program
        { init = initModel
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
