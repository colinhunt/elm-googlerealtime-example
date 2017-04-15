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

type alias Data = { todos: List Todo, newTodoId: Int }

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

gapiConfig : Gapi.Config Data
gapiConfig = {
    client_id = "349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com",
    file_name = "elm-realtime-example",
    folder_name = "ElmRealtimeExample",
    initData = Data [] 0
    }


initModel: (Model, Cmd msg)
initModel =
    ({ user = Gapi.SignedOut, todos = [], newTodoText = "", newTodoId = 0 }, gapiInit gapiConfig)


update: Msg -> Model -> (Model, Cmd msg)
update msg model = 
    case Debug.log "msg" msg of
        ReceiveData data ->
            ( { model | todos = data.todos, newTodoId = data.newTodoId }, Cmd.none )

        UpdateUser user ->
            ( { model | user = user }, Cmd.none )

        SignIn ->
            ( model , Gapi.signIn )

        SignOut ->
            ( model , Gapi.signOut )

        Input text ->
            ( { model | newTodoText = text }, Cmd.none )

        NewTodo ->
            persist (addTodo model)

        ToggleTodo id ->
            persist (toggleTodo model id)

        DeleteTodo id ->
            persist (deleteTodo model id)

        Cancel ->
            ( { model | newTodoText = "" }, Cmd.none )

persist: Model -> (Model, Cmd msg)
persist model =
    ( model, sendData (Data model.todos model.newTodoId) )


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
port gapiInit: Gapi.Config Data -> Cmd msg


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