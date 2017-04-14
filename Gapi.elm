port module Gapi exposing (..)

type User = 
    SignedOut | 
    SignedIn BasicProfile

type AuthCommand = SignIn | SignOut

type alias Config = {
    components: String,
    client_id: String,
    discovery_docs: List String,
    scopes: String
}

type alias BasicProfile = {
    id: String,
    name: String,
    givenName: String,
    familyName: String,
    imageUrl: String,
    email: String    
}

signIn =
    call "signIn"

signOut =
    call "signOut"

-- in
port updateUser: (Maybe BasicProfile -> msg) -> Sub msg

-- out
port load: Config -> Cmd msg
port call: String -> Cmd msg
