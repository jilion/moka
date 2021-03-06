// Generated by CoffeeScript 1.3.2-pre
(function() {
  var MKModuleManager, ModuleLoader, api, moduleManager, require;

  MKModuleManager = (function() {
    var sharedInstance_;

    MKModuleManager.className = 'MKModuleManager';

    sharedInstance_ = null;

    MKModuleManager.sharedInstance = function() {
      if (!sharedInstance_) {
        sharedInstance_ = new MKModuleManager;
      }
      return sharedInstance_;
    };

    MKModuleManager.ModuleState = {
      Loading: 0,
      Awaiting: 1,
      Installed: 2
    };

    function MKModuleManager() {
      var self;
      this.modules_ = {};
      this.moduleStates_ = {};
      this.pendingCalls_ = [];
      this.config_ = {
        paths: {}
      };
      this.context_ = new Object;
      self = this;
      this.define_(this.moduleForArgs_([
        MANGLE('require'), function() {
          return self.require_(self);
        }
      ]));
      this.require = this.require_(this)[0];
    }

    MKModuleManager.prototype.addPath = function(module, path) {
      return this.config_.paths[module] = path;
    };

    MKModuleManager.prototype.define = function() {
      var module;
      module = this.moduleForArgs_(arguments);
      if (!module) {
        throw Error('#0023');
      }
      return this.define_(module);
    };

    MKModuleManager.prototype.define_ = function(module) {
      if (!this.isInstalled_(module.name)) {
        if (this.areInstalled_(module.deps)) {
          return this.installModule_(module);
        } else {
          if (!this.isAwaiting_(module.name)) {
            this.modules_[module.name] = module;
            this.moduleStates_[module.name] = MKModuleManager.ModuleState.Awaiting;
            return this.downloadModules_(module.deps);
          }
        }
      }
    };

    MKModuleManager.prototype.require_ = function(moduleManager) {
      var requireMethod, self;
      self = moduleManager;
      requireMethod = function(moduleNames, observer) {
        var context;
        context = this.context_;
        if (self.areInstalled_(moduleNames)) {
          return observer.apply(context, self.moduleObjects_(moduleNames));
        } else {
          self.pendingCalls_.push([context, moduleNames, observer]);
          return self.downloadModules_(moduleNames);
        }
      };
      requireMethod.addPath = function(module, path) {
        return self.addPath(module, path);
      };
      return [requireMethod];
    };

    MKModuleManager.prototype.moduleObjects_ = function(moduleNames) {
      var deps, name, _i, _len;
      deps = [];
      for (_i = 0, _len = moduleNames.length; _i < _len; _i++) {
        name = moduleNames[_i];
        deps = deps.concat(this.modules_[name].objects);
      }
      return deps;
    };

    MKModuleManager.prototype.invokeModule_ = function(module) {
      var depObjects, obj;
      depObjects = this.moduleObjects_(module.deps);
      obj = module.code.apply(this.context_, depObjects);
      return obj;
    };

    MKModuleManager.prototype.installModule_ = function(module) {
      this.moduleStates_[module.name] = MKModuleManager.ModuleState.Installed;
      this.modules_[module.name] = module;
      module.objects = this.invokeModule_(module);
      return this.didInstallModule_(module);
    };

    MKModuleManager.prototype.downloadModules_ = function(names) {
      var loader, name, url, _i, _len;
      for (_i = 0, _len = names.length; _i < _len; _i++) {
        name = names[_i];
        if (this.moduleStates_[name] === void 0) {
          this.moduleStates_[name] = MKModuleManager.ModuleState.Loading;
          url = this.config_.paths[name];
          if (!url) {
            console.log("Invalid url for module '" + name + "': " + url, this.config_.paths);
            return;
          }
          loader = new ModuleLoader(url, function(error) {
            if (error) {
              return console.log(error);
            } else {

            }
          });
          loader.start();
        } else {

        }
      }
    };

    MKModuleManager.prototype.indexOf = function(list, anItem) {
      var i;
      i = 0;
      if (list.indexOf) {
        return list.indexOf(anItem);
      }
      while (i < list.length) {
        if (list[i] === anItem) {
          return i;
        }
        i++;
      }
      return -1;
    };

    MKModuleManager.prototype.didInstallModule_ = function(module) {
      var call, clonedCalls, index, moduleNames, name, _i, _len, _ref, _results;
      clonedCalls = this.pendingCalls_.slice();
      for (_i = 0, _len = clonedCalls.length; _i < _len; _i++) {
        call = clonedCalls[_i];
        moduleNames = call[1];
        if (this.areInstalled_(moduleNames)) {
          index = this.indexOf(this.pendingCalls_, call);
          this.pendingCalls_.splice(index, 1);
          call[2].apply(call[0], this.moduleObjects_(moduleNames));
        }
      }
      _ref = this.modules_;
      _results = [];
      for (name in _ref) {
        module = _ref[name];
        if (this.isAwaiting_(name) && this.areInstalled_(module.deps)) {
          _results.push(this.installModule_(module));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    MKModuleManager.prototype.moduleForArgs_ = function(args) {
      if (args.length === 2 && typeof args[0] === 'string' && typeof args[1] === 'function') {
        return {
          name: args[0],
          deps: [],
          code: args[1]
        };
      } else if (args.length === 3 && typeof args[0] === 'string' && args[1] instanceof Array && typeof args[2] === 'function') {
        return {
          name: args[0],
          deps: args[1],
          code: args[2]
        };
      } else {
        return null;
      }
    };

    MKModuleManager.prototype.isInstalled_ = function(name) {
      return this.isInState_(name, MKModuleManager.ModuleState.Installed);
    };

    MKModuleManager.prototype.areInstalled_ = function(names) {
      return this.areInState_(names, MKModuleManager.ModuleState.Installed);
    };

    MKModuleManager.prototype.isAwaiting_ = function(name) {
      return this.isInState_(name, MKModuleManager.ModuleState.Awaiting);
    };

    MKModuleManager.prototype.isInState_ = function(name, state) {
      return this.moduleStates_[name] === state;
    };

    MKModuleManager.prototype.areInState_ = function(names, state) {
      var name, _i, _len;
      for (_i = 0, _len = names.length; _i < _len; _i++) {
        name = names[_i];
        if (!this.isInState_(name, state)) {
          return false;
        }
      }
      return true;
    };

    return MKModuleManager;

  })();

  api = window[PRIVATE_NAMESPACE] = window[PRIVATE_NAMESPACE] || {};

  moduleManager = MKModuleManager.sharedInstance();

  api.module = function() {
    return moduleManager.define.apply(moduleManager, arguments);
  };

  require = function() {
    return moduleManager.require.apply(moduleManager, arguments);
  };

  ModuleLoader = (function() {

    ModuleLoader.className = 'ModuleLoader';

    function ModuleLoader(url, completion) {
      var _element;
      _element = document.createElement('script');
      _element.type = 'text/javascript';
      _element.async = true;
      _element.charset = 'utf-8';
      _element.onload = _element.onreadystatechange = this.didFinishLoading_(_element);
      _element.onerror = this.didFailLoading_(_element);
      _element.src = url;
      this._element = _element;
      this.completion = completion;
    }

    ModuleLoader.prototype.start = function() {
      var _headElement;
      _headElement = document['head'] || document.getElementsByTagName('head')[0];
      return _headElement.insertBefore(this._element, _headElement.firstChild);
    };

    ModuleLoader.prototype.didFinishLoading_ = function(_element) {
      var self;
      self = this;
      return function(_event) {
        var readyRegExp;
        _event = _event || window.event;
        readyRegExp = navigator.platform === 'PLAYSTATION 3' ? /^complete$/ : /^(complete|interactive|loaded)$/;
        if (_event.type === 'load' || readyRegExp.test(_element.readyState)) {
          _element.onload = _element.onreadystatechange = _element.onerror = null;
          if (self.completion) {
            return self.completion();
          }
        }
      };
    };

    ModuleLoader.prototype.didFailLoading_ = function(_element) {
      var self;
      self = this;
      return function(event) {
        if (self.completion) {
          return self.completion(new Error('#E001'));
        }
      };
    };

    return ModuleLoader;

  })();

}).call(this);
