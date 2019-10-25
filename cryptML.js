(function(ctx) {
  var cryptML = function() {
    this.accounts = {};
		this.resolved = new Map();
  };

  // FROM: https://github.com/LinusU/hex-to-array-buffer
  function cryptML_hexToBuffer(hex) {
    if (typeof hex !== 'string') {
      throw new TypeError('Expected input to be a string')
    }

    if ((hex.length % 2) !== 0) {
      throw new RangeError('Expected string to be an even number of characters')
    }

    var view = new Uint8Array(hex.length / 2)

    for (var i = 0; i < hex.length; i += 2) {
      view[i / 2] = parseInt(hex.substring(i, i + 2), 16)
    }

    return view.buffer
  }

  function cryptML_bufferToHex(buffer) {
      var s = '', h = '0123456789abcdef';
      (new Uint8Array(buffer)).forEach((v) => { s += h[v >> 4] + h[v & 15]; });
      return s;
  }

  // FROM: https://github.com/google/closure-library/blob/e877b1eac410c0d842bcda118689759512e0e26f/closure/goog/crypt/crypt.js
  function cryptML_stringToByteArray(str) {
    var output = [], p = 0;
    for (var i = 0; i < str.length; i++) {
      var c = str.charCodeAt(i);
      while (c > 0xff) {
        output[p++] = c & 0xff;
        c >>= 8;
      }
      output[p++] = c;
    }
    return output;
  };
  function cryptML_byteArrayToString(bytes) {
    return String.fromCharCode.apply(null, bytes);
  }

  var passwordCache = new Map();
  function cryptML_passwordToKey(password) {
    password = Promise.resolve(password);
    return password.then(function (p2) {
      var result;
      if (passwordCache.has(p2)) {
        result = passwordCache.get(p2);
      } else {
        result = cryptML_deriveKey(p2, 20000);
        passwordCache.set(p2, result);
      }

      return result;
    });

    return password.then(function (p2) {
      return window.crypto.subtle.digest(
        {name:'SHA-256'}, 
        new Uint8Array(cryptML_stringToByteArray(p2))
      );
    });
  }

  function cryptML_decrypt(password, data) {
    if (typeof data === 'string') {
      data = cryptML_stringToByteArray(data);
    }
    data = Promise.resolve(data);
    password = Promise.resolve(password);

    return password.then(function (p2) {
      return data.then(function(d2) {
        return cryptML_passwordToKey(p2).then(
          function (rawBytes) {
            return window.crypto.subtle.importKey(
              'raw', 
              rawBytes, 
              { name: 'AES-CBC' },
              false,
              ['encrypt', 'decrypt']
            );
        }).then(
          function (key) {
            return window.crypto.subtle.decrypt(
              { name: 'AES-CBC', iv: new ArrayBuffer(16) },
              key,
              new Uint8Array(d2)
            );
          }
         );
      });
    });
  }

  function cryptML_encrypt(password, data) {
    if (typeof data === 'string') {
      data = cryptML_stringToByteArray(data);
    }
    data = Promise.resolve(data);
    password = Promise.resolve(password);
    return password.then(function (p2) {
      return data.then(function (d2) {
        return cryptML_passwordToKey(p2).then(

          function (rawBytes) {
            return window.crypto.subtle.importKey(
              'raw', 
              rawBytes, 
              { name: 'AES-CBC' },
              false,
              ['encrypt', 'decrypt']
            );
        }).then(
          function (key) {
            return window.crypto.subtle.encrypt(
              { name: 'AES-CBC', iv: new ArrayBuffer(16) },
              key,
              new Uint8Array(d2)
            );
          }
         );
      });
    });
  }

  function cryptML_deriveKey(data, iterations) {
    var i = 0;
    var res = data;
    for (i = 0; i < iterations; i++) {
      res = cryptML_hash(res);
    }
    return res;
  }

  function cryptML_hash(data) {
    if (typeof data === 'string') {
      data = cryptML_stringToByteArray(data);
    }
    data = Promise.resolve(data);

    return data.then(function (d2) {
      return window.crypto.subtle.digest(
        { name: 'SHA-256' },
        new Uint8Array(d2)
      );
    });
  }

  function cryptML_generateEncryptionAttribute(password) {
    password = Promise.resolve(password);
    return password.then(function(p2) {
      return cryptML_encrypt(p2, p2).then(function (encrypted) {
        return cryptML_hash(encrypted);
      }).then(function (hashed) {
        return 'data-enc-' + cryptML_bufferToHex(hashed);
      });
    });
  }

	function cryptML_replaceAttrFunc(attrName, rawAttr2, password) {
		return function(node) {
      password = Promise.resolve(password);
      attrName = Promise.resolve(attrName);
      rawAttr2 = Promise.resolve(rawAttr2);
      return password.then(function (p2) {
        return rawAttr2.then(function (rawAttr) {
          return attrName.then(function (combAttr) {
            var encVal = node.getAttribute(combAttr);
            encVal = cryptML_hexToBuffer(encVal);
            return cryptML_decrypt(p2, encVal).then(function (dec) {
              var text = cryptML_byteArrayToString(new Uint8Array(dec));
              text = text.substring(24);
              node.setAttribute(rawAttr, text);
            });
          });
        });
      });
		};
	}

  function cryptML_decryptAttrFunc(rawAttr, password) {
    return function(encAttr) {
      var combAttr = encAttr + '-' + rawAttr;
      document.querySelectorAll('[' + combAttr + ']').forEach(
        cryptML_replaceAttrFunc(combAttr, rawAttr, password)
      );
    };
  }
  function cryptML_registerPasswordMap(cml, encryptedAccount, encryptedPassword) {
    // encryptedAccount should be encrypt(accountPassword,accountPassword).sha256().
    // encryptedPassword is encrypt(accountPassword,imagePassword)
    if (!(encryptedAccount in cml.accounts)) {
      cml.accounts[encryptedAccount] = [];
    }
    passwords = cml.accounts[encryptedAccount];
    
    if (!passwords.includes(encryptedPassword)) {
      passwords.push(encryptedPassword);
    }
  }
  function cryptML_getPasswords(cml, password) {
    password = Promise.resolve(password);
    return password.then(function(p2) {
      return cryptML_encrypt(p2, p2).then(function (encrypted) {
        return cryptML_hash(encrypted);
      }).then(function (hashed) {
        var hexHash = cryptML_bufferToHex(hashed);
        if (!(hexHash in cml.accounts)) {
          return Promise.resolve([]);
        }

        var passwords = cml.accounts[hexHash];
        var result = [];
        for (var i = 0; i < passwords.length; i++) {
          var pBuf = cryptML_hexToBuffer(passwords[i]);
          result.push(cryptML_decrypt(p2, pBuf).then(function (dec) {
            var text = cryptML_byteArrayToString(new Uint8Array(dec));
            text = text.substring(24);
            return text;
          }));
        }
        return Promise.all(result).then(function (results) { return results; });
      });
    });
  }
  function cryptML_searchExisting(cml, password) {
    cryptML_getPasswords(cml, password).then(function (passwords) {
      var i = 0;
      for (i = 0; i < passwords.length; i++) {
        var password = passwords[i];
        var attr = cryptML_generateEncryptionAttribute(password);  

        attr.then(cryptML_rememberPasswordFunc(cml, password));

        // do alt first so we see it when mutation observers see src and href changes
        attr.then(cryptML_decryptAttrFunc('alt', password));
        attr.then(cryptML_decryptAttrFunc('src', password));
        attr.then(cryptML_decryptAttrFunc('href', password));
      }
    });
  }
	function cryptML_rememberPasswordFunc(cml, password) {
		return function (attr) {
			cml.resolved.set(attr + '-alt', { password: password, rawAttr: 'alt' });
			cml.resolved.set(attr + '-src', { password: password, rawAttr: 'src' });
			cml.resolved.set(attr + '-href', { password: password, rawAttr: 'href' });
		}
	}

  cryptML.prototype.registerPassword = function (encryptedAccount, encryptedPassword) {
    cryptML_registerPasswordMap(this, encryptedAccount, encryptedPassword);
  }
  cryptML.prototype.applyPassword = function (password) {
    cryptML_searchExisting(this, password);
  };

  var mutationOptions = {
    childList: true,
    subtree: true 
  };
  cryptML.prototype.watchMutations = function () {
    var self = this;
    var observer = new MutationObserver((a,b)=>self.observeMutations(a,b));
    observer.observe(document.body, mutationOptions);
    self.observer = observer;
  }
  cryptML.prototype.observeMutations = function (mutations) {
		for (var i = 0; i < mutations.length; i++) {
			var mutation = mutations[i];
			if (mutation.type !== 'childList') { continue; }
			for (var j = 0; j < mutation.addedNodes.length; j++) {
				var added = mutation.addedNodes[j];
				// haven't identified why this happens, maybe document.createElement()?
				if (!added.parentNode) { continue; }
				this.checkAdditionRecursive(added);
			}
    }
  }
	cryptML.prototype.checkAdditionRecursive = function (added) {
		var remaining = [added];
		while (remaining.length > 0) {
			added = remaining.shift();

      this.resolved.forEach(function (data, attr) {
        if (added.hasAttribute && added.hasAttribute(attr)) {
          var fun = cryptML_replaceAttrFunc(attr, data.rawAttr, data.password); 
          fun(added);
        }
      });

			if(added.children) {
				for (var i = 0; i < added.children.length; i++) {
					var child = added.children[i];
					remaining.push(child);
				}
			}
		}
	}

  ctx['CryptML'] = cryptML;
})(window);
