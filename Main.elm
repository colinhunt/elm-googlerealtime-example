port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Gapi

type alias Model = {
    user: Gapi.User,
    text: Data
}

type alias Data = String

type Msg =
    SignIn |
    SignOut |
    UpdateUser Gapi.User |
    ReceiveData Data |
    TextChanged Data

gapiConfig : Gapi.Config
gapiConfig = {
    components = "auth:client,drive-realtime,drive-share",
    client_id = "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com",
    discovery_docs = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"],
    scopes = 
        "https://www.googleapis.com/auth/drive.metadata.readonly " ++
        "https://www.googleapis.com/auth/drive.file"
    }

file_name : String
file_name = "elm-gapi-example.json"
folder_name : String
folder_name = "Elm Gapi Example"


initModel: (Model, Cmd msg)
initModel =
    ({ user = Gapi.SignedOut, text = "elm_init" }, Gapi.load gapiConfig)


update: Msg -> Model -> (Model, Cmd msg)
update msg model = 
    case Debug.log "msg" msg of
        ReceiveData data ->
            ( { model | text = data }, Cmd.none )

        TextChanged data ->
            ( model, sendData data )

        UpdateUser user ->
            ( { model | user = user }, Cmd.none )

        SignIn ->
            ( model , Gapi.signIn )

        SignOut ->
            ( model , Gapi.signOut )

view: Model -> Html Msg
view model =
    div [] [
        userInfo model.user,
        h1 [] [ text "Realtime Collaboration Quickstart" ],
        p [] [ text "Now that your application is running, simply type in either text box and see your changes instantly appear in the other one. Open this same document in a new tab to see it work across tabs."],
        textarea [ id "text_area_1", onInput TextChanged, value model.text ] []
        --button [ id "auth_button" ] [ text "Authorize" ]
    ]

userInfo: Gapi.User -> Html Msg
userInfo user = 
    div [] [
        span [] [
            authButton user,
            displayUserProfile user
        ]
    ]

displayUserProfile: Gapi.User -> Html Msg
displayUserProfile user =
    case Debug.log "displayUserProfile" user of
        Gapi.SignedIn profile ->
            span [] [
                img [ src profile.imageUrl ] [],
                text (toString profile)
            ]

        Gapi.SignedOut ->
            text "Please sign in!"


authButton: Gapi.User -> Html Msg
authButton user =
    case user of
        Gapi.SignedIn _ ->
            button [ onClick SignOut ] [ text "Sign Out" ]
        Gapi.SignedOut ->
            button [ onClick SignIn ] [ text "Sign In" ]

-- in
port receiveData: (Data -> msg) -> Sub msg

-- out
port sendData: Data -> Cmd msg

subscriptions: Model -> Sub Msg
subscriptions model =
    Sub.batch [
        receiveData ReceiveData,
        Gapi.updateUser (\maybeProfile -> 
            case maybeProfile of
                Just profile ->
                    UpdateUser (Gapi.SignedIn profile)
                Nothing ->
                    UpdateUser Gapi.SignedOut
        )
    ]


main: Program Never Model Msg
main = 
    Html.program {
        init = initModel,
        view = view,
        update = update,
        subscriptions = subscriptions
    }