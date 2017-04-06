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
    auth: RemoteData Int Int,
    text: Data
}

type alias Data = String

type Msg =
    ReceiveData Data |
    TextChanged Data

initModel: (Model, Cmd msg)
initModel =
    ({ auth = NotAsked, text = "" }, Cmd.none)





update: Msg -> Model -> (Model, Cmd msg)
update msg model = 
    case Debug.log "msg" msg of
        ReceiveData data ->
            ( { model | text = data }, Cmd.none )

        TextChanged data ->
            ( model, sendData data )

view: Model -> Html Msg
view model =
    div [] [
        h1 [] [ text "Realtime Collaboration Quickstart" ],
        p [] [ text "Now that your application is running, simply type in either text box and see your changes instantly appear in the other one. Open this same document in a new tab to see it work across tabs."],
        textarea [ id "text_area_1", onInput TextChanged  ] [ text model.text ]
        --button [ id "auth_button" ] [ text "Authorize" ]
    ]

port receiveData: (Data -> msg) -> Sub msg
port sendData: Data -> Cmd msg


subscriptions: Model -> Sub Msg
subscriptions model =
    receiveData ReceiveData


main: Program Never Model Msg
main = 
    Html.program {
        init = initModel,
        view = view,
        update = update,
        subscriptions = subscriptions
    }