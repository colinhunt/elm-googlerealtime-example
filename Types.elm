module Types exposing (Model, Msg(..))

import Dict exposing (Dict)
import Gapi
import Todos exposing (Todo)


type alias Model =
    { gapiState : Gapi.State
    , todos : Dict Int Todo
    , newTodoText : String
    }


type Msg
    = SignIn
    | SignOut
    | ReceiveTodo ( Int, Todo )
    | ReceiveAllData (List ( Int, Todo ))
    | TodosMsg Todos.Msg
    | GapiMsg Gapi.Msg
