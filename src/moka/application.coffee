include 'core'

MKExports PRIVATE_NAMESPACE, 'init', @, (options, callback) ->
  app = new Application
  app.load options, callback

