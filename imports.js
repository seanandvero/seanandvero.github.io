(function() {
  var _imported = {};
  var _import = function(src) {
    if (src in _imported) { return; }
    _imported[src] = src;
    document.write('<script src="' + src + '"></script>');
  }
  var _csses = {};
  var _css = function(src) {
    if (src in _csses) { return; }
    _csses[src] = src;
    document.write('<link rel="stylesheet" href="' + src + '"/>'); }

  _css('pure-min.css');
  _css('grids-responsive-min.css');
  _css('demandjs.css');

  // TODO: decide on way to skip this import when es5 supported...?
  _import('polyfill/es5-shim.min.js');

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
	}

	if (!window.fetch) { _import('polyfill/fetch.js'); }

	if (!window.MutationObserver) { _import('polyfill/mutationobserver.min.js'); }
  _import('polyfill/webcomponents-hi.js');

  _import('hammer.min.js');
  _import('demandjs.min.js');
})();
