function elmGapi(elmApp) {
  const COMPONENTS = 'auth2:client,drive-realtime,drive-share';
  const DISCOVERY_DOCS = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"]
  const SCOPES = 
        "https://www.googleapis.com/auth/drive.metadata.readonly " +
        "https://www.googleapis.com/auth/drive.file"


  let file;
  let folder;
  let send;
  let notifyDone;


  elmApp.ports.gapiInit.subscribe((gapiConfig) => {
    console.log('gapiLoad', gapiConfig);
    gapi.load(COMPONENTS, () => initClient(gapiConfig));
  });

  elmApp.ports.call.subscribe((f) => {
    switch (f) {
      case 'signIn':
        return gapi.auth2.getAuthInstance().signIn({
          prompt: 'select_account'
        });
      case 'signOut':
        gapi.auth2.getAuthInstance().signOut();
    }
  })

  /**
   *  Initializes the API client library and sets up sign-in state
   *  listeners.
   */
  function initClient(gapiConfig) {
    console.log('initClient');
    gapi.client.init({
      discoveryDocs: DISCOVERY_DOCS,
      clientId: gapiConfig.client_id,
      scope: SCOPES
    }).then(function (result) {
      console.log('initClient', result)
      const auth = gapi.auth2.getAuthInstance();
      // Listen for sign-in state changes.
      auth.isSignedIn.listen(signInChange);

      // Handle the initial sign-in state.
      signInChange(auth.isSignedIn.get());
    }, function (reason) {
      console.log('failure');
      console.log(reason);
    });


    function signInChange(isSignedIn) {
      const userProfile = isSignedIn ? basicProfile() : null;
      elmApp.ports.updateUser.send(userProfile);

      if (isSignedIn) {
        const user = gapi.auth2.getAuthInstance().currentUser.get();
        const authResponse = user.getAuthResponse(true);
        console.log('authResponse', authResponse);
        gapi.auth.setToken(authResponse, (result) => console.log('setToken', result));
        prepareRealTimeDoc();
      }
    }

    function prepareRealTimeDoc() {
      // gapi.auth2.authorize({
      //   client_id: gapiConfig.client_id,
      //   scope: SCOPES,
      //   immediate: true
      // }, (result) => {
        // console.log('gapi.auth.authorize result', result);
        // if (!result.error) {
          createAndLoadFile(gapiConfig.file_name, gapiConfig.folder_name, (fileId) => {
            gapi.drive.realtime.load(
              fileId, 
              onFileLoaded, 
              (m) => onFileInitialize(m, gapiConfig.initData), 
              (error) => {
                console.log('gapi.drive.realtime.load error', error);
              }
            );
          });
        // } else {
          // console.log('gapi.auth.authorize error :(')
        // }
      // }
    }
  }

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

  // The first time a file is opened, it must be initialized with the
  // document structure. This function will add a collaborative string
  // to our model at the root.
  function onFileInitialize(model, initData) {
    console.log('onFileInitialize')
    const string = model.createString();
    string.text = JSON.stringify(initData);
    model.getRoot().set('model_json', string);
  }

  // After a file has been initialized and loaded, we can access the
  // document. We will wire up the data model to the UI.
  function onFileLoaded(doc) {
    console.log('onFileLoaded')
    const root = doc.getModel().getRoot();
    root.addEventListener(gapi.drive.realtime.EventType.OBJECT_CHANGED, onObjectChanged);

    const modelJson = root.get('model_json');
    elmApp.ports.receiveData.send(JSON.parse(modelJson.text));
    elmApp.ports.sendData.subscribe((data) => modelJson.text = JSON.stringify(data));
  }

  function onObjectChanged(event) {
    console.log('onObjectChanged', event);
    elmApp.ports.receiveData.send(JSON.parse(event.target.text));
  }

  // FILE CREATION / LOAD

  // http://stackoverflow.com/questions/40387834/how-to-create-google-docs-document-with-text-using-google-drive-javascript-sdk
  function createAndLoadFile(fileName, folderName, callback) {
    console.log('createAndLoadFile')
    gapi.client.drive.files.list({
      q: `name = '${folderName}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false`,
      fields: 'files(id, name, trashed)',
      spaces: 'drive'
    }).then(onFolderList);

    function onFolderList(result) {
      console.log('onFolderList', result)
      folder = result.result.files[0]
      if (!folder) {
        return createFolder();
      }
      console.log("found folder", folder)

      gapi.client.drive.files.list({
        q: `name = '${fileName}' and '${folder.id}' in parents and trashed = false `,
        fields: 'files(id, name, parents, trashed)',
        spaces: 'drive'
      }).then(onFileList(folder.id));
    }

    function createFolder() {
      var fileMetadata = {
        'name' : folderName,
        'mimeType' : 'application/vnd.google-apps.folder',
      };
      console.log('createFolder()')
      var request = gapi.client.drive.files.create({
         resource: fileMetadata,
         fields: 'id',
      }).then(function(result) {
        return onFolderList({result: {files: [result.result]}})
      });
    }

    function onFileList(folderId) {
      function _onFileList(result) {
        console.log('onFileList', result)
        file = result.result.files[0]
        if (!file) {
          return createFile(folderId);
        }
        console.log('Found file: ', file.name);
        callback(file.id);
      }
      return _onFileList;
    }

    function createFile(parent) {
      console.log('createFile', parent)
      gapi.client.drive.files.create({
        name: fileName,
        parents: [parent],
        params: {
          uploadType: 'media'
        },
        fields: 'id'
      }).then(function(result) {
        console.log('File create: ', result)
        onFileList(parent)({result: {files: [result.result]}})
      })
    }
  }
}