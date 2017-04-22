port module Gapi exposing (..)


type User
    = SignedOut
    | SignedIn BasicProfile


type alias State =
    { clientInitStatus : String
    , user : User
    }


type alias Config a =
    { client_id : String
    , file_name : String
    , folder_name : String
    , initData : a
    }


type alias BasicProfile =
    { id : String
    , name : String
    , givenName : String
    , familyName : String
    , imageUrl : String
    , email : String
    }


type alias ClientInitArgs =
    { clientId : String
    , discoveryDocs : List String
    , scope : String
    }


components : String
components =
    "auth2:client,drive-realtime,drive-share"


init : ( State, Cmd msg )
init =
    { clientInitStatus = "", user = SignedOut } ! [ load components ]


clientInitArgs : ClientInitArgs
clientInitArgs =
    { discoveryDocs =
        [ "https://www.googleapis.com/discovery/v1/apis/drive/v3/rest" ]
    , clientId =
        "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com"
    , scope =
        "https://www.googleapis.com/auth/drive.metadata.readonly "
            ++ "https://www.googleapis.com/auth/drive.file"
    }


type Msg
    = OnLoad
    | ClientInitSuccess
    | ClientInitFailure String
    | OnSignInChange Bool
    | UpdateUser (Maybe BasicProfile)
    | OnFileLoaded String


update : Msg -> { b | gapiState : State } -> ( { b | gapiState : State }, Cmd msg )
update msg ({ gapiState } as model) =
    let
        updateState state =
            { model | gapiState = state }
    in
        case Debug.log "Gapi.update" msg of
            OnLoad ->
                model ! [ clientInit clientInitArgs ]

            ClientInitSuccess ->
                model ! [ setSignInListeners "onSignInChange" ]

            ClientInitFailure reason ->
                ({ gapiState
                    | clientInitStatus = Debug.log "ClientInitFailure" reason
                 }
                    |> updateState
                )
                    ! []

            OnSignInChange signedIn ->
                case signedIn of
                    True ->
                        model
                            ! [ getBasicProfile ()
                              , createAndLoadFile <|
                                    (,) "elm-realtime-example" "ElmRealtimeExample"
                              ]

                    False ->
                        ({ gapiState | user = SignedOut } |> updateState) ! []

            UpdateUser maybeProfile ->
                (case maybeProfile of
                    Just profile ->
                        { gapiState | user = SignedIn profile } |> updateState

                    Nothing ->
                        { gapiState | user = SignedOut } |> updateState
                )
                    ! []

            OnFileLoaded _ ->
                -- handled by client
                model ! []


signIn : Cmd msg
signIn =
    call "signIn"


signOut : Cmd msg
signOut =
    call "signOut"


updateUserSub : (User -> msg) -> Sub msg
updateUserSub toMsg =
    updateUser
        (\maybeProfile ->
            case maybeProfile of
                Just profile ->
                    toMsg (SignedIn profile)

                Nothing ->
                    toMsg SignedOut
        )


port call : String -> Cmd msg


port load : String -> Cmd msg


port onLoad : (() -> msg) -> Sub msg


port clientInit :
    { discoveryDocs : List String
    , clientId : String
    , scope : String
    }
    -> Cmd msg


port clientInitSuccess : (() -> msg) -> Sub msg


port clientInitFailure : (String -> msg) -> Sub msg


port setSignInListeners : String -> Cmd msg


port onSignInChange : (Bool -> msg) -> Sub msg


port getBasicProfile : () -> Cmd msg


port updateUser : (Maybe BasicProfile -> msg) -> Sub msg


port createAndLoadFile : ( String, String ) -> Cmd msg


port onFileLoaded : (String -> msg) -> Sub msg


subscriptions : model -> Sub Msg
subscriptions model =
    Sub.batch
        [ onLoad (\_ -> OnLoad)
        , clientInitSuccess (\_ -> ClientInitSuccess)
        , clientInitFailure ClientInitFailure
        , onSignInChange OnSignInChange
        , onFileLoaded OnFileLoaded
        , updateUser UpdateUser
        ]



-- load
-- client
-- auth2
-- auth
-- drive.realtime
-- drive.files
