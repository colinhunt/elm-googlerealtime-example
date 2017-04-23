port module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Gapi
import Todos


-- Model Msg


type alias Model =
    { todosState : Todos.State
    , gapiState : Gapi.State
    }


type alias Data =
    { todos : List Todos.Todo
    , newTodoId : Int
    }


type Msg
    = SignIn
    | SignOut
    | ReceiveData Data
    | TodosMsg Todos.Msg
    | GapiMsg Gapi.Msg



-- Init


initModel : ( Model, Cmd msg )
initModel =
    let
        todosState =
            Todos.initState

        ( gapiState, gapiCmd ) =
            Gapi.init
    in
        { todosState = todosState
        , gapiState = gapiState
        }
            ! [ gapiCmd ]


initData : Data
initData =
    Data [] 0



-- Update


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case Debug.log "msg" msg of
        ReceiveData data ->
            receiveDataHelper model model.todosState data ! []

        SignIn ->
            ( model, Gapi.signIn )

        SignOut ->
            ( model, Gapi.signOut )

        TodosMsg todosMsg ->
            persist
                { model | todosState = Todos.update todosMsg model.todosState }

        GapiMsg gapiMsg ->
            Gapi.update gapiMsg model.gapiState |> (\( state, cmd ) -> { model | gapiState = state } ! [ cmd ])


receiveDataHelper : Model -> Todos.State -> Data -> Model
receiveDataHelper model todosState data =
    { model
        | todosState =
            { todosState | newTodoId = data.newTodoId, todos = data.todos }
    }


persist : Model -> ( Model, Cmd msg )
persist ({ todosState } as model) =
    ( model, sendData <| Data todosState.todos todosState.newTodoId )



-- View


view : Model -> Html Msg
view { gapiState, todosState } =
    div []
        [ userInfo gapiState.user
        , clientInitStatus gapiState.clientInitStatus
        , div [] [ text <| "fileInfo: " ++ toString gapiState.fileInfo ]
        , div [] [ text <| "realtimeFileStatus " ++ toString gapiState.realtimeFileStatus ]
        , div [] [ text <| "retries: " ++ toString gapiState.retries ]
        , exceptions gapiState.exceptions
        , h1 [] [ text "Realtime Collaboration Quickstart" ]
        , p []
            [ text
                """
                Now that your application is running,
                open this same document in a new tab or
                device to see syncing happen!
                """
            ]
        , todosView todosState gapiState.realtimeFileStatus
        ]


todosView : Todos.State -> Gapi.RealtimeFileStatus -> Html Msg
todosView todosState realtimeStatus =
    case realtimeStatus of
        Gapi.NotRequested ->
            text "Sign in to see your todos"

        Gapi.Loading ->
            text "Loading todos..."

        Gapi.Failure error ->
            case error of
                Gapi.Fatal message type_ ->
                    text "Fatal error, please refresh the page."

                Gapi.Recoverable message type_ ->
                    text "Recoverable error, please try refreshing the page or wait or sign in again."

        Gapi.Success status ->
            case status of
                Gapi.Open ->
                    Html.map TodosMsg <| Todos.view todosState

                Gapi.Closed ->
                    text "The realtime document is closed. Please refresh the page or sign in again."


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
    case user of
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


clientInitStatus : Gapi.ClientInitStatus -> Html Msg
clientInitStatus status =
    case status of
        Gapi.NotRequested ->
            div [] [ text "Gapi client uninitialized." ]

        Gapi.Loading ->
            div [] [ text "Gapi client loading..." ]

        Gapi.Success _ ->
            div [] [ text "Gapi client OK. " ]

        Gapi.Failure { error, details } ->
            div []
                [ div [] [ text <| "Gapi client init failure: " ++ error ]
                , div [] [ text <| "Details: " ++ details ]
                ]


exceptions : Maybe String -> Html Msg
exceptions e =
    case e of
        Just msg ->
            text <| "Unexpected exception: " ++ msg

        Nothing ->
            text ""



-- Ports


{-| in
-}
port receiveData : (Data -> msg) -> Sub msg


{-| out
-}
port sendData : Data -> Cmd msg


port goRealtime : ( String, Data ) -> Cmd msg



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Gapi.subscriptions model |> Sub.map GapiMsg
        , receiveData ReceiveData
        ]



-- Main


main : Program Never Model Msg
main =
    Html.program
        { init = initModel
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
