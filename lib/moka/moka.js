// Generated by CoffeeScript 1.3.2-pre
(function() {
  var App, coffee, execSync, fs, kClosureCompilerPath, kClosureLibraryDir, kClosureLibraryNamespace, kConfigFileName, kLibDirName, kLoaderFileName, kMokaNamespace, kPackageDirName, kSourceDirName, kTempLibDirName, nodes, path, uglify, _;

  fs = require('fs');

  path = require('path');

  execSync = require('exec-sync');

  _ = require('underscore');

  execSync = require('exec-sync');

  kLoaderFileName = 'loader';

  kConfigFileName = 'Mokafile';

  kSourceDirName = 'src';

  kLibDirName = 'lib';

  kTempLibDirName = path.join(kLibDirName, 'temp');

  kClosureLibraryNamespace = 'goog';

  kClosureCompilerPath = path.join(process.env.HOME, '/Projects/JavaScript/closure-compiler/compiler.jar');

  kClosureLibraryDir = path.join(process.env.HOME, '/Projects/JavaScript/closure-library');

  kMokaNamespace = 'moka';

  kPackageDirName = path.resolve(__dirname, '../..');

  uglify = require(path.join(kPackageDirName, '/../sv_compiler/uglify-js'));

  coffee = require('../coffee-script/coffee-script');

  nodes = require('../coffee-script/nodes');

  App = (function() {

    App.className = 'App';

    function App(root) {
      if (root == null) {
        root = './';
      }
      this.root = path.resolve(kPackageDirName, root);
      this.sourceDir = path.join(this.root, kSourceDirName);
      this.tempDir = path.join(this.root, kTempLibDirName);
      if (!path.existsSync(this.tempDir)) {
        fs.mkdirSync(this.tempDir, '0755');
      }
      this.mokafilePath = path.join(this.root, kConfigFileName);
      if (!path.existsSync(this.mokafilePath)) {
        throw "Can't find Mokafile in directory " + this.root + ".";
      }
    }

    App.prototype.config = function() {
      try {
        return eval(coffee.compile(fs.readFileSync(this.mokafilePath, "utf8"), {
          bare: true
        }));
      } catch (error) {
        throw "Invalid Mokafile: " + error + ".";
      }
    };

    App.prototype.exportsForFileAtPath = function(filePath) {
      var root, source;
      if (path.existsSync(filePath)) {
        source = fs.readFileSync(filePath, 'utf-8');
        root = coffee.nodes(source);
        return this.exportsForNodesWithRoot(root);
      } else {
        throw "Can't find file at path '" + filePath + "'";
      }
    };

    App.prototype.exportsForNodesWithRoot = function(root, skipProtocols) {
      var exports;
      if (skipProtocols == null) {
        skipProtocols = true;
      }
      exports = [];
      root.eachChild(function(child) {
        if (child instanceof nodes.Assign || child instanceof nodes.Class) {
          if (!(child instanceof nodes.Protocol && skipProtocols)) {
            if (child.variable) {
              return exports.push(child.variable.base.value);
            }
          }
        }
      });
      return _.uniq(exports);
    };

    App.prototype.includesForFileAtPath = function(filePath) {
      var root, source;
      source = fs.readFileSync(filePath, 'utf-8');
      root = coffee.nodes(source);
      return this.includesForNodesWithRoot(root);
    };

    App.prototype.includesForNodesWithRoot = function(root) {
      var includes;
      includes = [];
      root.eachChild(function(child) {
        if (child instanceof nodes.Include) {
          return includes.push(child.fileName);
        }
      });
      includes = _.uniq(includes);
      return includes;
    };

    App.prototype.importsForNodesWithRoot = function(root) {
      var fileName, filePath, imports, includes, _i, _len;
      includes = this.includesForNodesWithRoot(root);
      imports = [];
      for (_i = 0, _len = includes.length; _i < _len; _i++) {
        fileName = includes[_i];
        if (fileName) {
          filePath = this.filePathForName(fileName);
          imports = imports.concat(this.exportsForFileAtPath(filePath));
        } else {
          throw "invalid fileName " + fileName;
        }
      }
      return _.uniq(imports);
    };

    App.prototype.bundlesForNodesWithRoot = function(root) {
      var bundles, self;
      bundles = [];
      self = this;
      root.eachChild(function(child) {
        var value, _i, _len, _ref, _results;
        if (child instanceof nodes.Bundle) {
          _ref = child.fileNames;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            value = _ref[_i];
            _results.push(bundles.push(value));
          }
          return _results;
        }
      });
      return _.uniq(bundles);
    };

    App.prototype.compileWithClosureCompiler = function(root) {
      var ast, code, comps, data, pro, prop, propsList, propsMap, propsMapString, tempFilePath, varStatement, _i, _len;
      if (!(path.existsSync(kClosureCompilerPath) && path.existsSync(kClosureLibraryDir))) {
        throw "Can't find closure library and/or compiler at paths " + kClosureLibraryDir + " and " + kClosureCompilerPath;
      }
      code = root.compile({
        bare: true
      });
      varStatement = code.match(/(var(?:\s+[a-zA-Z0-9$_]+\s*,?)+;)/)[1];
      code = code.replace(varStatement, '');
      tempFilePath = path.join(this.tempDir, 'module.js');
      fs.writeFileSync(tempFilePath, code, 'utf8');
      data = execSync("python " + kClosureLibraryDir + "/closure/bin/calcdeps.py --path " + kClosureLibraryDir + " --input " + tempFilePath + " \     --compiler_jar " + kClosureCompilerPath + " --output_mode compiled --compiler_flags='--compilation_level=ADVANCED_OPTIMIZATIONS' \     --compiler_flags='--formatting=pretty_print'  --compiler_flags='--create_name_map_files'");
      propsMapString = fs.readFileSync('_props_map.out', "utf8");
      propsList = propsMapString.split("\n");
      propsMap = {};
      for (_i = 0, _len = propsList.length; _i < _len; _i++) {
        prop = propsList[_i];
        comps = prop.split(":");
        if (comps.length === 2) {
          propsMap[comps[1]] = comps[0];
        }
      }
      ast = uglify.parser.parse(data);
      pro = uglify.uglify;
      console.log('propsMap', propsMap);
      ast = pro.renameProperties(ast, propsMap);
      data = pro.gen_code(ast, {
        beautify: true
      });
      fs.unlink('_vars_map.out');
      fs.unlink('_props_map.out');
      fs.unlink(tempFilePath);
      data = data.replace(/\=\s+([a-zA-Z])\.window;/, '= window;');
      root = coffee.nodes("`" + varStatement + "\n(function(){" + data + "})();`");
      return root;
    };

    App.prototype.useClosureLibrary = function(root) {
      var found;
      found = false;
      root.eachChild(function(child) {
        if (child instanceof nodes.Call && child.variable.base.value === kClosureLibraryNamespace) {
          return found = true;
        }
      });
      return found;
    };

    App.prototype.bundleNames = function(namesAndRegexes) {
      var item, names, _i, _len;
      names = [];
      for (_i = 0, _len = namesAndRegexes.length; _i < _len; _i++) {
        item = namesAndRegexes[_i];
        if (typeof item === 'string') {
          names.push(item);
        } else {
          names = names.concat(this.filePathsForRegex(item));
        }
      }
      names = _.uniq(names);
      names = _.map(names, function(name) {
        return name.replace(/\'/g, '');
      });
      return names;
    };

    App.prototype.recursivelyCompileRoot = function(root, filePath, options) {
      var allExports, allImports, allIncludes, bundleNames, bundleNamesAndRegexs, bundles, fileName, mod, name, _i, _len;
      if (options == null) {
        options = {
          module: true
        };
      }
      name = this.fileNameForPath(filePath);
      allIncludes = this.includesForNodesWithRoot(root);
      allImports = this.importsForNodesWithRoot(root);
      allExports = this.exportsForNodesWithRoot(root);
      bundleNamesAndRegexs = this.bundlesForNodesWithRoot(root);
      bundleNames = this.bundleNames(bundleNamesAndRegexs);
      bundles = {};
      for (_i = 0, _len = bundleNames.length; _i < _len; _i++) {
        fileName = bundleNames[_i];
        mod = this.readModule(fileName);
        allIncludes = allIncludes.concat(mod.includes);
        allExports = allExports.concat(mod.exports);
        allImports = allExports.concat(mod.imports);
        bundles[fileName] = mod.code;
      }
      allImports = _.difference(allImports, allExports);
      allIncludes = _.map(_.uniq(allIncludes), function(name) {
        return name.replace(/\.moka$/, '');
      });
      allIncludes = _.without(allIncludes, name);
      allIncludes = _.difference(allIncludes, bundleNames);
      if (this.useClosureLibrary(root) && !options.skipClosure) {
        root = this.compileWithClosureCompiler(root);
      }
      bundleNamesAndRegexs = _.map(bundleNamesAndRegexs, function(reg) {
        return reg.toString();
      });
      return {
        name: name,
        includes: allIncludes,
        exports: allExports,
        imports: allImports,
        code: root.compile({
          bare: true,
          bundles: bundles
        }),
        bundleNamesAndRegexs: bundleNamesAndRegexs,
        bundleNames: bundleNames,
        filePath: filePath
      };
    };

    App.prototype.privateNamespace = function() {
      if (this.config().privateNamespace) {
        return this.config().privateNamespace;
      } else {
        return this.config().namespace + '_';
      }
    };

    App.prototype.compile = function(name, code, options) {
      try {
        return coffee.compile(code, options);
      } catch (e) {
        throw "Can't compile '" + name + "',\n" + e;
      }
    };

    App.prototype.loaderFileContent = function(options) {
      var code, mainMokaPath;
      if (options == null) {
        options = {
          compiled: true
        };
      }
      mainMokaPath = path.join(this.root, 'src/loaderDelegate.moka');
      if (path.existsSync(mainMokaPath)) {
        code = ("namespace = '" + (this.config().namespace) + "'\nprivateNamespace = '" + (this.privateNamespace()) + "'") + fs.readFileSync(mainMokaPath, 'utf-8') + '\n' + fs.readFileSync(path.join(__dirname, '../../src/moka/applicationLoader.coffee'), 'utf-8');
        if (options.compiled) {
          code = this.compile('loader', code);
        }
        return code;
      } else {
        throw "Can't find loaderDelegate.moka.";
      }
    };

    App.prototype.fileNameForPath = function(filePath) {
      return filePath.match(/([^\/]+)\.moka$/)[1];
    };

    App.prototype.filePathsForRegex = function(regex) {
      var filePaths;
      filePaths = this.recursiveReadDir(this.sourceDir, regex);
      return filePaths;
    };

    App.prototype.filePathForName = function(name) {
      var cachedFilePath, filePath;
      if (!this.cachedFileNameMap_) {
        this.cachedFileNameMap_ = {};
      }
      name = /\.moka$/.test(name) ? name : "" + name + ".moka";
      cachedFilePath = this.cachedFileNameMap_[name];
      if (cachedFilePath) {
        return cachedFilePath;
      } else {
        filePath = this.recursiveReadDir(this.sourceDir, name);
        this.cachedFileNameMap_[name] = filePath;
        return filePath;
      }
    };

    App.prototype.isDir = function(file) {
      try {
        return fs.statSync(file).isDirectory();
      } catch (e) {
        return false;
      }
    };

    App.prototype.recursiveReadDir = function(dir, name) {
      var filePath, isRegex;
      isRegex = name instanceof RegExp;
      filePath = null;
      if (isRegex) {
        filePath = this.recursiveScanDirForRegExp(dir, name);
      } else {
        filePath = this.recursiveScanDirForName(dir, name);
      }
      if (!filePath) {
        console.trace();
        throw "Can't find filePath for '" + name + "'";
      }
      return filePath;
    };

    App.prototype.recursiveScanDirForRegExp = function(dir, regex) {
      var fileName, filePath, filePaths, files, matches, _i, _len;
      files = fs.readdirSync(dir);
      matches = [];
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        fileName = files[_i];
        filePath = path.join(dir, fileName);
        if (this.isDir(filePath)) {
          filePaths = this.recursiveScanDirForRegExp(filePath, regex);
          matches = matches.concat(filePaths);
        } else if (regex.test(fileName)) {
          matches.push(fileName);
        }
      }
      return matches;
    };

    App.prototype.recursiveScanDirForName = function(dir, name) {
      var fileName, filePath, files, _i, _len;
      files = fs.readdirSync(dir);
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        fileName = files[_i];
        filePath = path.join(dir, fileName);
        if (this.isDir(filePath)) {
          filePath = this.recursiveScanDirForName(filePath, name);
          if (filePath) {
            return filePath;
          }
        } else if (fileName === name) {
          return filePath;
        }
      }
    };

    App.prototype.replaceMacros = function(code, macros) {
      var prod;
      if (macros == null) {
        macros = {};
      }
      prod = macros.production === true ? true : false;
      code = code.replace(/([^A-Z_])PRODUCTION([^A-Z_])/g, "$1" + prod + "$2");
      code = code.replace(/([^A-Z_])NAMESPACE([^A-Z_])/g, "$1'" + (this.config().namespace) + "'$2");
      code = code.replace(/([^A-Z_])PRIVATE_NAMESPACE([^A-Z_])/g, "$1'" + (this.privateNamespace()) + "'$2");
      return code;
    };

    App.prototype.isCachedModuleValid = function(module) {
      var bundleNames, bundleNamesAndRegexs, cacheDate, cachedModulePath, diff, filePath, modifiedDate, name, stats, submodule, _i, _len, _ref;
      cacheDate = new Date(module.createdDate);
      stats = fs.statSync(module.filePath);
      modifiedDate = new Date(stats.mtime);
      if (cacheDate - modifiedDate > 0) {
        if (module.bundleNamesAndRegexs) {
          bundleNamesAndRegexs = _.map(module.bundleNamesAndRegexs, function(item) {
            try {
              return eval(item);
            } catch (e) {
              return item;
            }
          });
          bundleNames = this.bundleNames(bundleNamesAndRegexs);
          diff = _.difference(bundleNames, module.bundleNames);
          if (diff.length !== 0) {
            console.log("invalid cached version for " + module.name + " (diff:" + diff + ").");
            return false;
          }
        }
        _ref = module.bundleNames;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          name = _ref[_i];
          filePath = this.filePathForName(name);
          if (!filePath) {
            return false;
          }
          name = this.fileNameForPath(filePath);
          cachedModulePath = path.join(this.tempDir, name);
          if (path.existsSync(cachedModulePath)) {
            submodule = JSON.parse(fs.readFileSync(cachedModulePath, 'utf-8'));
            if (!this.isCachedModuleValid(submodule)) {
              return false;
            }
          } else {
            return false;
          }
        }
        return true;
      } else {
        return false;
      }
    };

    App.prototype.readModule = function(name, options) {
      var cachedModuleContentPath, cachedModulePath, code, data, end, filePath, module, root, source;
      if (options == null) {
        options = {
          module: true,
          content: true
        };
      }
      filePath = this.filePathForName(name);
      if (filePath) {
        name = this.fileNameForPath(filePath);
        cachedModulePath = path.join(this.tempDir, name);
        cachedModuleContentPath = cachedModulePath + '.js';
        if (path.existsSync(cachedModulePath) && path.existsSync(cachedModuleContentPath)) {
          data = fs.readFileSync(cachedModulePath, 'utf-8');
          module = JSON.parse(data);
          if (!options.content) {
            return module;
          }
          if (module.filePath === filePath && this.isCachedModuleValid(module)) {
            module.code = fs.readFileSync(cachedModuleContentPath, 'utf-8');
            return module;
          } else {

          }
        }
        console.log(name, 'Not found in cache');
        source = fs.readFileSync(filePath, 'utf-8');
        root = coffee.nodes(source);
        module = this.recursivelyCompileRoot(root, filePath, options);
        module.createdDate = new Date();
        code = module.code;
        delete module.code;
        console.log("saving ", cachedModuleContentPath);
        fs.writeFileSync(cachedModulePath, JSON.stringify(module), 'utf8');
        fs.writeFileSync(cachedModuleContentPath, code, 'utf8');
        end = (new Date).getTime();
        module.code = code;
        return module;
      } else {
        throw "Can't find file path for module '" + name + "'";
      }
    };

    App.prototype.wrapModuleContent = function(module, options) {
      var code, exportObjects, includeKeys, includeObjects, keys, mod, moduleName, name, namespace, _i, _len, _ref;
      code = module.code;
      if (options.nameWrapFunction != null) {
        keys = _.map(module.includes, options.nameWrapFunction);
        includeKeys = "[" + (keys.join(',')) + "]";
        name = options.nameWrapFunction(module.name);
      } else {
        includeKeys = JSON.stringify(module.includes);
        name = JSON.stringify(module.name);
      }
      includeObjects = [];
      _ref = module.includes;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        moduleName = _ref[_i];
        mod = this.readModule(moduleName, {
          module: true,
          content: false
        });
        includeObjects = includeObjects.concat(mod.exports);
      }
      includeObjects = includeObjects.join(', ');
      if (options.module) {
        exportObjects = module.exports.join(', ');
        namespace = this.privateNamespace() || kMokaNamespace;
        return "" + namespace + ".module(" + name + ", " + includeKeys + ", function(" + includeObjects + ") {\n" + code + "\n  return [" + exportObjects + "];\n});\n";
      } else if (options.require) {
        return "require(" + includeKeys + ", function(" + includeObjects + ") {\n" + code + "\n});\n";
      } else {
        return module.code;
      }
    };

    App.prototype.moduleContent = function(name, options) {
      var content, module;
      if (options == null) {
        options = {
          module: true
        };
      }
      module = this.readModule(name);
      content = this.wrapModuleContent(module, options);
      content = this.replaceMacros(content, options.macros);
      return content;
    };

    App.prototype.moduleContents = function(regex, options) {
      var contents, filePath, filePaths, module, name, _i, _len;
      if (options == null) {
        options = {
          module: true
        };
      }
      filePaths = this.filePathsForRegex(regex);
      contents = [];
      for (_i = 0, _len = filePaths.length; _i < _len; _i++) {
        filePath = filePaths[_i];
        name = this.fileNameForPath(filePath);
        module = this.readModule(name);
        contents.push(this.replaceMacros(this.wrapModuleContent(module, options)));
      }
      return contents;
    };

    App.prototype.moduleLoaderContent = function(options) {
      var code;
      if (options == null) {
        options = {
          compiled: true
        };
      }
      code = fs.readFileSync(path.join(__dirname, '../../src/moka/moduleManager.coffee'), 'utf-8');
      if (options.compiled) {
        code = this.compile('moduleLoader', code, {
          bare: true
        });
      }
      return this.replaceMacros(code, options.macros);
    };

    App.prototype.applicationContent = function(options) {
      var applicationMokaPath, code, importedModule, mod, obj, _i, _j, _len, _len1, _ref, _ref1;
      if (options == null) {
        options = {
          compiled: true
        };
      }
      options.compiled = true;
      delete options.module;
      console.log('options', options);
      applicationMokaPath = path.join(this.root, 'src/application.moka');
      if (path.existsSync(applicationMokaPath)) {
        code = fs.readFileSync(applicationMokaPath, 'utf-8');
        code += fs.readFileSync(path.join(__dirname, '../../src/moka/application.coffee'), 'utf-8');
        options.includes = this.includesForFileAtPath(applicationMokaPath);
        options.includeObjects = [];
        _ref = options.includes;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          importedModule = _ref[_i];
          mod = this.readModule(importedModule);
          _ref1 = mod.exports;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            obj = _ref1[_j];
            options.includeObjects.push(obj);
          }
        }
        options.require = true;
        if (options.compiled) {
          code = this.compile('application', code, options);
        }
        return this.replaceMacros(code, options.macros);
      } else {
        throw "Can't find application.moka.";
      }
    };

    App.prototype.fileContent = function(name, options) {
      var content, module, modules, _i, _len;
      console.log('file =>>', name, options.macros);
      if (name === kLoaderFileName) {
        content = this.loaderFileContent();
        content = this.compile(name, content);
        return content;
      } else {
        modules = this.config().files[name];
        console.log('modules', modules);
        if (modules) {
          content = [];
          for (_i = 0, _len = modules.length; _i < _len; _i++) {
            module = modules[_i];
            console.log('module', module);
            content.push(this.moduleContent(module, options));
          }
          console.log("name in ['main', 'app']", name === 'main' || name === 'app');
          if (name === 'main' || name === 'app') {
            content.push(this.applicationContent(options));
            content = [this.moduleLoaderContent()].concat(content);
            return "(function(){\n" + (content.join('\n')) + "\n})();";
          } else {
            return content.join('\n');
          }
        } else {
          throw "Can't find file with name " + name + ".";
        }
      }
    };

    return App;

  })();

  module.exports = function(root) {
    return new App(root);
  };

}).call(this);
