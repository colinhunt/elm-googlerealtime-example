function elmGapi(elmApp) {
  const COMPONENTS = 'auth2:client,drive-realtime,drive-share';
  const DISCOVERY_DOCS = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"]
  const SCOPES = 
        "https://www.googleapis.com/auth/drive.metadata.readonly " +
        "https://www.googleapis.com/auth/drive.file"


  elmApp.ports.gapiInit.subscribe(initClient);

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

  /**
   *  Initializes the API client library and sets up sign-in state
   *  listeners.
   */
  function initClient(gapiConfig) {
    console.log('initClient', gapiConfig);
    gapi.load(COMPONENTS, () => {
      console.log('gapi.load');
      gapi.client.init({
        discoveryDocs: DISCOVERY_DOCS,
        clientId: gapiConfig.client_id,
        scope: SCOPES
      }).then(function (result) {
        console.log('gapi.client.init', result)
        const auth = gapi.auth2.getAuthInstance();
        // Listen for sign-in state changes.
        auth.isSignedIn.listen(signInChange);

        // Handle the initial sign-in state.
        signInChange(auth.isSignedIn.get());
      }, function (reason) {
        console.log('failure');
        console.log(reason);
      });
    });

    function signInChange(isSignedIn) {
      const userProfile = isSignedIn ? basicProfile() : null;
      elmApp.ports.updateUser.send(userProfile);

      if (isSignedIn) {
        createAndLoadFile(
          gapiConfig.file_name, 
          gapiConfig.folder_name, 
          (fileId) => realtimeMode(fileId, gapiConfig.initData)
        );
      }
    }
  }

  function realtimeMode(fileId, initData) {
    return realtimeLoad();

    function realtimeLoad() {
      setAuthToken();
      gapi.drive.realtime.load(
        fileId, 
        onFileLoaded, 
        onFileInitialize, 
        onError
      );      
    }

    // The first time a file is opened, it must be initialized with the
    // document structure. This function will add a collaborative string
    // to our model at the root.
    function onFileInitialize(model) {
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

    function onError(error) {
      if (error.type == gapi.drive.realtime.ErrorType
          .TOKEN_REFRESH_REQUIRED) {
        realtimeLoad();
      } else if (error.type == gapi.drive.realtime.ErrorType
          .CLIENT_ERROR) {
        alert('An Error happened: ' + error.message);
      } else if (error.type == gapi.drive.realtime.ErrorType.NOT_FOUND) {
        alert('The file was not found. It does not exist or you do not have ' +
          'read access to the file.');
      } else if (error.type == gapi.drive.realtime.ErrorType.FORBIDDEN) {
        alert('You do not have access to this file. Try having the owner share' +
          'it with you from Google Drive.');
      }
    }
  }

  function setAuthToken(refresh = false) {
    const user = gapi.auth2.getAuthInstance().currentUser.get();
    const authResponse = user.getAuthResponse(true);
    console.log('authResponse', authResponse);
    gapi.auth.setToken(authResponse);      
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
      const folder = result.result.files[0];
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
        const file = result.result.files[0]
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