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
      (error) => { 
        elm.onRealtimeError.send({
            isFatal: error.isFatal, 
            message: error.message, 
            type_: error.type 
        })
      }
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

  function key(version) {
    const key = 'app_data';
    return key + version;
  }

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
    try {
      console.log('onFileLoaded')
      const map = getSetMap(doc.getModel());
      map.addEventListener(gapi.drive.realtime.EventType.VALUE_CHANGED, onDataChanged);
      subscribeToElmData((data) => {
        try { map.set('app_data', data) } catch (e) {
          console.log(e)
          // we need to add event listeners for collaborators joining/leaving
          // which we can compare to the local user's profile to 
          // tell us if we closed the document or not...
          elm.runtimeException.send(e.toString())
        }
      });
      elm.onRealtimeFileLoaded.send(true);
      elm.realtimeClose.subscribe(() => {
        try {
          doc.close();
        } catch (e) {
          console.log(e)
          elm.runtimeException.send(e.toString())
        }
      })
    } catch (e) {
      console.log(e)
      elm.runtimeException.send(e.toString())
    }
  }

  function onDataChanged(event) {
    console.log('onDataChanged', event);
    sendDataToElm(event.newValue);
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