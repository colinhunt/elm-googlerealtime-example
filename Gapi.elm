port module Gapi exposing (..)


type RemoteData e a
    = NotRequested
    | Loading
    | Failure e
    | Success a


type User
    = SignedOut
    | SignedIn UserInfo


type Resource
    = Open
    | Closed


type alias ClientInitStatus =
    RemoteData ClientInitFailureReason Bool


type alias FileInfo =
    RemoteData Bool String


type alias RealtimeFileStatus =
    RemoteData ErrorType Resource


type ErrorType
    = Fatal String String
    | Recoverable String String


type alias State =
    { clientInitStatus : ClientInitStatus
    , user : User
    , fileInfo : FileInfo
    , realtimeFileStatus : RealtimeFileStatus
    , retries : Int
    , exceptions : Maybe RuntimeException
    , collaborators : List Collaborator
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


type alias Collaborator =
    { color : String
    , displayName : String
    , isAnonymous : Bool
    , isMe : Bool
    , permissionId : String
    , photoUrl : String
    , sessionId : String
    , userId : String
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


type alias RuntimeException =
    { name : String
    , message : String
    }


fileName : String
fileName =
    "elm-realtime-example"


folderName : String
folderName =
    "ElmRealtimeExample"


components : String
components =
    "auth2:client,drive-realtime,drive-share"


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
    | OnRealtimeFileLoaded Bool
    | OnRealtimeError RealtimeError
    | OnRuntimeException RuntimeException
    | UpdateCollaborators (List Collaborator)
    | OnReloadAuthResponse Bool


init : ( State, Cmd msg )
init =
    { fileInfo = NotRequested
    , clientInitStatus = NotRequested
    , user = SignedOut
    , realtimeFileStatus = NotRequested
    , retries = 0
    , exceptions = Nothing
    , collaborators = []
    }
        ! [ load components ]


update :
    Msg
    -> State
    -> ( State, Cmd msg )
update msg state =
    case msg of
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
                    { state | fileInfo = Loading }
                        ! [ createAndLoadFile ( fileName, folderName ) ]

                False ->
                    { state | user = SignedOut, fileInfo = NotRequested, realtimeFileStatus = NotRequested } ! [ realtimeClose () ]

        UpdateUser maybeProfile ->
            case maybeProfile of
                Just profile ->
                    { state | user = SignedIn profile } ! []

                Nothing ->
                    { state | user = SignedOut } ! []

        UpdateCollaborators collaborators ->
            { state | collaborators = collaborators } ! []

        OnFileLoaded fileId ->
            { state | fileInfo = Success fileId } ! [ realtimeLoad fileId ]

        OnRealtimeFileLoaded success ->
            { state | realtimeFileStatus = Success Open } ! []

        OnRealtimeError error ->
            handleRealtimeError error state

        OnRuntimeException e ->
            handleRuntimeException e state

        OnReloadAuthResponse _ ->
            handleReloadAuthResponse state


handleRuntimeException : RuntimeException -> State -> ( State, Cmd msg )
handleRuntimeException e state =
    let
        newState =
            { state | exceptions = Just e }
    in
        if e.name == "DocumentClosedError" then
            handleRealtimeError (RealtimeError False e.message e.name) newState
        else
            newState ! []


signIn : Cmd msg
signIn =
    call "signIn"


signOut : Cmd msg
signOut =
    call "signOut"


handleFatalError : RealtimeError -> State -> ( State, Cmd msg )
handleFatalError { message, type_ } state =
    { state
        | realtimeFileStatus = Failure <| Fatal message type_
        , retries = 0
    }
        ! [ realtimeClose () ]


handleRealtimeError : RealtimeError -> State -> ( State, Cmd msg )
handleRealtimeError error state =
    if error.isFatal then
        handleFatalError error state
    else
        handleRecoverableError error state


handleRecoverableError : RealtimeError -> State -> ( State, Cmd msg )
handleRecoverableError ({ message, type_ } as error) state =
    { state | realtimeFileStatus = Failure <| Recoverable message type_ }
        |> case type_ of
            "concurrent_creation" ->
                tryRealtimeLoad error

            "invalid_compound_operation" ->
                always <| state ! []

            "invalid_json_syntax" ->
                always <| state ! []

            "missing_property" ->
                always <| state ! []

            "not_found" ->
                tryRealtimeLoad error

            "forbidden" ->
                (\state -> state ! [ realtimeClose () ])

            "server_error" ->
                tryRealtimeLoad error

            "client_error" ->
                tryRealtimeLoad error

            "token_refresh_required" ->
                (\state -> state ! [ reloadAuthResponse () ])

            "invalid_element_type" ->
                always <| state ! []

            "no_write_permission" ->
                always <| state ! []

            "DocumentClosedError" ->
                if state.realtimeFileStatus /= Success Closed then
                    tryRealtimeLoad error
                else
                    always <| state ! []

            _ ->
                handleFatalError error


tryRealtimeLoad : RealtimeError -> State -> ( State, Cmd msg )
tryRealtimeLoad ({ message, type_ } as error) state =
    if state.retries >= 5 then
        handleFatalError error state
    else
        { state | retries = state.retries + 1 }
            ! case state.fileInfo of
                NotRequested ->
                    [ createAndLoadFile ( fileName, folderName ) ]

                Loading ->
                    []

                Failure _ ->
                    [ createAndLoadFile ( fileName, folderName ) ]

                Success fileId ->
                    [ realtimeLoad fileId ]


handleReloadAuthResponse : State -> ( State, Cmd msg )
handleReloadAuthResponse state =
    case state.realtimeFileStatus of
        Failure (Recoverable _ "token_refresh_required") ->
            { state | realtimeFileStatus = Success Open } ! []

        _ ->
            state ! []


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


port reloadAuthResponse : () -> Cmd msg


port onReloadAuthResponse : (Bool -> msg) -> Sub msg


port realtimeLoad : String -> Cmd msg


port onRealtimeError : (RealtimeError -> msg) -> Sub msg


port onRealtimeFileLoaded : (Bool -> msg) -> Sub msg


port updateCollaborators : (List Collaborator -> msg) -> Sub msg


port realtimeClose : () -> Cmd msg


port runtimeException : (RuntimeException -> msg) -> Sub msg


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
        , onRealtimeFileLoaded OnRealtimeFileLoaded
        , runtimeException OnRuntimeException
        , updateCollaborators UpdateCollaborators
        , onReloadAuthResponse OnReloadAuthResponse
        ]



-- load
-- client
-- auth2
-- auth
-- drive.realtime
-- drive.files
