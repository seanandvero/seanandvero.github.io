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
        height = img.height;

		fetch(img.src).
			then(function (blob) {
				ctx.getExifOrientation(blob, function (srcOrientation) {
          // this function is assuming we want to match our parents width as the
          // driving force behind sizing our image
          var layoutWidth = img.parentNode.clientWidth;
          var layoutHeight = img.height;
          var widthAsr = 0;
          var exifWidth = width, exifHeight = height;

					if (4 < srcOrientation && srcOrientation < 9) {
            widthAsr = layoutWidth / height;
            img.width = height;
            img.height = width;

            var tmp = exifHeight;
            exifHeight = width;
            exifWidth = tmp;
					} else {
            widthAsr = layoutWidth / width;
            img.height = height;
            img.width = width;
          }
          var adjustedWidth = layoutWidth;
          var adjustedHeight = exifHeight * widthAsr;

          img.style.transformOrigin = '0 0';

          var whratio = adjustedWidth / adjustedHeight;
          var hwratio = adjustedHeight / adjustedWidth;

					// transform context before drawing image
					switch (srcOrientation) {
						case 2: img.style.transform = 'matrix(-1, 0, 0, 1, '+adjustedWidth+', 0)'; break;
						case 3: img.style.transform = 'matrix(-1, 0, 0, -1, '+adjustedWidth+', '+adjustedHeight+' )'; break;
						case 4: img.style.transform = 'matrix(1, 0, 0, -1, 0, '+adjustedHeight+' )'; break;
						case 5: img.style.transform = 'matrix(0, '+hwratio+', '+whratio+', 0, 0, 0)'; break;
						case 6: img.style.transform = 'matrix(0, '+hwratio+', -'+whratio+', 0, '+adjustedWidth+' , 0)'; break;
						case 7: img.style.transform = 'matrix(0, -'+hwratio+', -'+whratio+', 0, '+adjustedWidth+' , '+adjustedHeight+')'; break;
						case 8: img.style.transform = 'matrix(0, -'+hwratio+', '+whratio+', 0, 0, '+adjustedHeight+')'; break;
						default: break;
					}

          img.style.height = adjustedHeight;
          img.style.width = adjustedWidth;

					var replaceSrc = true;
          img.setAttribute('data-exif', Date.now());
				});
			});
  }
})(window);
