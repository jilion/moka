fs        = require 'fs'
path      = require 'path'
execSync  = require 'exec-sync'
_         = require 'underscore'

execSync  = require 'exec-sync'


# ============
# = Contants =
# ============

kLoaderFileName = 'loader'
kConfigFileName = 'Mokafile'
kSourceDirName =  'src'
kLibDirName =  'lib'
kTempLibDirName =  path.join kLibDirName, 'temp'

kClosureLibraryNamespace = 'goog'
kClosureCompilerPath = path.join process.env.HOME, '/Projects/JavaScript/closure-compiler/compiler.jar'
kClosureLibraryDir = path.join process.env.HOME, '/Projects/JavaScript/closure-library'
kMokaNamespace = 'moka'
kPackageDirName = path.resolve __dirname, '../..'

# TODO clean this
uglify = require path.join kPackageDirName, '/../sv_compiler/uglify-js'

# ===========
# = Helpers =
# ===========

coffee    = require '../coffee-script/coffee-script'
nodes     = require '../coffee-script/nodes'


# ==================
# = Moka app class =
# ==================

class App
  constructor: (root = './') ->
    @root = path.resolve kPackageDirName, root
    @sourceDir = path.join @root, kSourceDirName
    @tempDir = path.join @root, kTempLibDirName
    unless path.existsSync @tempDir
      fs.mkdirSync @tempDir, '0755'
    @mokafilePath = path.join @root, kConfigFileName
    unless path.existsSync @mokafilePath
      throw "Can't find Mokafile in directory #{@root}."

  config: ->
    try
      eval coffee.compile(fs.readFileSync(@mokafilePath, "utf8"), bare: yes)
    catch error
      throw "Invalid Mokafile: #{error}."

  exportsForFileAtPath: (filePath) ->
    if path.existsSync filePath
      source = fs.readFileSync filePath, 'utf-8'
      root = coffee.nodes source
      @exportsForNodesWithRoot root
    else
      throw "Can't find file at path '#{filePath}'"

  exportsForNodesWithRoot: (root, skipProtocols = yes) ->
    exports = []
    root.eachChild (child) ->
      if child instanceof nodes.Assign \ # variables, functions and objects.
        or child instanceof nodes.Class  # classes (hence protocols too).
          unless child instanceof nodes.Protocol and skipProtocols
            exports.push child.variable.base.value if child.variable
    _.uniq exports

  includesForFileAtPath: (filePath) ->
    source = fs.readFileSync filePath, 'utf-8'
    root = coffee.nodes source
    @includesForNodesWithRoot root

  includesForNodesWithRoot: (root) ->
    includes = []
    root.eachChild (child) ->
      if child instanceof nodes.Include
          includes.push child.fileName
    includes = _.uniq includes
    includes

  importsForNodesWithRoot: (root) ->
    includes = @includesForNodesWithRoot root
    imports = []
    for fileName in includes
      if fileName
        filePath = @filePathForName fileName
        imports = imports.concat @exportsForFileAtPath filePath
      else
        throw "invalid fileName #{fileName}"
    _.uniq imports

  bundlesForNodesWithRoot: (root) ->
    bundles = []
    self = @
    root.eachChild (child) ->
      if child instanceof nodes.Bundle
          for value in child.fileNames
            bundles.push value
    _.uniq bundles

  compileWithClosureCompiler: (root) ->
    unless path.existsSync(kClosureCompilerPath) and path.existsSync(kClosureLibraryDir)
      throw "Can't find closure library and/or compiler at paths #{kClosureLibraryDir} and #{kClosureCompilerPath}"

    code = root.compile bare:yes

    # remove var statement, otherwise the variables are traited as
    # local variables, thus renamed by closure compiler.
    varStatement = code.match(/(var(?:\s+[a-zA-Z0-9$_]+\s*,?)+;)/)[1]
    code = code.replace varStatement, ''
    tempFilePath = path.join @tempDir, 'module.js'
    fs.writeFileSync tempFilePath, code, 'utf8'

    data = execSync("python " + kClosureLibraryDir + "/closure/bin/calcdeps.py --path " + kClosureLibraryDir + " --input " + tempFilePath + " \
     --compiler_jar " + kClosureCompilerPath + " --output_mode compiled --compiler_flags='--compilation_level=ADVANCED_OPTIMIZATIONS' \
     --compiler_flags='--formatting=pretty_print'  --compiler_flags='--create_name_map_files'");
    propsMapString = fs.readFileSync '_props_map.out', "utf8"
    propsList = propsMapString.split("\n")
    propsMap = {}
    for prop in propsList
      comps = prop.split(":")
      propsMap[comps[1]] = comps[0] if comps.length is 2


    ast = uglify.parser.parse(data)
    pro = uglify.uglify;
    console.log('propsMap', propsMap)

    ast = pro.renameProperties(ast, propsMap)
    data = pro.gen_code(ast, beautify:yes)


    # for key, value of propsMap
    #   regex =  new RegExp "([^a-zA-Z0-9_\\\/])" + key + "([^a-zA-Z0-9_\\\\])", 'g'
    #   # BUG: a(a) doesn't get replaced with value(value)
    #   # HACK: perform replace twice
    #   data = data.replace(regex, "$1" + value + "$2")
    #   data = data.replace(regex, "$1" + value + "$2")

    fs.unlink  '_vars_map.out'
    fs.unlink  '_props_map.out'
    fs.unlink  tempFilePath

    # Horrible fix, check ca.animations P = f.window where f is this
    data = data.replace(/\=\s+([a-zA-Z])\.window;/, '= window;')
    root = coffee.nodes "`#{varStatement}\n(function(){#{data}})();`" # ` are to write js inside coffee
    root

  useClosureLibrary: (root) ->
    found = no
    root.eachChild (child) ->
      if child instanceof nodes.Call and child.variable.base.value is kClosureLibraryNamespace
          return found = yes
    found

  bundleNames: (namesAndRegexes) ->
    names = []
    for item in namesAndRegexes
      if typeof item is 'string'
        names.push item
      else
        names = names.concat @filePathsForRegex(item)
    names = _.uniq names
    # TODO FIX bundle name with double ', ie ''ciao''
    names = _.map names, (name) -> name.replace(/\'/g, '')
    names

  # Recursively compile the root by aggregating the imports and exports
  # of its includes and by importing the code of 'bundle' calls.
  recursivelyCompileRoot: (root, filePath, options = {module:yes}) ->
    # console.log "-- compileRoot #{filePath}, wrap:#{options.module}, compiled:#{options.compiled}"
    name = @fileNameForPath filePath
    allIncludes = @includesForNodesWithRoot root
    allImports = @importsForNodesWithRoot root
    allExports = @exportsForNodesWithRoot root
    bundleNamesAndRegexs = @bundlesForNodesWithRoot root
    bundleNames = @bundleNames bundleNamesAndRegexs

    # console.log 'mod imports', allImports
    # console.log 'mod exports', allExports
    # console.log '******** bundleNames', bundleNames
    bundles = {}
    for fileName in bundleNames
      mod = @readModule fileName
      # console.log 'imports', imports
      # console.log 'exports', exports
      allIncludes = allIncludes.concat mod.includes
      allExports = allExports.concat mod.exports
      allImports = allExports.concat mod.imports
      bundles[fileName] = mod.code
      # console.log '******** bundles', JSON.stringify bundles

    # console.log 'mod allImports ', allImports
    # console.log 'mod allExports ', allExports

    # in case the main file or some bundle imports 'exports' of other bundles in this same file.
    allImports = _.difference allImports, allExports
    allIncludes = _.map(_.uniq(allIncludes), (name) -> name.replace(/\.moka$/, ''))
    # sometimes (ie with skins) a bundled file include its parent, hence we have to remove it from
    # the list of includes
    allIncludes = _.without allIncludes, name

    # console.log 'allIncludes', allIncludes, 'bnames', bnames
    allIncludes = _.difference allIncludes, bundleNames

    root = @compileWithClosureCompiler(root) if @useClosureLibrary(root) and not options.skipClosure

    bundleNamesAndRegexs = _.map bundleNamesAndRegexs, (reg) -> reg.toString()

    name: name
    includes: allIncludes
    exports: allExports
    imports: allImports
    code: root.compile(bare: yes, bundles: bundles)
    bundleNamesAndRegexs : bundleNamesAndRegexs
    bundleNames: bundleNames
    filePath: filePath

  privateNamespace: ->
    if @config().privateNamespace then @config().privateNamespace else @config().namespace + '_'

  compile: (name, code, options) ->
    try
      coffee.compile code, options
    catch e
      throw "Can't compile '#{name}',\n#{e}"

  loaderFileContent: (options = {compiled:yes}) ->
    mainMokaPath = path.join(@root, 'src/loaderDelegate.moka')
    if path.existsSync mainMokaPath
      code = "namespace = '#{@config().namespace}'\nprivateNamespace = '#{@privateNamespace()}'" + \
      fs.readFileSync(mainMokaPath, 'utf-8') + '\n' + \
      fs.readFileSync(path.join(__dirname, '../../src/moka/applicationLoader.coffee'), 'utf-8')
      code = @compile 'loader', code if options.compiled
      code
    else
      throw "Can't find loaderDelegate.moka."

  fileNameForPath: (filePath) ->
    filePath.match(/([^\/]+)\.moka$/)[1]

  filePathsForRegex: (regex) ->
    filePaths = @recursiveReadDir @sourceDir, regex
    filePaths

  # Search for a file given its name.
  # It first scans the framework directory, if nothing is found
  # it tries with the project directory.
  filePathForName: (name) ->
    unless @cachedFileNameMap_
      @cachedFileNameMap_ = {}
    name = if /\.moka$/.test name then name else "#{name}.moka"
    cachedFilePath = @cachedFileNameMap_[name]
    if cachedFilePath
      cachedFilePath
    else
      filePath = @recursiveReadDir @sourceDir, name
      @cachedFileNameMap_[name] = filePath
      filePath

  isDir: (file) ->
    try
      return fs.statSync(file).isDirectory()
    catch e
      return no


  recursiveReadDir: (dir, name) ->
    isRegex = name instanceof RegExp
    filePath = null
    if isRegex
      # console.log "********** matches: #{@recursiveScanDirForRegExp dir, name}"
      filePath = @recursiveScanDirForRegExp dir, name
    else
      filePath = @recursiveScanDirForName dir, name
    if not filePath
      console.trace()
      throw "Can't find filePath for '#{name}'"
    filePath

  recursiveScanDirForRegExp: (dir, regex) ->
    files = fs.readdirSync dir
    matches = []
    for fileName in files
      filePath = path.join(dir, fileName)
      # console.log filePath
      if @isDir filePath
        filePaths = @recursiveScanDirForRegExp filePath, regex
        matches = matches.concat filePaths
      else if regex.test fileName
        matches.push fileName

    # console.log(typeof match) for match in matches
    matches

  recursiveScanDirForName: (dir, name) ->
    files = fs.readdirSync dir
    for fileName in files
      filePath = path.join(dir, fileName)
      if @isDir filePath
        filePath = @recursiveScanDirForName filePath, name
        return filePath if filePath
      else if fileName is name
        # console.log '#### FOUND ####'
        return filePath

  replaceMacros: (code, macros = {}) ->
    prod = if macros.production is yes then true else false
    code = code.replace(/([^A-Z_])PRODUCTION([^A-Z_])/g, "$1#{prod}$2")
    code = code.replace(/([^A-Z_])NAMESPACE([^A-Z_])/g, "$1'#{@config().namespace}'$2")
    code = code.replace(/([^A-Z_])PRIVATE_NAMESPACE([^A-Z_])/g, "$1'#{@privateNamespace()}'$2")
    code

  isCachedModuleValid: (module) ->
    cacheDate = new Date module.createdDate
    stats = fs.statSync module.filePath
    modifiedDate = new Date stats.mtime
    # console.log cacheDate
    # console.log modifiedDate

    if cacheDate - modifiedDate > 0
      # Test bundle regexes returns same files
      if module.bundleNamesAndRegexs
        bundleNamesAndRegexs = _.map module.bundleNamesAndRegexs, (item) ->
          # convert string to regexp using eval, if it fails it means it's a string.
          try
            eval item
          catch e
            item
        bundleNames = @bundleNames(bundleNamesAndRegexs)
        diff = _.difference bundleNames, module.bundleNames
        if diff.length isnt 0
          console.log "invalid cached version for #{module.name} (diff:#{diff})."
          return no
      # console.log "Valid, testing bundles of #{module.filePath}"
      for name in module.bundleNames
        filePath = @filePathForName name
        return no unless filePath
        name = @fileNameForPath filePath
        cachedModulePath = path.join @tempDir, name
        if path.existsSync cachedModulePath
          submodule = JSON.parse fs.readFileSync cachedModulePath, 'utf-8'
          unless @isCachedModuleValid submodule
            # console.log "Invalid bundle #{name}"
            return no
        else
          return no
      yes
    else
      # console.log "Invalid #{module.filePath}"
      no


  readModule: (name, options = {module:yes, content:yes}) ->
    # console.log "moduleContent: #{name}, wrap:#{options.module}, compiled:#{options.compiled}"
    # start = (new Date).getTime()

    filePath = @filePathForName name
    if filePath
      name = @fileNameForPath filePath
      cachedModulePath = path.join @tempDir, name
      cachedModuleContentPath = cachedModulePath + '.js'

      if path.existsSync(cachedModulePath) and path.existsSync(cachedModuleContentPath)
        data  = fs.readFileSync cachedModulePath, 'utf-8'
        # end = (new Date).getTime()
        # console.log "time to read module '#{name}' :", (end - start)
        # start = (new Date).getTime()
        module = JSON.parse data
        return module if not options.content

        # end = (new Date).getTime()
        # start = (new Date).getTime()

        # console.log "time to parse module '#{name}' :", (end - start)
        if module.filePath is filePath \ # maybe the module has moved.
            and @isCachedModuleValid(module)

          # valid cache, read the module content
          module.code = fs.readFileSync cachedModuleContentPath, 'utf-8'
          # end = (new Date).getTime()
          # console.log "time to read module content '#{name}' :", (end - start)
          return module
        else
          # console.log "Invalid cache version #{name}"
      console.log name, 'Not found in cache'
      source = fs.readFileSync filePath, 'utf-8'
      root = coffee.nodes source
      module = @recursivelyCompileRoot root, filePath, options
      module.createdDate = new Date()

      # place code in another file to speed up the JSON.parse().
      code = module.code
      delete module.code
      console.log "saving ", cachedModuleContentPath
      fs.writeFileSync cachedModulePath, JSON.stringify(module), 'utf8'
      fs.writeFileSync cachedModuleContentPath, code, 'utf8'

      end = (new Date).getTime()
      # console.log "time to parse module '#{name}' :", (end - start)
      module.code = code
      module
    else
      throw "Can't find file path for module '#{name}'"

  wrapModuleContent: (module, options) ->
    code = module.code

    if options.nameWrapFunction?
      # Each module name is passed to this function.
      # The user can alter or wrap the name with same js code.
      # It must return a string.
      keys = _.map module.includes, options.nameWrapFunction
      includeKeys = "[#{keys.join(',')}]"
      name = options.nameWrapFunction module.name
    else
      includeKeys = JSON.stringify module.includes
      name = JSON.stringify module.name

    includeObjects = []
    for moduleName in module.includes
       mod = @readModule moduleName, { module:yes, content:no }
       includeObjects = includeObjects.concat mod.exports
    includeObjects = includeObjects.join ', '


    if options.module
      exportObjects = module.exports.join ', '
      namespace = @privateNamespace() or kMokaNamespace
      "#{namespace}.module(#{name}, #{includeKeys}, function(#{includeObjects}) {\n#{code}\n  return [#{exportObjects}];\n});\n"
    else if options.require
      "require(#{includeKeys}, function(#{includeObjects}) {\n#{code}\n});\n"
    else
      module.code

  moduleContent: (name, options = {module:yes}) ->
    # start = (new Date).getTime()
    module = @readModule name
    # end = (new Date).getTime()
    # console.log 'time to wrap read :', (end - start)
    # start = (new Date).getTime()
    content = @wrapModuleContent(module, options)
    # end = (new Date).getTime()
    # console.log 'time to wrap module :', (end - start)
    # start = (new Date).getTime()
    content = @replaceMacros content, options.macros
    # end = (new Date).getTime()
    # console.log 'time to replace macros :', (end - start)
    content
  moduleContents: (regex, options = {module:yes}) ->
    filePaths = @filePathsForRegex regex
    contents = []
    for filePath in filePaths
      name = @fileNameForPath filePath
      module = @readModule name
      contents.push @replaceMacros(@wrapModuleContent(module, options))
    contents

  moduleLoaderContent: (options = {compiled:yes}) ->
    code = fs.readFileSync(path.join(__dirname, '../../src/moka/moduleManager.coffee'), 'utf-8')
    code = @compile 'moduleLoader', code, bare:yes if options.compiled
    @replaceMacros code, options.macros

  applicationContent: (options = {compiled:yes}) ->
    options.compiled = yes
    delete options.module
    console.log 'options', options
    applicationMokaPath = path.join(@root, 'src/application.moka')
    if path.existsSync applicationMokaPath
      code = fs.readFileSync(applicationMokaPath, 'utf-8')
      code +=  fs.readFileSync(path.join(__dirname, '../../src/moka/application.coffee'), 'utf-8')
      options.includes = @includesForFileAtPath applicationMokaPath
      options.includeObjects = []

      for importedModule in options.includes
        mod = @readModule importedModule
        # console.log 'exports', importedModule , mod.exports
        options.includeObjects.push(obj) for obj in mod.exports
      options.require = yes
      code = @compile 'application', code, options if options.compiled
      @replaceMacros code, options.macros
    else
      throw "Can't find application.moka."

  fileContent: (name, options) ->
    console.log 'file =>>', name, options.macros
    if name is kLoaderFileName
      content = @loaderFileContent()
      content = @compile name, content
      content
    else
      modules = @config().files[name]
      console.log 'modules', modules
      if modules
        content = []
        # start = (new Date).getTime()
        for module in modules
          console.log 'module', module
          content.push @moduleContent(module, options)
        console.log "name in ['main', 'app']", name in ['main', 'app']
        if name in ['main', 'app']
          content.push @applicationContent(options)
          content = [@moduleLoaderContent()].concat content
          # end = (new Date).getTime()
          # console.log 'time :', (end - start)
          "(function(){\n#{content.join('\n')}\n})();"
        else
          # end = (new Date).getTime()
          # console.log 'time :', (end - start)
          content.join '\n'
      else
        throw "Can't find file with name #{name}."

  # fileContent: (name, options) ->
  #   console.log name
  #   if name is kLoaderFileName
  #     content = @loaderFileContent()
  #     content = @compile name, content
  #     [{
  #       name: name
  #       content: content
  #     }]
  #   else
  #     modules = @config().files[name]
  #     console.log 'modules', modules
  #     if modules
  #       fileContent = []
  #       for module in modules
  #         console.log 'file', module
  #         fileContent.push {
  #           name: module
  #           content: @moduleContent(module, options)
  #         }

  #       if name is 'main'
  #         fileContent.push {
  #           name: '__application__'
  #           content: @applicationContent(options)
  #         }

  #         fileContent = [{
  #           name: '__module_loader__'
  #           content: @moduleLoaderContent()
  #         }].concat fileContent

  #       #   "(function(){\n#{content.join('\n')}\n})();"
  #       # else
  #       #   content.join '\n'
  #       fileContent

  #     else
  #       throw "Can't find file with name #{name}."

module.exports = (root) -> new App root



