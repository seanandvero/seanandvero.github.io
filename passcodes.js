(function() {
  var cmlManager = window['cml'];
  var doWatch = function() {
    // we are calling this before body is created so just do 
    // a polling loop until the browser actually gets far enough along
    if (document.body) {
      cmlManager.watchMutations();
    } else {
      setTimeout(doWatch, 100);
    }
  }
  doWatch();
  window.submitPasscode = window.submitPasscode || function(form) {
    var tbs = form.querySelectorAll('input[type="password"]');
    if (!tbs || tbs.length != 1) {
      throw 'Form contains more than one password input';
    }
    var tb = tbs[0];
    var cmlManager = window['cml'];
    cmlManager.applyPassword(tb.value);
    tb.value = '';
    return false;
  }
})();
