class MKModuleManager

  sharedInstance_ = null
  @sharedInstance: () ->
    unless sharedInstance_
      sharedInstance_ = new MKModuleManager
    sharedInstance_

  @ModuleState =
    Loading: 0
    Awaiting: 1
    Installed: 2

  constructor: ->
    # installed modules
    @modules_ = {}
    @moduleStates_ = {}
    # put pending calls awaiting for modules to be downloaded.
    @pendingCalls_ = []
    # @moduleURLs_ = {} no needed anymore
    @config_ =
      paths: {}
    # context used to call the modules.
    @context_ = new Object

    # install require
    self = @
    @define_ @moduleForArgs_ [MANGLE('require'), () -> self.require_(self)]
    #
    # defaultModules = {require: () -> self.require_(self) }
    # for key, value of defaultModules
    #   @define_ @moduleForArgs_ [key, value]
    #
    @require = @require_(@)[0]

  addPath: (module, path) ->
    @config_.paths[module] = path;

  define: () ->
    # console.log 'define() called!'

    module = @moduleForArgs_ arguments
    if not module
      throw Error('#0023')

    # if @moduleStates_[module.name] isnt ModuleManager.ModuleState.Loading
    #   throw Error('#0062')


    @define_ module


  define_: (module) ->
    # console.group('define ' + module.name) if console.group

    unless @isInstalled_ module.name
      # install only if it's not already installed.
      # console.log module.name, '-> deps installed? ' + @areInstalled_(module.deps)

      if @areInstalled_ module.deps
        # all deps are installed, proceed installing this module.
        @installModule_ module
      else
        # download all deps first (only once)
        # console.log 'download all deps'
        unless @isAwaiting_ module.name
          @modules_[module.name] = module
          @moduleStates_[module.name] = MKModuleManager.ModuleState.Awaiting
          @downloadModules_ module.deps

    # console.groupEnd() if console.groupEnd

  require_: (moduleManager) ->
    self = moduleManager
    # console.log self
    # (context, moduleNames, observer) ->
    #   # console.log arguments
    #
    #   if context instanceof Array and typeof moduleNames is 'function'
    #     # context is null
    #     observer = moduleNames
    #     moduleNames = context
    #     context = @context_
    requireMethod = (moduleNames, observer) ->
      # console.log arguments
      context = @context_

      # console.log 'context'
      # console.log context
      # console.log 'moduleNames'
      # console.log moduleNames
      # console.log 'observer'
      # console.log observer

      # for name in moduleNames
      #   console.log 'requiring ' + self.extractModuleName_(name)
      #   console.log 'name'
      #   console.log name

      # console.log 'requiring ' + arguments.callee.caller

      if self.areInstalled_ moduleNames
        # console.log 'already installed!' + moduleNames
        # modules already installed.
        # console.log self.moduleObjects_ moduleNames
        observer.apply(context, self.moduleObjects_ moduleNames)
      else
        # not all modules are installed
        # console.log 'add to pending call'
        self.pendingCalls_.push [context, moduleNames, observer]
        self.downloadModules_ moduleNames

    requireMethod.addPath = (module, path) -> self.addPath(module, path)
    [requireMethod]


  moduleObjects_: (moduleNames) ->
    deps = []
    for name in moduleNames
      deps = deps.concat @modules_[name].objects  #@invokeModule_(@modules_[name])
    # console.log 'moduleObjects_', deps
    deps

  invokeModule_: (module) ->
    # call and store all dependencies.
    depObjects = @moduleObjects_ module.deps
    # console.log module.name
    # console.log module.code
    #
    # console.log 'depObjects ', depObjects
    # call the new module and pass it all dep objects.
    obj = module.code.apply(@context_, depObjects)

    # console.log obj
    obj

  installModule_: (module) ->
    @moduleStates_[module.name] = MKModuleManager.ModuleState.Installed
    # console.log  @moduleStates_
    # console.log "module state: " +  @moduleStates_[module.name]
    @modules_[module.name] = module
    # @invokeModule_ module
    module.objects = @invokeModule_(module)
    @didInstallModule_ module

  downloadModules_: (names) ->
    for name in names

      if @moduleStates_[name] is undefined
        # console.log 'downloading modules ' + name
        # unknown module, download it.
        @moduleStates_[name] = MKModuleManager.ModuleState.Loading
        # console.log "@@@@@@@@@ downloadModules_ @@@@@@@@@@"
        # console.log @config.customModules
        # console.log "********************** isCustom  ***************************"
        #
        # console.log name + " " + isCustom
        # console.log @config_.paths
        url = @config_.paths[name]
        unless url
          console.log "Invalid url for module '#{name}': #{url}", @config_.paths
          return

        # console.log 'module ' + name + ' @ URL: ' + url
        loader = new ModuleLoader url, (error) ->
          if error
            console.log error
          else
            # console.log 'module ' + name + " loaded"
        loader.start()
      else
        # console.log 'already downloading module ' + name

  # indexOf doesn't exist in IE6,7,8 (in other modules use _.indexOf)
  indexOf: (list, anItem) ->
    i = 0
    if list.indexOf
      return list.indexOf anItem
    while i < list.length
      if list[i] is anItem
        return i
      i++
    -1

  didInstallModule_: (module) ->
    # console.log '@@@didInstallModule_ ', module.name
    # call pending calls which modules have been downloaded.
    clonedCalls = @pendingCalls_.slice() # slice to clone
    # console.log 'SAME', clonedCalls is @pendingCalls_
    for call in clonedCalls
      moduleNames = call[1]
      # console.log '*** pending call'
      # console.log moduleNames, @moduleStates_
      if @areInstalled_ moduleNames
        # console.log "call to remove", call
        index = @indexOf @pendingCalls_, call
        # console.log "index", index
        @pendingCalls_.splice(index, 1)
        call[2].apply(call[0], @moduleObjects_ moduleNames)

    # console.log 'remaining pending calls', @pendingCalls_
    # check pending defines
    for name, module of @modules_
      # console.log 'check pending define: ' + module.name
      # console.log '@isAwaiting_ ' + @isAwaiting_(name)
      # console.log 'state ' + @moduleStates_[name]
      #
      # console.log '@areInstalled_ ' + @areInstalled_(module.deps)
      # console.log '==> ' + (@isAwaiting_(name) and @areInstalled_(module.deps))
      if @isAwaiting_(name) and @areInstalled_(module.deps)
        # console.log 'can install ' + name
        @installModule_ module


  moduleForArgs_: (args) ->

    if args.length == 2 \
       and typeof args[0] is 'string' \
       and typeof args[1] is 'function'
      # name + code
      return name: args[0], deps: [], code: args[1]

    else if args.length == 3 \
     and typeof args[0] is 'string' \
     and args[1] instanceof Array \
     and typeof args[2] is 'function'
      #  name + deps + code
      return name: args[0], deps: args[1], code: args[2]

    else
      # invalid args or number of args
      null


  # ===================
  # = State Managment =
  # ===================

  isInstalled_: (name) ->
    @isInState_ name, MKModuleManager.ModuleState.Installed

  areInstalled_: (names) ->
    # for name in names
      # console.log 'state of ' + name + ": " + @moduleStates_[name]
    @areInState_ names, MKModuleManager.ModuleState.Installed

  isAwaiting_: (name) ->
    @isInState_ name, MKModuleManager.ModuleState.Awaiting

  isInState_: (name, state) ->
    # console.log (@moduleStates_[@extractModuleName_(name)] is state)
    @moduleStates_[name] is state

  areInState_: (names, state) ->
    for name in names
      if not @isInState_(name, state)
        # console.log name
        return no
    yes



