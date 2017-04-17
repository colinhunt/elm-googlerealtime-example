port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Gapi


type alias Model =
    { user : Gapi.User
    , newTodoText : String
    , data : Data
    }


type alias Data =
    { todos : List Todo
    , newTodoId : Int
    }


type alias Todo =
    { id : Int
    , text : String
    , completed : Bool
    }


type Msg
    = SignIn
    | SignOut
    | ReceiveData Data
    | Input String
    | NewTodo
    | ToggleTodo Int
    | DeleteTodo Int
    | Cancel
    | UpdateUser Gapi.User


gapiConfig : Data -> Gapi.Config Data
gapiConfig data =
    { client_id =
        "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com"
    , file_name = "elm-realtime-example"
    , folder_name = "ElmRealtimeExample"
    , initData = data
    }


initModel : ( Model, Cmd msg )
initModel =
    let
        data =
            Data [] 0
    in
        ( { user = Gapi.SignedOut
          , newTodoText = ""
          , data = data
          }
        , gapiInit (gapiConfig data)
        )


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case Debug.log "msg" msg of
        ReceiveData data ->
            ( { model | data = data }, Cmd.none )

        UpdateUser user ->
            ( { model | user = user }, Cmd.none )

        SignIn ->
            ( model, Gapi.signIn )

        SignOut ->
            ( model, Gapi.signOut )

        Input text ->
            ( { model | newTodoText = text }, Cmd.none )

        NewTodo ->
            persist (addTodo model)

        ToggleTodo id ->
            persist (toggleTodo model id)

        DeleteTodo id ->
            persist (deleteTodo model id)

        Cancel ->
            ( { model | newTodoText = "" }, Cmd.none )


persist : Model -> ( Model, Cmd msg )
persist ({ data } as model) =
    ( model, sendData data )


addTodo : Model -> Model
addTodo ({ data } as model) =
    let
        todo =
            Todo data.newTodoId model.newTodoText False
    in
        { model
            | newTodoText = ""
            , data =
                { data
                    | newTodoId = data.newTodoId + 1
                    , todos = todo :: data.todos
                }
        }


toggleTodo : Model -> Int -> Model
toggleTodo ({ data } as model) id =
    updateTodos model <|
        List.map
            (\t ->
                if t.id == id then
                    Todo id t.text (not t.completed)
                else
                    t
            )
            data.todos


deleteTodo : Model -> Int -> Model
deleteTodo ({ data } as model) id =
    updateTodos model <| List.filter (\t -> t.id /= id) data.todos


updateTodos : Model -> List Todo -> Model
updateTodos ({ data } as model) todos =
    { model | data = { data | todos = todos } }


view : Model -> Html Msg
view { user, newTodoText, data } =
    div []
        [ userInfo user
        , h1 [] [ text "Realtime Collaboration Quickstart" ]
        , p [] [ text "Now that your application is running, open this same document in a new tab or device to see syncing happen!" ]
        , todoForm newTodoText
        , ul [] <| List.map todo <| data.todos
        ]


userInfo : Gapi.User -> Html Msg
userInfo user =
    div []
        [ span []
            [ authButton user
            , displayUserProfile user
            ]
        ]


displayUserProfile : Gapi.User -> Html Msg
displayUserProfile user =
    case Debug.log "displayUserProfile" user of
        Gapi.SignedIn profile ->
            span []
                [ img [ src profile.imageUrl ] []
                , text (toString profile)
                ]

        Gapi.SignedOut ->
            text "Please sign in!"


authButton : Gapi.User -> Html Msg
authButton user =
    case user of
        Gapi.SignedIn _ ->
            button [ onClick SignOut ] [ text "Sign Out" ]

        Gapi.SignedOut ->
            button [ onClick SignIn ] [ text "Sign In" ]


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
        , button [ type_ "submit" ] [ text "+" ]
        , button [ type_ "button", onClick Cancel ] [ text "x" ]
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
        li []
            [ span
                [ class className, onClick (ToggleTodo todo.id) ]
                [ text todo.text ]
            , button [ onClick (DeleteTodo todo.id) ] [ text "x" ]
            ]



-- in


port receiveData : (Data -> msg) -> Sub msg



-- out


port sendData : Data -> Cmd msg


port gapiInit : Gapi.Config Data -> Cmd msg


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ receiveData ReceiveData
        , Gapi.updateUserSub UpdateUser
        ]


main : Program Never Model Msg
main =
    Html.program
        { init = initModel
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
