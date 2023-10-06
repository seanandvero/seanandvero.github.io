(function() {
  var _imported = {};
  var _import = function(src) {
    if (src in _imported) { return; }
    _imported[src] = src;
    document.write('<script src="' + src + '"></script>');
  }
  var _exec = function(src) {
    document.write('<script>' + src + '</script>');
  }
  var _csses = {};
  var _css = function(src) {
    if (src in _csses) { return; }
    _csses[src] = src;
    document.write('<link rel="stylesheet" href="' + src + '"/>'); }


  _css('pure-min.css');
  _css('grids-responsive-min.css');
  _css('demandjs.css');
  _css('masonflex.css');

  // TODO: decide on way to skip this import when es5 supported...?
  _import('polyfill/es5-shim.min.js');

  if (!String.prototype.includes) {
    _import('polyfill/string_includes.js');
  }
	if (!Array.prototype.includes) {
		_import('polyfill/array_includes.js');
	}

  if (typeof Object.assign != 'function') {
    _import('polyfill/object_assign.js');
  }
	if (!Element.prototype.matches) {
    _import('polyfill/element_matches.js');
	}
  if (!window.WeakMap) {
    _import('polyfill/weakmap-polyfill.min.js');
  }

	if (!window.Promise) {
  	_import('polyfill/promise.min.js');
	}

	if (!('IntersectionObserver' in window) || 
			!('IntersectionObserverEntry' in window) ||
			!('intersectionRatio' in window.IntersectionObserverEntry.prototype) || 
			!('isIntersecting' in window.IntersectionObserverEntry.prototype)) {
			_import('polyfill/intersection-observer.js');
      _exec('window.IntersectionObserver.prototype.POLL_INTERVAL = 100;');
	}

	if (!window.fetch) { _import('polyfill/fetch.js'); }

	if (!window.MutationObserver) { _import('polyfill/mutationobserver.min.js'); }
  _import('polyfill/webcomponents-hi.js');

  _import('hammer.min.js');
  _import('demandjs.min.js');
  _import('exif.js');
  _import('masonflex.min.js');
  _import('cryptML.js');
  _import('access.js');
  _import('passcodes.js');
  _import('photogallery_swipe.js');
  _import('long-press-event.min.js');
  _import('photoalbum_doubletap.js');
  _import('films.js');

  _import('dashjs/dash.all.min.js');
  _import('dashjs/controlbar.js');
  _css('dashjs/controlbar.css');
})();
