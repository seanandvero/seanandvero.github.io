(function(ctx) {
	ctx.getExifOrientation = function(file, callback) {
		var reader = new FileReader();
		reader.onload = function(e) {
      setTimeout(function() {
        var view = new DataView(e.target.result);
        if (view.getUint16(0, false) != 0xFFD8) return callback(-2);
        var length = view.byteLength, offset = 2;
        while (offset < length) {
          var marker = view.getUint16(offset, false);
          offset += 2;
          if (marker == 0xFFE1) {
            if (view.getUint32(offset += 2, false) != 0x45786966) return callback(-1);
            var little = view.getUint16(offset += 6, false) == 0x4949;
            offset += view.getUint32(offset + 4, little);
            var tags = view.getUint16(offset, little);
            offset += 2;
            for (var i = 0; i < tags; i++)
              if (view.getUint16(offset + (i * 12), little) == 0x0112)
                return callback(view.getUint16(offset + (i * 12) + 8, little));
          }
          else if ((marker & 0xFF00) != 0xFF00) break;
          else offset += view.getUint16(offset, false);
        }
        return callback(-1);
      }, 0);
		};
		file.blob().then(function (blob) {
			reader.readAsArrayBuffer(blob);
		});
	}

  ctx.exifTransform = function() {
	 	var img = this;

		if (img.getAttribute('data-exif') || false) {
        img.setAttribute('data-exif', Date.now());
				return;
		}
   	var width = img.width,
        height = img.height,
        canvas = document.createElement('canvas'),
        cvs = canvas.getContext("2d");

		fetch(img.src).
			then(function (blob) {
				ctx.getExifOrientation(blob, function (srcOrientation) {
					// set proper canvas dimensions before transform & export
					if (4 < srcOrientation && srcOrientation < 9) {
						canvas.width = height;
						canvas.height = width;
					} else {
						canvas.width = width;
						canvas.height = height;
					}

					// transform context before drawing image
					switch (srcOrientation) {
						case 2: cvs.transform(-1, 0, 0, 1, width, 0); break;
						case 3: cvs.transform(-1, 0, 0, -1, width, height ); break;
						case 4: cvs.transform(1, 0, 0, -1, 0, height ); break;
						case 5: cvs.transform(0, 1, 1, 0, 0, 0); break;
						case 6: cvs.transform(0, 1, -1, 0, height , 0); break;
						case 7: cvs.transform(0, -1, -1, 0, height , width); break;
						case 8: cvs.transform(0, -1, 1, 0, 0, width); break;
						default: break;
					}

					// draw image
					cvs.drawImage(img, 0, 0);

					var replaceSrc = true;
					if (replaceSrc) {
            img.setAttribute('data-exif', Date.now());
						img.crossOrigin = 'anonymous';
						img.src = canvas.toDataURL('image/jpeg'); 
					} else {
						img.parentNode.insertBefore(canvas, img);
						img.parentNode.removeChild(img);
					}
				});
			});
  }
})(window);
