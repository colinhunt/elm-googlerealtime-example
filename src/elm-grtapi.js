function elmGrtapi(elmApp) {
  var clientId = '349913990095-ce6i4ji4j08akc882di10qsm8menvoa8.apps.googleusercontent.com';

  if (!/^([0-9])$/.test(clientId[0])) {
    alert('Invalid Client ID - did you forget to insert your application Client ID?');
  }
  // Create a new instance of the realtime utility with your client ID.
  var realtimeUtils = new utils.RealtimeUtils({ clientId: clientId });

  authorize();

  function authorize() {
    // Attempt to authorize
    realtimeUtils.authorize(function(response){
      if(response.error){
        // Authorization failed because this is the first time the user has used your application,
        // show the authorize button to prompt them to authorize manually.
        var button = document.getElementById('auth_button');
        button.classList.add('visible');
        button.addEventListener('click', function () {
          realtimeUtils.authorize(function(response){
            start();
          }, true);
        });
      } else {
          start();
      }
    }, false);
  }

  function start() {
    // With auth taken care of, load a file, or create one if there
    // is not an id in the URL.
    var id = realtimeUtils.getParam('id');
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