doc = document
DOMContentLoadedString = "DOMContentLoaded"
onreadystatechangeString = "onreadystatechange"
_window = window
AppNotLoaded = 0
LoadingApp = 1
AppLoaded = 2
readyObservers_ = []
appLoadingStatus_ = AppNotLoaded
domLoaded_ = false

isFunction = (arg) ->
  typeof arg is "function"

notifyObservers = (obs) ->
  i = 0
  while i < obs.length
    obs[i]()
    i++
  obs.length = 0

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

unbindReady = ->
  return unless _binded
  _binded = no
  if doc.addEventListener
    doc.removeEventListener DOMContentLoadedString, domDidLoad, false
    _window.removeEventListener "load", domDidLoad, false
  else
    doc.detachEvent onreadystatechangeString, domDidLoad
    _window.detachEvent "onload", domDidLoad

domDidLoad = (_event) ->
  _event = _window.event unless _event
  if doc.addEventListener or doc.readyState is "complete" or (_event and _event.type is "load")
    unbindReady()
    unless domLoaded_
      domLoaded_ = true
      loadApplication() if shouldLoadApplication() or forceAppLoading_

bindReady = ->
  _binded = yes
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

###
TO REMOVE PLEASE
###
if not _window.console
  f = ->
  _window.console =
    log: f
    warn: f
    error: f
    debug: f

forceAppLoading_ = no

loadApplication = ->
  return  unless appLoadingStatus_ is AppNotLoaded
  appLoadingStatus_ = LoadingApp
  loadScript applicationURL(applicationOptions), ->
    _window[privateNamespace]["init"] applicationOptions, ->
      appLoadingStatus_ = AppLoaded
      notifyObservers readyObservers_
      applicationDidLoad()
  `undefined`

api = _window[namespace]
if api and api['ready'] and api['load']
  console.error 'SublimeVideo loader has been installed more than once.'
else
  api = _window[namespace] = {}
  api["ready"] = (observer) ->
    if appLoadingStatus_ is AppLoaded
      observer()
    else
      readyObservers_.push observer if isFunction(observer)
    `undefined`

  api["load"] = ->
    if domLoaded_
      loadApplication()
    else
      forceAppLoading_ = yes
    `undefined`

  customAPI()
  if document.readyState is "complete"
    # document is already laoded, fire callback
    domDidLoad()
  else
    _jQuery = _window.jQuery
    if _jQuery and isFunction(_jQuery.ready)
      _jQuery(doc).ready domDidLoad
    else
      bindReady()

