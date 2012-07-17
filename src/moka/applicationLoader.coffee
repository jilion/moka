doc = document
DOMContentLoadedString = "DOMContentLoaded"
onreadystatechangeString = "onreadystatechange"
_window = window
AppNotLoaded = 0
LoadingApp = 1
AppLoaded = 2
loadApp = null
readyObservers_ = []
preparesObservers_ = []
appLoadingStatus_ = AppNotLoaded
internalReadyCallback_ = null
domLoaded_ = false
prepareCalls_ = []
forceLoadApp_ = false


isFunction = (arg) ->
  typeof arg is "function"

notifyObservers = (obs) ->
  i = 0
  while i < obs.length
    obs[i]()
    i++
  obs.length = 0

loadApplication = ->
  if domLoaded_
    loadApp() if appLoadingStatus_ is AppNotLoaded
  else
    forceLoadApp_ = true


buildAppLoader = () ->
  (cb) ->
    loadApp_ ->
      notifyObservers readyObservers_
      i = 0
      while i < prepareCalls_.length
        method = window[namespace]["prepare"]
        method.apply window, prepareCalls_[i]
        i++

      # TODO: before or after invoking cb()? I wouldsay after...
      applicationDidLoad()

      cb() if cb


loadApp_ = (callback) ->
  console.log('load app')
  callback()  if appLoadingStatus_ is AppLoaded
  return  unless appLoadingStatus_ is AppNotLoaded
  appLoadingStatus_ = LoadingApp
  loadScript applicationURL(applicationOptions), ->
    console.log('loaded')
    window[privateNamespace]["init"] applicationOptions, ->
      appLoadingStatus_ = AppLoaded
      callback()

domReady = ->
  ->
    if forceLoadApp_ or shouldLoadApplication()
      loadApp ->
        notifyObservers preparesObservers_
    else
      notifyObservers readyObservers_



loadScript = (src, callback) ->
  if src
    _container = doc.getElementsByTagName("head")[0] or doc.body
    _element = doc.createElement("script")
    _element.type = "text/javascript"
    _element.src = src
    _element.async = true # TODO: why it was set to false?!
    _element[onreadystatechangeString] = _element.onload = ->
      state = _element.readyState
      if not callback.done and (not state or (/loaded|complete/).test(state))
        callback.done = true
        callback()

    _container.appendChild _element
  else
    callback()
onReady = (callback) ->
  if domLoaded_
    callback()
  else
    internalReadyCallback_ = callback
    bindReady()

domDidLoad = ->
  ready = 0
  if doc.attachEvent and doc.readyState is "complete"
    doc.detachEvent onreadystatechangeString, domDidLoad
    ready = 1
  else if doc.addEventListener
    doc.removeEventListener DOMContentLoadedString, domDidLoad, false
    ready = 1

  if ready and not domLoaded_
    domLoaded_ = true
    internalReadyCallback_()  if internalReadyCallback_

bindReady = ->
  if doc.addEventListener
    doc.addEventListener DOMContentLoadedString, domDidLoad, false
    _window.addEventListener "load", domDidLoad, false
  else if doc.attachEvent
    doc.attachEvent onreadystatechangeString, domDidLoad
    _window.attachEvent "onload", domDidLoad
    toplevel = false
    try
      toplevel = not _window.frameElement?
    doScrollCheck()  if doc.docElement and doc.docElement.doScroll and toplevel
doScrollCheck = ->
  unless domLoaded_
    try
      doc.docElement.doScroll "left"
    catch e
      setTimeout doScrollCheck, 1
      return
    domDidLoad()

api = window[namespace] = {}
api["ready"] = (observer) ->
  readyObservers_.push observer  if isFunction(observer)

api["prepare"] = (arg1, arg2) ->
  observer = (if isFunction(arg1) then arg1 else (if isFunction(arg2) then arg2 else null))
  if appLoadingStatus_ is LoadingApp
    prepareCalls_.push [ arg1, arg2 ]
  else if appLoadingStatus_ is AppNotLoaded
    if shouldLoadApplication()
      preparesObservers_.push observer if observer
      if domLoaded_
        loadApp ->
          notifyObservers preparesObservers_
    else (if (domLoaded_) then observer() else readyObservers_.push(observer))  if observer


loadApp = buildAppLoader()
customAPI()
onReady domReady()



