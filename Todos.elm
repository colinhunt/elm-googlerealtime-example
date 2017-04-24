module Todos exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


type alias State =
    { todos : List Todo
    , newTodoId : Int
    , newTodoText : String
    }


type alias Todo =
    { id : Int
    , text : String
    , completed : Bool
    }


type Msg
    = Input String
    | NewTodo
    | ToggleTodo Int
    | DeleteTodo Int
    | Cancel


initState : State
initState =
    { todos = [], newTodoId = 0, newTodoText = "" }


update : Msg -> State -> State
update msg state =
    case msg of
        Input text ->
            { state | newTodoText = text }

        NewTodo ->
            addTodo state

        ToggleTodo id ->
            toggleTodo state id

        DeleteTodo id ->
            deleteTodo state id

        Cancel ->
            { state | newTodoText = "" }


addTodo : State -> State
addTodo state =
    let
        todo =
            Todo state.newTodoId state.newTodoText False
    in
        { state
            | newTodoText = ""
            , newTodoId = state.newTodoId + 1
            , todos = todo :: state.todos
        }


toggleTodo : State -> Int -> State
toggleTodo state id =
    { state
        | todos =
            List.map
                (\t ->
                    if t.id == id then
                        Todo id t.text (not t.completed)
                    else
                        t
                )
                state.todos
    }


deleteTodo : State -> Int -> State
deleteTodo state id =
    { state | todos = List.filter (\t -> t.id /= id) state.todos }


view : State -> Html Msg
view { newTodoText, todos } =
    div []
        [ todoForm newTodoText
        , ul [] (todos |> List.map todo)
        ]


todoForm : String -> Html Msg
todoForm newTodoText =
    Html.form [ onSubmit NewTodo ]
        [ input
            [ type_ "text"
            , placeholder "Add todo..."
            , onInput Input
            , value newTodoText
            ]
            []
        , button [ class "submit", type_ "submit" ] [ text "+" ]
        , button [ class "cancel", type_ "button", onClick Cancel ] [ text "x" ]
        ]


todo : Todo -> Html Msg
todo todo =
    let
        className =
            if todo.completed then
                "completedTodo"
            else
                ""
    in
        li [ class className ]
            [ span
                [ onClick <| ToggleTodo todo.id ]
                [ text todo.text ]
            , button [ onClick <| DeleteTodo todo.id ] []
            ]
