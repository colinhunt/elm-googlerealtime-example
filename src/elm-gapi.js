function elmGapi(elmApp) {
  const COMPONENTS = 'auth2:client,drive-realtime,drive-share';
  const DISCOVERY_DOCS = ["https://www.googleapis.com/discovery/v1/apis/drive/v3/rest"]
  const SCOPES = 
        "https://www.googleapis.com/auth/drive.metadata.readonly " +
        "https://www.googleapis.com/auth/drive.file"

  const elm = elmApp.ports;

  elm.load.subscribe((components) => {
    console.log('elm.load')
    gapi.load(components, () => elm.onLoad.send(null));
  });

  elm.clientInit.subscribe((args) => {
    console.log('elm.clientInit');
    gapi.client.init(args).then(
      () => elm.clientInitSuccess.send(null),
      elm.clientInitFailure.send
    )
  })

  elm.setSignInListeners.subscribe((onSignInChange) => {
    console.log('elm.setSignInListeners')
    const auth = gapi.auth2.getAuthInstance();
    // Listen for sign-in state changes.
    auth.isSignedIn.listen(elm[onSignInChange].send);

    // Handle the initial sign-in state.
    elm[onSignInChange].send(auth.isSignedIn.get());
  })

  elm.getUser.subscribe(() => {
    console.log('elm.getUser')
    elm.updateUser.send(userInfo());
  })

  elm.setAuthToken.subscribe((authResponse) => {
    gapi.auth.setToken(authResponse);
  })

  elm.createAndLoadFile.subscribe((args) => {
    console.log('elm.createAndLoadFile')
    createAndLoadFile(
      args[0], 
      args[1],
      elm.onFileLoaded.send
    );
  })

  elm.realtimeLoad.subscribe((fileId) => {
    console.log('elm.realtimeLoad')
    gapi.drive.realtime.load(
      fileId, 
      onFileLoaded, 
      onFileInitialize, 
      (error) => { elm.onRealtimeError.send({...error, type_: error.type })}
    );
  })

  elmApp.ports.call.subscribe((f) => {
    switch (f) {
      case 'signIn':
        gapi.auth2.getAuthInstance().signIn({
          prompt: 'select_account'
        });
        break;
      case 'signOut':
        gapi.auth2.getAuthInstance().signOut();
        break;
    }
  })

  function sendDataToElm(data, onError) {
    elmApp.ports.receiveData.send(data);
  }

  function subscribeToElmData(receiveElmData) {
    elmApp.ports.sendData.subscribe(receiveElmData);
  }

  function userInfo() {
    const user = gapi.auth2.getAuthInstance().currentUser.get();
    const basicProfile = user.getBasicProfile();
    const authResponse = user.getAuthResponse(true);
    if (basicProfile) {
      return {
        id: basicProfile.getId(),
        name: basicProfile.getName(),
        givenName: basicProfile.getGivenName(),
        familyName: basicProfile.getFamilyName(),
        imageUrl: basicProfile.getImageUrl(),
        email: basicProfile.getEmail(),
        authResponse: authResponse
      }
    } else {
      return null;
    }
  }

  function realtimeMode(fileId, initData) {

    function key(version) {
      const key = 'app_data';
      return key + version;
    }

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
      const map = model.collaborativeMap();
      map.set('app_data', initData);
      model.getRoot().set(key(0), map);
    }

    function getSetMap(model) {
      console.log('getSetMap')
      const attempts = 1000;
      const root = model.getRoot();
      for (let i = 0; i < attempts; i++) {
        if (!root.has(key(i))) {
          const map = model.createMap();
          map.set('app_data', initData);
          root.set(key(i), map);
          console.log('Created new data at key', key(i));
        }          
        const map = root.get(key(i));
        const data = map.get('app_data');
        try {
          sendDataToElm(data);
        } catch (e) {
          if (e.message.includes('Trying to send an unexpected type of value through port')) {
            console.log('Data mismatch error, retry')
            continue;
          }
          console.log('Unrecoverable data error.')
          throw e;  // unrecoverable so re-throw
        }
        // success
        console.log('Success! Found data at key', key(i))
        return map;
      }
    }

    // After a file has been initialized and loaded, we can access the
    // document. We will wire up the data model to the UI.
    function onFileLoaded(doc) {
      console.log('onFileLoaded')
      const map = getSetMap(doc.getModel());
      map.addEventListener(gapi.drive.realtime.EventType.VALUE_CHANGED, onDataChanged);
      subscribeToElmData((data) => map.set('app_data', data));
    }

    function onDataChanged(event) {
      console.log('onDataChanged', event);
      sendDataToElm(event.newValue);
    }

    function onError(error) {
      if (error.type == gapi.drive.realtime.ErrorType
          .TOKEN_REFRESH_REQUIRED) {
        return realtimeLoad();
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

  // To avoid 'token_refresh_required' errors from gapi.drive.realtime, 
  // we have to supply gapi.auth with our authentication token from gapi.auth2
  function setAuthToken() {
    const user = gapi.auth2.getAuthInstance().currentUser.get();
    const authResponse = user.getAuthResponse(true);
    console.log('authResponse', authResponse);
    gapi.auth.setToken(authResponse);
    // refresh before expirery
    setTimeout(() => {
      return setAuthToken();
    }, authResponse.expires_in * 0.9 * 1000 )
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