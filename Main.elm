port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Gapi
import Todos


-- Model Msg


type alias Model =
    { user : Gapi.User
    , data : Data
    }


type alias Data =
    { todosState : Todos.State }


type Msg
    = SignIn
    | SignOut
    | ReceiveData Data
    | UpdateUser Gapi.User
    | TodosMsg Todos.Msg



-- Init


initModel : ( Model, Cmd msg )
initModel =
    let
        data =
            Data Todos.initState
    in
        ( { user = Gapi.SignedOut
          , data = data
          }
        , gapiInit (gapiConfig data)
        )


gapiConfig : Data -> Gapi.Config Data
gapiConfig data =
    { client_id =
        "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com"
    , file_name = "elm-realtime-example"
    , folder_name = "ElmRealtimeExample"
    , initData = data
    }



-- Update


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

        TodosMsg todosMsg ->
            updateTodos model <| Todos.update todosMsg model.data.todosState


updateTodos : Model -> Todos.State -> ( Model, Cmd msg )
updateTodos ({ data } as model) todosState =
    persist { model | data = { data | todosState = todosState } }


persist : Model -> ( Model, Cmd msg )
persist ({ data } as model) =
    ( model, sendData data )



-- View


view : Model -> Html Msg
view { user, data } =
    div []
        [ userInfo user
        , h1 [] [ text "Realtime Collaboration Quickstart" ]
        , p [] [ text "Now that your application is running, open this same document in a new tab or device to see syncing happen!" ]
        , Html.map TodosMsg <| Todos.view data.todosState
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



-- Ports


{-| in
-}
port receiveData : (Data -> msg) -> Sub msg


{-| out
-}
port sendData : Data -> Cmd msg


port gapiInit : Gapi.Config Data -> Cmd msg



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ receiveData ReceiveData
        , Gapi.updateUserSub UpdateUser
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
