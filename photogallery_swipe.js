(function() {
  var swipeHandler = function(node, prev, next) {                                                                           
        var hammer = new Hammer(node, {                                                                                         
          recognizers: [                                                                                                        
            // RecognizerClass, [options], [recognizeWith, ...], [requireFailure, ...]                                          
            [Hammer.Swipe,{ direction: Hammer.DIRECTION_HORIZONTAL }],                                                          
          ]                                                                                                                     
        });                                                                                                                     
        if(prev) {                                                                                                              
          hammer.on('swiperight', function() {                                                                                  
              prev.click();                                                                                                     
          });                                                                                                                   
        }                                                                                                                       
        if (next) {                                                                                                             
          hammer.on('swipeleft', function() {                                                                                   
            next.click();                                                                                                       
          });                                                                                                                   
        }                                                                                                                       
      };

  var checkPhotoViewerNode = function(node) {
    return node && node.nodeType === 1 && node.nodeName === 'DIV' && node.classList && node.hasAttribute && node.classList.contains('photoViewerDialog') && !node.hasAttribute('data-photoViewerObs');
  }

  var applyPhotoViewer = function(node) {
    var img = node.querySelector('img');
    if (img == null) { return; }

    var prev = node.querySelector('div.prev');
    if (prev) { prev = prev.parentNode; }
    var next = node.querySelector('div.next');
    if (next) { next = next.parentNode; }

    swipeHandler(node, prev, next);
    swipeHandler(img, prev, next);

    node.setAttribute('data-photoViewerObs', 'data-photoViewerObs');
  }

  // detect new labels being added to the DOM, and if they qualify as the magical 'close' label, rewrite them
  // as implemented in applyPhotoViewer() for proper scrolling
  var photoViewerRewriter = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var mutation = mutations[i];
      if (mutation.type === 'childList') {
        for (var j = 0; j < mutation.addedNodes.length; j++) {
          var node = mutation.addedNodes[j];
          if (checkPhotoViewerNode(node)) {
            applyPhotoViewer(node);
          }
            
          if (!node.querySelectorAll) { continue; }
          var children = node.querySelectorAll('div');
          for (var k = 0; k < children.length; k++) {
            var child = children[k];
            if (checkPhotoViewerNode(child)) {
              applyPhotoViewer(child);
            }
          }
        }
      }
    }
  });
  window.addEventListener('load', function () {
    photoViewerRewriter.observe(window.document.body, { subtree: true, childList: true });
  }, null);
})();
