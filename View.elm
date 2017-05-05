module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Dict exposing (Dict)
import Types exposing (Model, Msg(..))
import Gapi
import Todos


view : Model -> Html Msg
view ({ gapiState } as model) =
    div []
        [ myHeader gapiState.user
        , content model
        , myFooter gapiState
        ]


content : Model -> Html Msg
content model =
    div [ class "content" ]
        [ h3 [] [ text "Elm Realtime Collaboration Demo" ]
        , p []
            [ text
                """
            Now that your application is running,
            open this same document in a new tab or
            device to see syncing happen!
            """
            ]
        , todosView model
        ]


myFooter : Gapi.State -> Html Msg
myFooter gapiState =
    footer []
        [ h4 [] [ text "Status:" ]
        , div []
            [ text <|
                "collaborators: "
                    ++ ((List.length gapiState.collaborators) |> toString)
            ]
        , clientInitStatus gapiState.clientInitStatus
        , div []
            [ text <|
                "fileInfo: "
                    ++ toString gapiState.fileInfo
            ]
        , div []
            [ text <|
                "realtimeFileStatus "
                    ++ toString gapiState.realtimeFileStatus
            ]
        , div []
            [ text <|
                "retries: "
                    ++ toString gapiState.retries
            ]
        , exceptions gapiState.exceptions
        ]


todosView : Model -> Html Msg
todosView model =
    case model.gapiState.user of
        Gapi.SignedOut ->
            text "Sign in to see your todos."

        Gapi.SignedIn _ ->
            case model.gapiState.fileInfo of
                Gapi.NotRequested ->
                    text "Requesting the application file..."

                Gapi.Loading ->
                    text "Loading the application file..."

                Gapi.Failure _ ->
                    text """
                        Failed to load the application file from drive.
                        Please try refreshing the page.
                            """

                Gapi.Success _ ->
                    case model.gapiState.realtimeFileStatus of
                        Gapi.NotRequested ->
                            text "Requesting the realtime document..."

                        Gapi.Loading ->
                            text "Loading todos..."

                        Gapi.Failure error ->
                            case error of
                                Gapi.Fatal message type_ ->
                                    text "Fatal error, please refresh the page."

                                Gapi.Recoverable message type_ ->
                                    text
                                        """
    Recoverable error, please try refreshing the page or wait or sign in again.
                                        """

                        Gapi.Success status ->
                            case status of
                                Gapi.Open ->
                                    Html.map TodosMsg <|
                                        Todos.view model.newTodoText <|
                                            Dict.toList model.todos

                                Gapi.Closed ->
                                    text """
    The realtime document is closed. Please refresh the page or sign in again.
                                         """


myHeader : Gapi.User -> Html Msg
myHeader user =
    header []
        [ profileToggle user
        , case user of
            Gapi.SignedIn info ->
                profileModal info

            Gapi.SignedOut ->
                div [] []
        , authButton user
        ]


profileToggle : Gapi.User -> Html Msg
profileToggle user =
    case user of
        Gapi.SignedIn profile ->
            img [ src profile.imageUrl ] []

        Gapi.SignedOut ->
            span [] []


authButton : Gapi.User -> Html Msg
authButton user =
    case user of
        Gapi.SignedIn _ ->
            button [ onClick SignOut ] [ text "Sign Out" ]

        Gapi.SignedOut ->
            button [ onClick SignIn ] [ text "Sign In" ]


profileModal : Gapi.UserInfo -> Html Msg
profileModal info =
    div [ class "profileModal" ]
        [ div [] [ text info.name ]
        , div [] [ text info.email ]
        ]


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


exceptions : Maybe Gapi.RuntimeException -> Html Msg
exceptions e =
    case e of
        Just e ->
            text <| "Unexpected exception: " ++ (e |> toString)

        Nothing ->
            text ""
