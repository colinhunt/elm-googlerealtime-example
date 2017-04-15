port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Gapi

type alias Model = {
    user: Gapi.User,
    newTodoText: String,
    newTodoId: Int,
    todos: List Todo
}

type alias Todo = {
    id: Int,
    text: String,
    completed: Bool
}

type alias Data = List Todo

type Msg =
    SignIn |
    SignOut |
    UpdateUser Gapi.User |
    ReceiveData Data |
    Input String |
    NewTodo |
    ToggleTodo Int |
    DeleteTodo Int |
    Cancel

gapiConfig : Gapi.Config
gapiConfig = {
    components = "auth:client,drive-realtime,drive-share",
    client_id = "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com",
    discovery_docs = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"],
    scopes = 
        "https://www.googleapis.com/auth/drive.metadata.readonly " ++
        "https://www.googleapis.com/auth/drive.file",
    file_name = "elm-realtime-example",
    folder_name = "ElmRealtimeExample"
    }


initModel: (Model, Cmd msg)
initModel =
    ({ user = Gapi.SignedOut, todos = [], newTodoText = "", newTodoId = 0 }, Gapi.init gapiConfig)


update: Msg -> Model -> (Model, Cmd msg)
update msg model = 
    case Debug.log "msg" msg of
        ReceiveData todos ->
            ( { model | todos = todos }, Cmd.none )

        UpdateUser user ->
            ( { model | user = user }, Cmd.none )

        SignIn ->
            ( model , Gapi.signIn )

        SignOut ->
            ( model , Gapi.signOut )

        Input text ->
            ( { model | newTodoText = text }, Cmd.none )

        NewTodo ->
            ( addTodo model, Cmd.none )

        ToggleTodo id ->
            ( toggleTodo model id, Cmd.none )

        DeleteTodo id ->
            ( deleteTodo model id, Cmd.none )

        Cancel ->
            ( { model | newTodoText = "" }, Cmd.none )

addTodo: Model -> Model
addTodo model =
    let
        todo = Todo model.newTodoId model.newTodoText False
    in
        { model | todos = todo :: model.todos, newTodoText = "", newTodoId = model.newTodoId + 1 }

toggleTodo: Model -> Int -> Model
toggleTodo model id =
    let
        newTodos = List.map (\t -> if t.id == id then Todo id t.text (not t.completed) else t ) model.todos
    in
        { model | todos = newTodos }

deleteTodo: Model -> Int -> Model
deleteTodo model id =
    { model | todos = List.filter (\t -> t.id /= id) model.todos }

view: Model -> Html Msg
view model =
    div [] [
        userInfo model.user,
        h1 [] [ text "Realtime Collaboration Quickstart" ],
        p [] [ text "Now that your application is running, open this same document in a new tab or device to see syncing happen!."],
        todoForm model,
        ul [] <| List.map todo <| model.todos
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

todoForm: Model -> Html Msg
todoForm model =
    Html.form [ onSubmit NewTodo ] [
        input [
            type_ "text",
            placeholder "Add todo...",
            onInput Input,
            value model.newTodoText
        ] [],
        button [ type_ "submit" ] [ text "+" ],
        button [ type_ "button", onClick Cancel ] [ text "x" ]
    ]

todo: Todo -> Html Msg
todo todo =
    let
        className = if todo.completed then "completedTodo" else ""
    in
    li [] [
        span [ class className, onClick (ToggleTodo todo.id) ] [ text todo.text ],
        button [ onClick (DeleteTodo todo.id) ] [ text "x" ]
    ]

port receiveData: (Data -> msg) -> Sub msg
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