
with-db-context = (object-store, cb) ->
  " cb must return an indexeddb request "
  resolve, reject <- new Promise _
  req = window.indexedDB.open 'kartography'
  req.onerror = reject
  req.onupgradeneeded = (ev)~>
    db = req.result
    db.create-object-store "resource-cache"
  req.onsuccess = (evt)~>
    db = req.result
    trans = db.transaction ["resource-cache"], "readwrite"
    rx = cb trans.object-store "resource-cache"
    rx.onerror = reject
    rx.onsuccess = -> resolve rx

export save-cache-key = (name, blob)->
  with-db-context 'resource-cache', (.put blob, name)

export load-cache-key = (name)->>
  {result} = await with-db-context 'resource-cache', (.get name)
  result

export save-file = (file)->
  with-db-context 'files', (.put file, file.name)

export load-file = (filename)->>
  {result} = await with-db-context 'files', (.get filename)
  result