# window.sublime_ =
#   define: ModuleManager.define
api = window[PRIVATE_NAMESPACE] = window[PRIVATE_NAMESPACE] || {}

# the compiler will set the private api namespace after window
moduleManager = MKModuleManager.sharedInstance()
# bind function to moduleManager
api.module = () -> moduleManager.define.apply(moduleManager, arguments)
require = () -> moduleManager.require.apply(moduleManager, arguments)












# @usage
# loader = new ModuleLoader url, (error) ->
#   if error
#     console.log error
#   else
#     console.log 'module loaded'
# loader.start

class ModuleLoader
  constructor: (url, completion) ->
    _element = document.createElement('script')
    _element.type = 'text/javascript'
    _element.async = true
    _element.charset = 'utf-8'
    _element.onload = _element.onreadystatechange = @didFinishLoading_(_element);
    _element.onerror = @didFailLoading_(_element);
    _element.src = url
    @_element = _element
    @completion = completion

  start: () ->
    # console.log 'appending element'
    _headElement = document['head'] || document.getElementsByTagName('head')[0]
    _headElement.insertBefore(@_element, _headElement.firstChild)

  # ===========
  # = Private =
  # ===========

  didFinishLoading_: (_element) ->
    self = @
    (_event) ->
      _event = _event || window.event;
      # detect when it's done loading
      readyRegExp = if navigator.platform is 'PLAYSTATION 3' then /^complete$/ else /^(complete|interactive|loaded)$/
      if _event.type is 'load' or readyRegExp.test _element.readyState
        # release event listeners
        _element.onload = _element.onreadystatechange = _element.onerror = null;
        if self.completion
          self.completion()

  didFailLoading_: (_element) ->
    self = @
    (event) ->
      if self.completion
        self.completion(new Error('#E001'))
