port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)

type RemoteData e a
    = NotAsked
    | Loading
    | Failure e
    | Success a

type alias Model = {
    gapiUser: GapiUser,
    text: Data
}

type alias Data = String

type Msg =
    SignIn |
    SignOut |
    UpdateUser GapiUser |
    ReceiveData Data |
    TextChanged Data

type alias GapiConfig = {
    components: String,
    client_id: String,
    discovery_docs: List String,
    scopes: String
}

type alias GapiUser = {
    id: String,
    name: String,
    givenName: String,
    familyName: String,
    imageUrl: String,
    email: String,
    isSignedIn: Bool
}

initGapiUser: GapiUser
initGapiUser = {
    id = "",
    name = "",
    givenName = "",
    familyName = "",
    imageUrl = "",
    email = "",
    isSignedIn = False
    }


gapiConfig : GapiConfig
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
    ({ gapiUser = initGapiUser, text = "elm_init" }, gapiLoad gapiConfig)





update: Msg -> Model -> (Model, Cmd msg)
update msg model = 
    case Debug.log "msg" msg of
        ReceiveData data ->
            ( { model | text = data }, Cmd.none )

        TextChanged data ->
            ( model, sendData data )

        UpdateUser gapiUser ->
            ( { model | gapiUser = gapiUser }, Cmd.none )

        SignIn ->
            ( model , call "signIn" )

        SignOut ->
            ( model , call "signOut" )

view: Model -> Html Msg
view model =
    div [] [
        userInfo model.gapiUser,
        h1 [] [ text "Realtime Collaboration Quickstart" ],
        p [] [ text "Now that your application is running, simply type in either text box and see your changes instantly appear in the other one. Open this same document in a new tab to see it work across tabs."],
        textarea [ id "text_area_1", onInput TextChanged, value model.text ] []
        --button [ id "auth_button" ] [ text "Authorize" ]
    ]

userInfo: GapiUser -> Html Msg
userInfo gapiUser = 
    div [] [
        div [] [
            authButton gapiUser,
            text (toString gapiUser)
        ],
        if gapiUser.isSignedIn then
            img [ src gapiUser.imageUrl ] []
        else
            text ""
    ]


authButton: GapiUser -> Html Msg
authButton { isSignedIn } =
    if isSignedIn then
        button [ onClick SignOut ] [ text "Sign Out" ]
    else
        button [ onClick SignIn ] [ text "Sign In" ]

-- in
port receiveData: (Data -> msg) -> Sub msg
port updateUser: (GapiUser -> msg) -> Sub msg

-- out
port sendData: Data -> Cmd msg
port gapiLoad: GapiConfig -> Cmd msg
port call: String -> Cmd msg

subscriptions: Model -> Sub Msg
subscriptions model =
    Sub.batch [
        receiveData ReceiveData,
        updateUser UpdateUser
    ]


main: Program Never Model Msg
main = 
    Html.program {
        init = initModel,
        view = view,
        update = update,
        subscriptions = subscriptions
    }