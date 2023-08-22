(function(modules) {
  var dataId = 0;
  var TimelineData = function(options) {
     this.id = dataId++;
    this.elementId = 0;
    this.elements = [];
    this.cancel = false;
    this.infoHandler = function(elementData){};
    this.maximizeHandler = function(elementData){};
    this.reloadHandler = function(currentImage, elementData) {};
    this.frameExtractorHandler = function(elementData){};

    if (options && options.hasOwnProperty('infoHandler')) {
      this.infoHandler = options.infoHandler;
    }
    if (options && options.hasOwnProperty('maximizeHandler')) {
      this.maximizeHandler = options.maximizeHandler;
    }
    if (options && options.hasOwnProperty('reloadHandler')) {
      this.reloadHandler = options.reloadHandler;
    }
    if (options && options.hasOwnProperty('frameExtractorHandler')) {
      this.frameExtractorHandler = options.frameExtractorHandler;
    }

    if (options && options.hasOwnProperty('filter')) {
      this.filter = options.filter;
    } else {
      this.filter = {
        reverseOrder: false
      };
    }
  }

  //<script src="aws-sdk.min.js"></script>
  var TimelineTool = function(options) {
    
      var bucketName = options.bucket;
      var ep = new AWS.Endpoint(options.endpoint);
      var accessKeyId = options.accessKeyId;
      var secretAccessKey = options.accessKeySecret;
      this.s3 = new AWS.S3({
        endpoint: ep,
        region: options.region,
        accessKeyId,
        secretAccessKey
      });
      this.Bucket = bucketName;
      this.RootElement = document.getElementById('timelineContainer');
      this.ExpireDuration = options.expireDuration;
      this.passwords
  };

  TimelineTool.prototype.registerResizeHandler = function(resultContainer) {
    var self = this;
    resultContainer.resizeListener =  function() {
      self.onResize(resultContainer);
    };
    window.addEventListener('resize',resultContainer.resizeListener);
  }
  TimelineTool.prototype.onResize = function (resultContainer) {
    var self = this;
    var currentPos = document.documentElement.scrollTop;

    resultContainer.elements.sort(function (a,b) {
      var apos = Math.abs(currentPos - a.pos);
      var bpos = Math.abs(currentPos - b.pos);

      return apos < bpos ? -1 : apos == bpos ? 0 : 1;
    })

    resultContainer.resizeIndex = 0;

    if (!resultContainer.resizePending) {
      self.asyncResize(resultContainer);
    }
  }
  TimelineTool.prototype.asyncResize = function (resultContainer) {
    var self = this;
    if (resultContainer.cancel || resultContainer.resizeIndex >= resultContainer.elements.length) {
      resultContainer.resizePending = false;
      return;
    }

    var data = resultContainer.elements[resultContainer.resizeIndex];

    switch (data.type) {
      case 'image':
        this.sizeImage(data.metadata, data.element);
        break;
      case 'video':
        this.sizeVideo(data.metadata, data.element, data.placeholder);
        break;
      default:
        throw 'Unknown element of type ' + data.type;
    }

    resultContainer.resizePending = true;
    resultContainer.resizeIndex++;
    setTimeout(0, function() {
      self.asyncResize(resultContainer);
    });
  }

  TimelineTool.prototype.sizeVideo = function (metadata, videoNode, imgNode) {
    var rotation = 0;
    if (metadata.ffprobe) {
      var match = (/rotation of ([\-0-9.]*) degrees/).exec(metadata.ffprobe);
      if (match) {
        rotation = parseFloat(match[1]);
      }
    }

    // TODO: What should we do here if element is not in documeniz
    if (videoNode.parentNode === null) { return; }
    var maxSize = videoNode.parentNode.clientWidth;

    var vidcvs = document.createElement('canvas');
    if (metadata.width) {
      vidcvs.width = metadata.width * 4;
    } else if (metadata.exifTool && metadata.exifTool.ImageWidth) {
      vidcvs.width = metadata.exifTool.ImageWidth * 4;
    }
    if (metadata.height) {
      vidcvs.height = metadata.height * 4;
    } else if (metadata.exifTool && metadata.exifTool.ImageHeight) {
      vidcvs.height = metadata.exifTool.ImageHeight * 4;
    }

    if (rotation == parseFloat('-90.0') || rotation == parseFloat('90.0')) {
      var tmp = vidcvs.width;
      vidcvs.width = vidcvs.height;
      vidcvs.height = tmp;
    }
    var whratio = vidcvs.width / vidcvs.height;
    var hwratio = vidcvs.height / vidcvs.width;
    if (vidcvs.width > maxSize) {
      vidcvs.width = maxSize;
      vidcvs.height = hwratio * maxSize;
    }
    if (vidcvs.height > maxSize) {
      vidcvs.height = maxSize;
      vidcvs.width = maxSize * whratio;
    }

    imgNode.src = vidcvs.toDataURL('image/jpeg', 0.001);
  }
  TimelineTool.prototype.exifImageDimensions = function (metadata) {
    var adjustedWidth = 0;
    var adjustedHeight = 0;
    if (metadata.width) {
      adjustedWidth = metadata.width;
    } else if (metadata.exifTool && metadata.exifTool.ImageWidth) {
      adjustedWidth = metadata.exifTool.ImageWidth;
    }
    if (metadata.height) {
      adjustedHeight = metadata.height;
    } else if (metadata.exifTool && metadata.exifTool.ImageHeight) {
      adjustedHeight = metadata.exifTool.ImageHeight;
    }

    var hwratio = adjustedHeight/adjustedWidth;
    var whratio = adjustedWidth / adjustedHeight;

    var srcOrientation = metadata.orientation;

    switch (srcOrientation) {                                              
       case 'TopLeft': case 'TopRight': case 'BottomRight': case 'BottomLeft': 

       break;
       case 'LeftTop': case 'RightTop': case 'RightBottom': case 'LeftBottom':
          var tmp = adjustedWidth;
          adjustedWidth = adjustedHeight;
          adjustedHeight = tmp;
          tmp = hwratio;
          hwratio = whratio;
          whratio = tmp;
          break;
       break;
       
       default: break;
     }

    return {
      width: adjustedWidth,
      height: adjustedHeight,
      hwratio: hwratio,
      whratio: whratio 
    };
  }
  TimelineTool.prototype.sizeImage = function (metadata, element) {
    var maxWidth = element.parentNode.clientWidth;
    var maxHeight = element.parentNode.clientHeight;

    // rough copy from exif.js
    var adjustedWidth = 0;
    var adjustedHeight = 0;
    if (metadata.width) {
      adjustedWidth = metadata.width;
    } else if (metadata.exifTool && metadata.exifTool.ImageWidth) {
      adjustedWidth = metadata.exifTool.ImageWidth;
    }
    if (metadata.height) {
      adjustedHeight = metadata.height;
    } else if (metadata.exifTool && metadata.exifTool.ImageHeight) {
      adjustedHeight = metadata.exifTool.ImageHeight;
    }

    var hwratio = adjustedHeight/adjustedWidth;
    var whratio = adjustedWidth / adjustedHeight;


    var srcOrientation = metadata.orientation;

    switch (srcOrientation) {                                              
       case 'TopLeft': case 'TopRight': case 'BottomRight': case 'BottomLeft': 

       break;
       case 'LeftTop': case 'RightTop': case 'RightBottom': case 'LeftBottom':
          var tmp = adjustedWidth;
          adjustedWidth = adjustedHeight;
          adjustedHeight = tmp;
          tmp = hwratio;
          hwratio = whratio;
          whratio = tmp;
          break;
       break;
       
       default: break;
     }

    if (adjustedWidth > maxWidth) {
      adjustedWidth = maxWidth;
      adjustedHeight = maxWidth * hwratio;
      element.style.height = adjustedHeight;
      element.style.width = adjustedWidth;
    }
    if (adjustedHeight > maxWidth) {
      adjustedHeight = maxWidth;
      adjustedWidth = maxWidth * whratio;
      element.style.height = adjustedHeight;
      element.style.width = adjustedWidth;
    }

    /*
    //var hwratio = 1;
    //var whratio = 1;
    //adjustedWidth = 1;
    //adjustedHeight = 1;
    element.style.transformOrigin = '0 0';

     switch (srcOrientation) {                                              
        case 'TopRight': element.style.transform = 'matrix(-1, 0, 0, 1, '+adjustedWidth+', 0)'; break;
        case 'BottomRight': element.style.transform = 'matrix(-1, 0, 0, -1, '+adjustedWidth+', '+adjustedHeight+' )'; break;
        case 'BottomLeft': element.style.transform = 'matrix(1, 0, 0, -1, 0, '+adjustedHeight+' )'; break;
        case 'LeftTop': element.style.transform = 'matrix(0, '+hwratio+', '+whratio+', 0, 0, 0)'; break;
        case 'RightBottom': element.style.transform = 'matrix(0, -'+hwratio+', -'+whratio+', 0, '+adjustedWidth+' , '+adjustedHeight+')'; break;
        case 'RightTop': element.style.transform = 'matrix(0, '+hwratio+', -'+whratio+',0,'+adjustedWidth+',0)';break;
        case 'LeftBottom': element.style.transform = 'matrix(0,-'+hwratio+','+whratio+',0,0,'+adjustedHeight+')';break;
        default: break;
     }
    // as of Chrome 81 imageOrientation defaults to from-image and we need this to disable that
    element.style.imageOrientation = 'none';
    */
  }

  TimelineTool.prototype.Teardown = function(resultContainer) {
    resultContainer.cancel = true;
    resultContainer.rootElement.remove();
    window.removeEventListener('resize', resultContainer.resizeListener);
  }
  TimelineTool.prototype.Setup = function(options) {
    var data = new TimelineData(options);
    this.GetTimelineGroups(data);
    this.registerResizeHandler(data);
    return data;
  }

  TimelineTool.prototype.GetTimelineGroups = function(resultContainer) {
    if (resultContainer.cancel) { return; }
    var self = this;
      self.s3.getObject({
        Key: 'metadata/timeline.groups.max',
        Bucket:self.Bucket
      }, function(err,timelineData) {
        if (err) { 
          console.log(err, err.stack); // an error occurred
          throw 'failed loading timeline groups';
        }

        resultContainer.rootElement = document.createElement('div');
        resultContainer.rootElement.setAttribute('class', 'timeline-container');

        var parentForm = document.createElement('form');
        parentForm.appendChild(resultContainer.rootElement);

        self.RootElement.appendChild(parentForm);

        var content = new TextDecoder().decode(timelineData.Body);
        content = parseInt(content);

        if (resultContainer.filter.reverseOrder) {
          resultContainer.currentGroupSet = content;
        } else {
          resultContainer.currentGroupSet = 1;
        }

        resultContainer.currentGroups = null;
        resultContainer.currentGroupIdx = null;
        resultContainer.currentGroupFileIdx = null;
        resultContainer.maxGroup = content;

        self.GetNextTimelineGroup(resultContainer);
      });
  };
  TimelineTool.prototype.GetNextTimelineGroup = function(resultContainer) {
    if (resultContainer.cancel) { return; }
    var self = this;
    if (resultContainer.currentGroupSet > resultContainer.maxGroup ||
        resultContainer.currentGroupSet <= 0) {
      throw 'there are no remaining timeline group sets to read';
    }

    var fname = 'metadata/timeline.groups.' + resultContainer.currentGroupSet + '.json';

    self.s3.getObject({
      Key: fname,
      Bucket:this.Bucket
    }, function(err,timelineData) {
      if (err) { 
        console.log(err, err.stack); // an error occurred
        throw ('failed loading timeline groups file '+ fname);
      }

      var content = new TextDecoder().decode(timelineData.Body);
      var newGroups = JSON.parse(content);

      resultContainer.currentGroups = newGroups;
      if (resultContainer.filter.reverseOrder) {
        resultContainer.currentGroupIdx = newGroups.length-1;
      } else {
        resultContainer.currentGroupIdx = 0;
      }
      resultContainer.currentGroupFileIdx = 0;

      // do we really need to retain all groups?
      //resultContainer.groups = resultContainer.groups.Concat(newGroups);
      
      self.LoadCurrentGroup(resultContainer);
    });
  };
  TimelineTool.prototype.GetCurrentGroupElement = function(resultContainer) {
    var cgc = resultContainer.currentGroupContainer;
    var targetId = resultContainer.currentGroupIdx;
    if (cgc) {
      if (cgc.hasAttribute('data-timeline-group-idx')) {
        var attr = cgc.getAttribute('data-timeline-group-idx');
        if (attr == targetId) {
          return cgc;
        }
      }
    }

    var currentGroup = resultContainer.currentGroups[resultContainer.currentGroupIdx];

    cgc = resultContainer.currentGroupContainer = document.createElement('div');
    cgc.setAttribute('data-timeline-group-idx', targetId);
    cgc.setAttribute('class', 'timeline-group');

    var minDate = new Date(parseInt(currentGroup.minDate));
    var maxDate = new Date(parseInt(currentGroup.maxDate));

    var dateOpts = { weekday:'long', month:'long', 'day': 'numeric', year: 'numeric'};
    var dateText = '';
    if (minDate.getFullYear() == maxDate.getFullYear() && 
        minDate.getMonth() == maxDate.getMonth() &&
        minDate.getDay() == maxDate.getDay()) {
        dateText += minDate.toLocaleString('default', dateOpts);
  

        dateText += '  ';
        dateText += minDate.toLocaleTimeString('default', {hour12:false});
        dateText += ' to ';
        dateText += maxDate.toLocaleTimeString('default', {hour12:false});
    } else {
        dateOpts.hour12 = false;
        dateText += minDate.toLocaleString('default', dateOpts);
        dateText += ' to ';
        dateText += maxDate.toLocaleString('default', dateOpts);
    }
    var dateNode = document.createElement('div');
    dateNode.innerText = dateText;
    dateNode.setAttribute('class', 'timeline-date');

    cgc.appendChild(dateNode);

    var cgcParent = document.createElement('div');
    cgcParent.setAttribute('class', 'timeline-group-container');
    cgcParent.appendChild(cgc);

    resultContainer.rootElement.appendChild(cgcParent);

    return cgc;
  }

  TimelineTool.prototype.registerElement = function (resultContainer, data) {
    var rect = data.element.getBoundingClientRect();
    data['position'] = rect.top + document.body.scrollTop;
    data['id'] = resultContainer.elementId++;

    resultContainer.elements.push(data);

    data['container'].setAttribute('data-timeline-element-id', data['id']);
  }
  TimelineTool.prototype.unregisterElement = function (resultContainer, data) {
    resultContainer.elements = resultContainer.elements.filter(e=>e !== data);
    data.container.remove();
  }

  TimelineTool.prototype.isFiltered = function (resultContainer, group) {
    if (!resultContainer.filter) {
      return false;
    }

    var filter = resultContainer.filter;
    var minDate = new Date(parseInt(group.minDate));
    var maxDate = new Date(parseInt(group.maxDate));

    if (filter.minDate && filter.minDate > maxDate) {
      return true;
    }
    if (filter.maxDate && filter.maxDate < minDate) {
      return true;
    }

    return false;
  }

  var selectorId = 0;
  TimelineTool.prototype.LoadCurrentGroup = function(resultContainer) {
    if (resultContainer.cancel) { return; }
    var self = this;
    if (resultContainer.currentGroups === null) {
      throw 'no current group defined';
    }

    if (resultContainer.filter.reverseOrder) {
      if (resultContainer.currentGroupIdx < 0) {
        resultContainer.currentGroupSet--;
        this.GetNextTimelineGroup(resultContainer);
        return;
      }
    } else {
      if (resultContainer.currentGroups.length <= resultContainer.currentGroupIdx) {
        resultContainer.currentGroupSet++;
        this.GetNextTimelineGroup(resultContainer);
        return;
      }
    }
    var currentGroup = resultContainer.currentGroups[resultContainer.currentGroupIdx];
    if (self.isFiltered(resultContainer, currentGroup) || 
        currentGroup.files.length <= resultContainer.currentGroupFileIdx) {
      if (resultContainer.filter.reverseOrder) {
        resultContainer.currentGroupIdx--;
        resultContainer.currentGroupFileIdx = 0;
      } else {
        resultContainer.currentGroupIdx++;
        resultContainer.currentGroupFileIdx = 0;
      }
      this.LoadCurrentGroup(resultContainer);
      return;
    }

    var currentFile = currentGroup.files[resultContainer.currentGroupFileIdx];
    var signedUrl = self.s3.getSignedUrl('getObject', {
      Key: currentFile,
      Bucket:self.Bucket,
      Expires:self.ExpireDuration,
      ResponseContentType: 'application/octet-stream'
    });
    self.s3.getObject({
      Key: 'metadata/' + currentFile + '.metadata.json',
      Bucket:self.Bucket
    }, function(err,timelineData) {
      if (err) { 
        console.log(err, err.stack); // an error occurred
        throw 'failed loading timeline groups';
      }

      var content = new TextDecoder().decode(timelineData.Body);
      var imageMetadata = JSON.parse(content);
      if (Array.isArray(imageMetadata.width)) {
        imageMetadata.width = imageMetadata.width[0];
      }
      if (Array.isArray(imageMetadata.height)) {
        imageMetadata.height = imageMetadata.height[0];
      }

      var mySelectorId = selectorId++;

      var cgc = self.GetCurrentGroupElement(resultContainer);

      self.renderElement(resultContainer, cgc, currentFile, signedUrl, imageMetadata);
      
      resultContainer.currentGroupFileIdx++;

      // we expect this call to do something async, if it became synchronous we would need to inject async somehow
      // using setTimeout()
      self.LoadCurrentGroup(resultContainer);
    });
  }


  // image metadata requirements
  // {
  //   'filenameNoPath': 'filename to be displayed',
  //   'datetime': 'date time to be displayed',
  //   'htmlTag': 'video' or 'img',
  //   'width': size in px,
  //   'height': size in px,
  //   'orientation': 'TopLeft', 'TopRight', etc... to apply exif orientations on images -- this is currently disabled though
  // }
  TimelineTool.prototype.renderElement = function (resultContainer, groupElement, currentFile, url, metadata) {
    var mySelectorId = selectorId++;
    var self = this;

    var cgc = groupElement;

    var elementData = {
      'signedUrl': url,
      'filename': currentFile,
      'metadata': metadata,
      'groupElement': groupElement,
    };

    var container = document.createElement('div');
    container.setAttribute('class', 'timeline-content');
    container.setAttribute('id', 'timeline-container-' + mySelectorId);
    cgc.appendChild(container);
    elementData.container = container;

    if (metadata.isGenerated) {
      container.classList.add('timeline-isGenerated');
    }

    var checkbox = document.createElement('input');
    checkbox.setAttribute('type', 'checkbox');
    checkbox.setAttribute('class', 'timeline-selection');
    checkbox.setAttribute('name', 'timeline-selections');
    checkbox.setAttribute('id', 'timeline-selector-' + mySelectorId);
    checkbox.setAttribute('data-timeline-container-id', container.getAttribute('id'));
    container.appendChild(checkbox);

    // css rules depend on this element existing even if it's not allowed to be selected
    var primaryRadio = document.createElement('input');
    primaryRadio.setAttribute('type', 'radio');
    primaryRadio.setAttribute('class', 'timeline-primary');
    primaryRadio.setAttribute('name', 'timeline-primary');
    primaryRadio.setAttribute('id', 'timeline-primary-' + mySelectorId);
    primaryRadio.setAttribute('data-timeline-container-id', container.getAttribute('id'));
    container.appendChild(primaryRadio);

    var label01 = document.createElement('label');
    label01.setAttribute('for', checkbox.id);
    label01.setAttribute('class', 'timeline-select');
    container.appendChild(label01);

    var filenameNode = document.createElement('div');
    filenameNode.innerText = metadata.filenameNoPath;
    filenameNode.setAttribute('class', 'timeline-filename');
    label01.appendChild(filenameNode);

    var label02 = document.createElement('label');
    label02.setAttribute('for', checkbox.id);
    label02.setAttribute('class', 'timeline-select');
    container.appendChild(label02);

    var dateNode = document.createElement('div');
    dateNode.innerText = metadata.datetime;
    dateNode.setAttribute('class', 'timeline-date');
    label02.appendChild(dateNode);

    var infoNode = document.createElement('div');
    infoNode.innerHTML = '&nbsp;';
    infoNode.setAttribute('class', 'timeline-info');
    infoNode.addEventListener('click', (async function() { await resultContainer.infoHandler(elementData); }));
    container.appendChild(infoNode);

    if (metadata.isGenerated) {
      var generatedNode = document.createElement('div');
      generatedNode.innerText = metadata.generatedText;
      generatedNode.setAttribute('class', 'timeline-generatedNote');
      container.appendChild(generatedNode);
    }

    switch (metadata.htmlTag) {
      case 'img':
        var maximizeNode = document.createElement('div');
        maximizeNode.innerHTML = '&nbsp;';
        maximizeNode.setAttribute('class', 'timeline-maximize');
        maximizeNode.addEventListener('click', (async function() { await resultContainer.maximizeHandler(elementData); }));
        container.appendChild(maximizeNode);

        var reloadNode = document.createElement('div');
        reloadNode.innerHTML = '&nbsp;';
        reloadNode.setAttribute('class', 'timeline-reload');
        container.appendChild(reloadNode);

        var currentImage = document.createElement('img');
        currentImage.src = url;
        currentImage.crossOrigin = 'anonymous';
        currentImage.setAttribute('class', 'timeline-img');
        container.appendChild(currentImage);
        reloadNode.addEventListener('click', (async function() { await resultContainer.reloadHandler(currentImage, elementData); }));

        self.sizeImage(metadata, currentImage);

        elementData.element = currentImage;
        elementData.type = 'image';
        elementData.exifdimensions = self.exifImageDimensions(metadata);


        // so far only images are allowed to be primary
        var primaryEvtListener = function (ev) {
          ev.preventDefault();
          primaryRadio.click();
          return false;
        };
        label01.addEventListener('contextmenu', primaryEvtListener);
        label02.addEventListener('contextmenu', primaryEvtListener);
        break;

      case 'video':
        var imgNode = document.createElement('img');
        imgNode.setAttribute('class', 'timeline-video-placeholder nodemand');
        container.appendChild(imgNode);

        var frameExtractorNode = document.createElement('div');
        frameExtractorNode.innerHTML = '&nbsp;';
        frameExtractorNode.setAttribute('class', 'timeline-frameExtractor');
        frameExtractorNode.addEventListener('click', (async function() { await resultContainer.frameExtractorHandler(elementData); }));
        container.appendChild(frameExtractorNode);

        var vidNode = document.createElement('video');
        vidNode.controls = 'controls';
        vidNode.setAttribute('class', 'timeline-video');
        container.appendChild(vidNode);

        if (metadata.videoPreviews) {
          if (metadata.videoPreviews.mp4Preview) {
            var mp4Node = document.createElement('source');
            var mp4SignedUrl = self.s3.getSignedUrl('getObject', {
              Key: metadata.videoPreviews.mp4Preview,
              Bucket:self.Bucket,
              Expires:self.ExpireDuration,
              ResponseContentType: 'application/octet-stream'
            });
            mp4Node.src = mp4SignedUrl;
            mp4Node.type = 'video/mp4';
            vidNode.appendChild(mp4Node);
          }
          if (metadata.videoPreviews.webmPreview) {
            var webmNode = document.createElement('source');
            var webmSignedUrl = self.s3.getSignedUrl('getObject', {
              Key: metadata.videoPreviews.webmPreview,
              Bucket:self.Bucket,
              Expires:self.ExpireDuration,
              ResponseContentType: 'application/octet-stream'
            });
            webmNode.src = webmSignedUrl;
            webmNode.type = 'video/webm';
            vidNode.appendChild(webmNode);
          }
        }
        var originalSource = document.createElement('source');
        originalSource.src = url;
        vidNode.appendChild(originalSource);

        self.sizeVideo(metadata, vidNode, imgNode);

        elementData.element = vidNode;
        elementData.placeholder = imgNode;
        elementData.type = 'video';

        break;
        
      default:
        var maxSize = container.clientWidth;

        var contentNode = document.createElement('div');
        contentNode.setAttribute('class', 'unknown-file');
        contentNode.setAttribute('title', 'unknown file type');
        contentNode.setAttribute('alt', 'unknown file type');
        contentNode.style.width = maxSize;
        contentNode.style.height = maxSize;
        contentNode.style.backgroundSize = parseInt(maxSize * 0.75) + 'px';
        contentNode.innerHTML = '&nbsp;';
        container.appendChild(contentNode);

        checkbox.remove();
        primaryRadio.remove();

        elementData.element = contentNode;
        elementData.type = 'unknown';

        break;
    }

    self.registerElement(resultContainer, elementData);

    return elementData;
  };

  TimelineTool.prototype.getElementById = function (resultContainer, elementId) {
    var element = null;
    for (var j = 0; j < resultContainer.elements.length; j++) {
      if (resultContainer.elements[j].id == elementId) {
        element = resultContainer.elements[j];
        break;
      }
    }

    if (!element) {
      throw 'unable to find selected element i=' + i;
    }

    return element;
  }

  TimelineTool.prototype.getElementFromContainer = function (resultContainer, container) {
    var elementId = container.getAttribute('data-timeline-element-id');
    var element = this.getElementById(resultContainer, elementId);
    return element;
  }
  TimelineTool.prototype.getPrimaryContainer = function (resultContainer, primaryRadio) {
    // for the time being the mechanism for doing this is exactly the same
    return this.getSelectionContainer(resultContainer, primaryRadio);
  }
  TimelineTool.prototype.getSelectionContainer = function (resultContainer, selectionCheckbox) {
    var containerId = selectionCheckbox.getAttribute('data-timeline-container-id');
    var container = document.getElementById(containerId);
    return container;
  }
  TimelineTool.prototype.clearSelections = function (resultContainer) {
    var selections = resultContainer.rootElement.querySelectorAll('.timeline-selection:checked');
    for (var i = 0; i < selections.length; i++) {
      selections[i].click();
    }
    var primary = resultContainer.rootElement.querySelectorAll('.timeline-primary:checked');
    if (primary.length > 0) {
      primary[0].checked = false;
    }
  }
  TimelineTool.prototype.getSelections = function (resultContainer) {
    var selections = resultContainer.rootElement.querySelectorAll('.timeline-selection:checked');
    var primary = resultContainer.rootElement.querySelectorAll('.timeline-primary:checked');

    var result = {
      selected: [],
      primary: {},
      isPrimaryDefault: false
    };

    for (var i = 0; i < selections.length; i++) {
      var selection = selections[i];
      var container = this.getSelectionContainer(resultContainer, selection);
      var element = this.getElementFromContainer(resultContainer, container);

      result.selected.push(element);
    }

    var hasPrimary = false;
    if (primary.length > 0) {
      var primaryNode = primary[0];
      var primaryContainer = this.getPrimaryContainer(resultContainer, primaryNode);
      var element = this.getElementFromContainer(resultContainer, primaryContainer);

      if (element.type == 'image') {
        result.primary = element;
        hasPrimary = true;
      }
    }
    if (!hasPrimary) {
      for (var i = 0; i < result.selected.length; i++) {
        var ele = result.selected[i];
        if (ele.type == 'image') {
          result.primary = ele;
          result.isPrimaryDefault = true;
          hasPrimary = true;
        }
      }
    }
    if (!hasPrimary) {
      throw 'unable to get selections since no valid primary could be found';
    }

    return result;
  }

  TimelineTool.prototype.generatePreview = function (resultContainer, options) {
    var target = options.target;
    target.innerHtml = '';

    var selections = resultContainer.rootElement.querySelectorAll('.timeline-selection:checked');
    var primary = resultContainer.rootElement.querySelectorAll('.timeline-primary:checked');

    var previewBannerContainer = document.createElement('div');
    previewBannerContainer.setAttribute('class', 'timeline-preview-banner-container');
    target.appendChild(previewBannerContainer);

    var hasBanner = false;
    if (primary.length > 0) {
      var primaryNode = primary[0];
      var primaryContainer = this.getPrimaryContainer(resultContainer, primaryNode);
      var primaryImage = primaryContainer.querySelectorAll('img');
      var primaryVideo = primaryContainer.querySelectorAll('video');
      
      if (primaryVideo.length == 0 && primaryImage.length > 0) {
        previewBannerContainer.appendChild(primaryImage[0].cloneNode());
        hasBanner = true;
      }
    }

    if (!hasBanner) {
      var warningText = document.createElement('div');
      warningText.setAttribute('class', 'timeline-preview-warning');
      warningText.innerText = '* Banner selection chosen automatically';
      previewBannerContainer.appendChild(warningText);

      for (var i = 0; i < selections.length; i++) {
        var node = selections[i];
        var container = this.getSelectionContainer(resultContainer, node);
        var content = container.querySelectorAll('img');
        var videoContent = container.querySelectorAll('video');

        if (videoContent.length > 0) { continue; }
        if (content.length <= 0) { continue; }

        previewBannerContainer.appendChild(content[0].cloneNode());
        hasBanner = true;
      }

      if (!hasBanner) {
        warningText.setAttribute('class', 'timeline-preview-error');
        warningText.innerText = ' * No suitable image found to use for banner!';
      }
    }

    if (hasBanner) {
      var shortDescNode = document.createElement('div');
      shortDescNode.setAttribute('class', 'timeline-preview-banner-shortdesc');
      shortDescNode.innerText = options.shortdesc;
      previewBannerContainer.appendChild(shortDescNode);
    }

    var mainContainerParent = document.createElement('div');
    mainContainerParent.setAttribute('class', 'timeline-preview-article-container');
    target.appendChild(mainContainerParent);

    var mainContainer = document.createElement('div');
    mainContainer.setAttribute('class', 'masonflex');
    mainContainerParent.appendChild(mainContainer);

    for (var i = 0; i < selections.length; i++) {
      var selectionCheckbox = selections[i];
      var selectionContainer = this.getSelectionContainer(resultContainer, selectionCheckbox);
      var selectionContent = selectionContainer.querySelectorAll('img,video');

      var container = document.createElement('div');
      container.setAttribute('class', 'timeline-preview-article-element masonflex-panel photoCollage');
      
      for (var j = 0; j < selectionContent.length; j++) {
        var selectionToClone = selectionContent[j];
        var selectionClone = selectionToClone.cloneNode();
        container.appendChild(selectionClone);
      }
      mainContainer.appendChild(container);
    }

    var mf = new MasonFlex(mainContainer, {});
  }

  modules.TimelineData = TimelineData;
  modules.TimelineTool = TimelineTool;
})(window);
