(function() {
  var uid = 1;
  var tapHandler = function(node, img) {
    var uuid = 'photoAlbumPressViewer_' + uid++;
    var ele = document.createElement('div');

    node.addEventListener('long-press', function(e) {
      if (ele.parentElement == null) {
        ele.classList.add('photoViewerDialog');
        var imgSrc = img.src;
        if (imgSrc.substring(imgSrc.length - 8) === '_640.jpg') {
          imgSrc = imgSrc.substring(0, imgSrc.length - 8) + '.jpg';
        }

        var innerHtml = '<input type="radio" name="' + uuid + '" id="' + uuid + '_close" class="photoViewer" />';
        innerHtml += '<input type="radio" name="' + uuid + '" id="' + uuid + '_view" class="photoViewer" />';
        innerHtml += '<div class="photoViewer">';
        innerHtml += '<label for="' + uuid + '_close"><div class="close"></div></label>';
        innerHtml += '<img class="pure-img" src="' + imgSrc + '" />';
        innerHtml += '</div>';
        ele.innerHTML = innerHtml;
        node.parentElement.insertBefore(ele, node);
      }
      var viewButton = ele.querySelector('#' + uuid + '_view');
      viewButton.click();
    });
  };

  var checkPhotoAlbumNode = function(node) {
    return node && node.matches && node.matches('body > div > div.pure-g div.photo-box') && node.hasAttribute && !node.hasAttribute('data-photoAlbumTapHandler');
  }

  var applyPhotoAlbumNode = function(node) {
    var img = node.querySelector('img');
    if (img == null) { return; }

    tapHandler(img, img);

    node.setAttribute('data-photoAlbumTapHandler', 'data-photoAlbumTapHandler');
  }

  // detect new labels being added to the DOM, and if they qualify as the magical 'close' label, rewrite them
  // as implemented in applyPhotoAlbumNode() for proper scrolling
  var photoAlbumTapApplier = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var mutation = mutations[i];
      if (mutation.type === 'childList') {
        for (var j = 0; j < mutation.addedNodes.length; j++) {
          var node = mutation.addedNodes[j];
          if (checkPhotoAlbumNode(node)) {
            applyPhotoAlbumNode(node);
          }

          if (!node.querySelectorAll) { continue; }
          var children = node.querySelectorAll('div');
          for (var k = 0; k < children.length; k++) {
            var child = children[k];
            if (checkPhotoAlbumNode(child)) {
              applyPhotoAlbumNode(child);
            }
          }
        }
      }
    }
  });
  window.addEventListener('load', function () {
    photoAlbumTapApplier.observe(window.document.body, { subtree: true, childList: true });
    var existing = window.document.querySelectorAll('body > div > div.pure-g div.photo-box');
    for (var i = 0; i < existing.length; i++) {
      if (checkPhotoAlbumNode(existing[i])) { applyPhotoAlbumNode(existing[i]); }
    }
  }, null);
})();
