
api = window[PRIVATE_NAMESPACE]
api or= {}
api['init'] = (options, callback) ->
  app = new Application
  app.load options, callback

