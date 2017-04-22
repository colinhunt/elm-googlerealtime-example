port module Gapi exposing (..)


type RemoteData e a
    = NotRequested
    | Loading
    | Failure e
    | Success a


type User
    = SignedOut
    | SignedIn UserInfo


type alias ClientInitStatus =
    RemoteData ClientInitFailureReason Bool


type alias FileInfo =
    RemoteData Bool String



--type alias RealtimeFileStatus =
--    RemoteData


type alias State =
    { clientInitStatus : ClientInitStatus
    , user : User
    , fileInfo : FileInfo
    , realtimeFileStatus : RealtimeFileStatus
    }


type alias Config a =
    { client_id : String
    , file_name : String
    , folder_name : String
    , initData : a
    }


type alias UserInfo =
    { id : String
    , name : String
    , givenName : String
    , familyName : String
    , imageUrl : String
    , email : String
    , authResponse : AuthResponse
    }


type alias AuthResponse =
    { access_token : String -- The Access Token granted.
    , id_token : String -- The ID Token granted.
    , scope : String -- The scopes granted in the Access Token.
    , expires_in : Int -- The number of seconds until the Access Token expires.
    , first_issued_at : Int -- The timestamp at which the user first granted the scopes requested.
    , expires_at : Int -- The timestamp at which the Access Token will expire.
    }


type alias ClientInitArgs =
    { clientId : String
    , discoveryDocs : List String
    , scope : String
    }


type alias ClientInitFailureReason =
    { error : String
    , details : String
    }


type alias RealtimeError =
    { isFatal : Bool
    , message : String
    , type_ : String
    }


components : String
components =
    "auth2:client,drive-realtime,drive-share"


init : ( State, Cmd msg )
init =
    { fileInfo = NotRequested
    , clientInitStatus = NotRequested
    , user = SignedOut
    }
        ! [ load components ]


clientInitArgs : ClientInitArgs
clientInitArgs =
    { discoveryDocs =
        [ "https://www.googleapis.com/discovery/v1/apis/drive/v3/rest" ]
    , clientId = """349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com"""
    , scope =
        "https://www.googleapis.com/auth/drive.metadata.readonly "
            ++ "https://www.googleapis.com/auth/drive.file"
    }


type Msg
    = OnLoad
    | ClientInitSuccess
    | ClientInitFailure ClientInitFailureReason
    | OnSignInChange Bool
    | UpdateUser (Maybe UserInfo)
    | OnFileLoaded String
    | OnRealtimeError RealtimeError


update :
    Msg
    -> State
    -> ( State, Cmd msg )
update msg state =
    case Debug.log "Gapi.update" msg of
        OnLoad ->
            state ! [ clientInit clientInitArgs ]

        ClientInitSuccess ->
            { state | clientInitStatus = Success True }
                ! [ setSignInListeners "onSignInChange" ]

        ClientInitFailure reason ->
            { state
                | clientInitStatus =
                    Failure <| Debug.log "ClientInitFailure" reason
            }
                ! []

        OnSignInChange signedIn ->
            case signedIn of
                True ->
                    state
                        ! [ getUser ()
                          , createAndLoadFile <|
                                ( "elm-realtime-example"
                                , "ElmRealtimeExample"
                                )
                          ]

                False ->
                    { state | user = SignedOut } ! []

        UpdateUser maybeProfile ->
            case maybeProfile of
                Just profile ->
                    { state | user = SignedIn profile }
                        ! [ setAuthToken profile.authResponse ]

                Nothing ->
                    { state | user = SignedOut } ! []

        OnFileLoaded fileId ->
            { state | fileInfo = Success fileId } ! [ realtimeLoad fileId ]

        OnRealtimeError error ->
            handleRealtimeError error state


signIn : Cmd msg
signIn =
    call "signIn"


signOut : Cmd msg
signOut =
    call "signOut"


handleRealtimeError : RealtimeError -> State -> ( State, Cmd msg )
handleRealtimeError { isFatal, message, type_ } state =
    (if isFatal then
        { state | realtimeFileStatus = Failure <| Fatal message type_ } ! []
     else
        { state | realtimeFileStatus = Failure <| Recoverable message type_ }
        ! [ case type_ of 
            ]
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


port clientInitFailure : (ClientInitFailureReason -> msg) -> Sub msg


port setSignInListeners : String -> Cmd msg


port onSignInChange : (Bool -> msg) -> Sub msg


port getUser : () -> Cmd msg


port updateUser : (Maybe UserInfo -> msg) -> Sub msg


port createAndLoadFile : ( String, String ) -> Cmd msg


port onFileLoaded : (String -> msg) -> Sub msg


port setAuthToken : AuthResponse -> Cmd msg


port realtimeLoad : String -> Cmd msg


port onRealtimeError : (RealtimeError -> msg) -> Sub msg


subscriptions : model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ onLoad <| always OnLoad
        , clientInitSuccess <| always ClientInitSuccess
        , clientInitFailure ClientInitFailure
        , onSignInChange OnSignInChange
        , onFileLoaded OnFileLoaded
        , updateUser UpdateUser
        , onRealtimeError OnRealtimeError
        ]



-- load
-- client
-- auth2
-- auth
-- drive.realtime
-- drive.files
