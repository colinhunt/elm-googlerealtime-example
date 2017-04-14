function elmGapi(elmApp) {
  elmApp.ports.load.subscribe((gapiConfig) => {
    console.log('gapiLoad', gapiConfig);
    gapi.load(gapiConfig.components, () => initClient(gapiConfig));
  });

  elmApp.ports.call.subscribe((f) => {
    switch (f) {
      case 'signIn':
        return gapi.auth2.getAuthInstance().signIn({
          prompt: 'select_account'
        });
      case 'signOut':
        return gapi.auth2.getAuthInstance().signOut();
    }
  })

  function basicProfile() {
    const basicProfile = gapi.auth2.getAuthInstance().currentUser.get().getBasicProfile()
    if (basicProfile) {
      return {
        id: basicProfile.getId(),
        name: basicProfile.getName(),
        givenName: basicProfile.getGivenName(),
        familyName: basicProfile.getFamilyName(),
        imageUrl: basicProfile.getImageUrl(),
        email: basicProfile.getEmail()
      }
    }
  }

  function updateUser(isSignedIn) {
    const userProfile = isSignedIn ? basicProfile() : null;
    elmApp.ports.updateUser.send(userProfile);
  }
  
  /**
   *  Initializes the API client library and sets up sign-in state
   *  listeners.
   */
  function initClient(gapiConfig) {
    console.log('initClient');
    gapi.client.init({
      discoveryDocs: gapiConfig.discovery_docs,
      clientId: gapiConfig.client_id,
      scope: gapiConfig.scopes
    }).then(function () {
      console.log('success')
      // Listen for sign-in state changes.
      gapi.auth2.getAuthInstance().isSignedIn.listen(updateUser);

      // Handle the initial sign-in state.
      updateUser(gapi.auth2.getAuthInstance().isSignedIn.get());
    }, function (reason) {
      console.log('failure')
      console.log(reason);
    });
  }

  function start() {
    // With auth taken care of, load a file, or create one if there
    // is not an id in the URL.
    var id = '0B3cmYHgSA9yETVhUT0QtMmQtUGs';
    // var id = realtimeUtils.getParam('id');
    if (id) {
      // Load the document id from the URL
      realtimeUtils.load(id.replace('/', ''), onFileLoaded, onFileInitialize);
    } else {
      // Create a new document, add it to the URL
      realtimeUtils.createRealtimeFile('New Quickstart File', function(createResponse) {
        window.history.pushState(null, null, '?id=' + createResponse.id);
        realtimeUtils.load(createResponse.id, onFileLoaded, onFileInitialize);
      });
    }
  }

  // The first time a file is opened, it must be initialized with the
  // document structure. This function will add a collaborative string
  // to our model at the root.
  function onFileInitialize(model) {
    var string = model.createString();
    string.setText('Welcome to the Quickstart App!');
    model.getRoot().set('demo_string', string);
  }

  // After a file has been initialized and loaded, we can access the
  // document. We will wire up the data model to the UI.
  function onFileLoaded(doc) {
    var collaborativeString = doc.getModel().getRoot().get('demo_string');
    doc.getModel().getRoot().addEventListener(gapi.drive.realtime.EventType.OBJECT_CHANGED, onObjectChanged)
    elmApp.ports.receiveData.send(collaborativeString.text);
    elmApp.ports.sendData.subscribe((data) => collaborativeString.text = data);
  }

  function onObjectChanged(event) {
    console.log('onObjectChanged', event);
    elmApp.ports.receiveData.send(event.target.text);
  }
}