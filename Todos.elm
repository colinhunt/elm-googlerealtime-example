module Todos exposing (view, Todo, Msg(..))

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


type alias Todo =
    { text : String
    , completed : Bool
    }


type Msg
    = Input String
    | New
    | Toggle Int
    | Delete Int
    | Cancel


view : String -> List ( Int, Todo ) -> Html Msg
view newTodoText todos =
    div []
        [ todoForm newTodoText
        , todoList (not << .completed) todos
        , todoList .completed todos
        ]


todoList : (Todo -> Bool) -> List ( Int, Todo ) -> Html Msg
todoList filterTest todos =
    ol [] (todos |> List.filter (\( i, t ) -> filterTest t) |> List.map todo)


todoForm : String -> Html Msg
todoForm newTodoText =
    Html.form [ onSubmit New ]
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


todo : ( Int, Todo ) -> Html Msg
todo ( id, todo ) =
    let
        className =
            if todo.completed then
                "completedTodo"
            else
                ""
    in
        li [ class className ]
            [ span
                [ onClick <| Toggle id ]
                [ text todo.text ]
            , button [ onClick <| Delete id ] []
            ]
