port module Gapi exposing (..)

type User = 
    SignedOut | 
    SignedIn BasicProfile

type AuthCommand = SignIn | SignOut

type alias Config = {
    components: String,
    client_id: String,
    discovery_docs: List String,
    scopes: String,
    file_name: String,
    folder_name: String
}

type alias BasicProfile = {
    id: String,
    name: String,
    givenName: String,
    familyName: String,
    imageUrl: String,
    email: String
}

signIn: Cmd msg
signIn =
    call "signIn"

signOut : Cmd msg
signOut =
    call "signOut"

-- in
port updateUser: (Maybe BasicProfile -> msg) -> Sub msg

-- out
port init: Config -> Cmd msg
port call: String -> Cmd msg
