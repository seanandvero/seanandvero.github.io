(function(modules) {
  var FrameExtractorTool = function(options) {
    this.options = options;
    this.skeleton = this.generateSkeleton();
    this.isFetching = false; 
    this.maxPickerFrames = 10;
    this.pickerEpsilon = 1/5; // if we are showing more than 5 frames per second we dont offer another sub-picker (maybe we want to allow this to be customizable based on video at some point)

    this.extracted = [];
    this.target = null;
    this.onExtract = options.onExtract || function (target, extract) { }
    this.onUnExtract = options.onUnExtract || function (target, extract) { }

    window.document.body.appendChild(this.skeleton.root);
    this.hide();
  };

  FrameExtractorTool.prototype.beginFetch = function () {
    this.isFetching = true; 

    this.skeleton.root.classList.add('fetching');
  }
  FrameExtractorTool.prototype.endFetch = function () {
    this.isFetching = false; 
    this.skeleton.root.classList.remove('fetching');
  }

  FrameExtractorTool.prototype.generateSkeleton = function () {
    var container = document.createElement('div');
    container.setAttribute('class', 'frameExtractor');

    var form = document.createElement('form');
    form.addEventListener('submit', function(e) {
      // form is just used for UI stuff and should never be submittted somewhere
      e.preventDefault();
    });
    container.appendChild(form);

    var closeButton1 = this.generateCloseButton('frameExtractor-close1 pure-button pure-button-primary');
    var closeButton2 = this.generateCloseButton('frameExtractor-close2 pure-button pure-button-primary');
    
    var contentPanel = document.createElement('div');
    contentPanel.setAttribute('class', 'frameExtractor-content');
    var videoReferencePanel = document.createElement('div');
    videoReferencePanel.setAttribute('class', 'frameExtractor-videoReferencePanel');
    var extractedPanel = document.createElement('div');
    extractedPanel.setAttribute('class', 'frameExtractor-extractedPanel');
    var pickerPanel = document.createElement('div');
    pickerPanel.setAttribute('class', 'frameExtractor-pickerPanel');

    contentPanel.appendChild(extractedPanel);
    contentPanel.appendChild(videoReferencePanel);
    contentPanel.appendChild(pickerPanel);

    form.appendChild(closeButton1);
    form.appendChild(contentPanel);
    form.appendChild(closeButton2);

    return {
      root: container,
      form: form,
      closeButtons: [closeButton1, closeButton2],
      contentPanel: contentPanel,
      extractedPanel: extractedPanel,
      pickerPanel: pickerPanel,
      videoReferencePanel: videoReferencePanel
    };
  }

  FrameExtractorTool.prototype.generateCloseButton = function(classes) {
    var buttonContainer = document.createElement('div');
    var button = document.createElement('a');
    buttonContainer.appendChild(button);

    buttonContainer.setAttribute('class', 'frameExtractor-close');
    button.setAttribute('href', 'javascript:void(0)');
    button.setAttribute('class', classes);
    button.innerText = 'Close';
    var self = this;
    button.addEventListener('click', function () {
      self.hide();
    });

    return buttonContainer;
  }

  FrameExtractorTool.prototype.hide = function() {
    if (!this.skeleton || !this.skeleton.root) {
      throw 'skeleton not initialized.';
    }
    this.skeleton.root.style.display = 'none';
  }
  FrameExtractorTool.prototype.show = function() {
    if (!this.skeleton || !this.skeleton.root) {
      throw 'skeleton not initialized.';
    }
    this.skeleton.root.style.display = 'block';
  }


  FrameExtractorTool.prototype.generateFramePicker = async function(parent, startTime, endTime, baseFrame=null) {
    if (!this.url) {
      throw 'url has not been set yet';
    }

    var fps = this.fps;
    var frameStart = startTime * fps;
    var frameEnd = endTime * fps;

    var seekPerFrame = frameEnd - frameStart;
    seekPerFrame /= this.maxPickerFrames;
    seekPerFrame /= fps;

    await this.setupForExtract(this.url);

    var frames = await this.extractFramesFromVideo(seekPerFrame, frameStart, this.maxPickerFrames);

    var framePicker = {
      type: 'framePicker',
      frameStart: frameStart,
      frameEnd: frameEnd,
      fps: fps,
      seekPerFrame: seekPerFrame,
      frames: frames,
      canHaveSubPicker: seekPerFrame > this.pickerEpsilon,
      id: ('fpid_' + crypto.randomUUID()).replace('-', ''),

      parent: parent,
      baseFrame: baseFrame
    };
    var content = await this.renderFramePicker(framePicker);
    framePicker.content = content;

    return framePicker;
  };

  FrameExtractorTool.prototype.cleanupFramePicker = function (framePicker) {
    if (!framePicker) { 
      throw 'framepicker argument is required.';
    }

    var leaf = framePicker;
    while (leaf.subPicker != null) {
      leaf = leaf.subPicker;
    }

    var current = leaf;
    do {
      current = leaf;
      leaf = leaf.parent;
      current.content.remove();
      current.frames = null;
      if (current.parent) {
        current.parent.subPicker = null;
      }
      current.cleanedUp = true;
    } while (leaf && current != framePicker); 
  }

  FrameExtractorTool.prototype.openNewFramePicker = async function (parent=null, baseFrame=null) {
    try {
      if (this.isFetching) { return false; }
      this.beginFetch();

      var startTime, endTime;
      if (parent) {
        if (!baseFrame) {
          throw 'baseFrame is required if providing parent';
        }
        if (parent.subPicker) {
          if (parent.subPicker.parent != parent) {
            throw 'invalid sub picker - parent doesnt match';
          }
          // if we already have the picker we dont need to do anything
          if (parent.subPicker.baseFrame === baseFrame) { return; }

          this.cleanupFramePicker(parent.subPicker);
        }
        startTime = baseFrame.currentTime;
        endTime = baseFrame.nextTime;
      } else {
        if (this.rootFramePicker) {
          this.cleanupFramePicker(this.rootFramePicker);
        }
        startTime = this.startTime;
        endTime = this.endTime;
      }

      var newPicker = await this.generateFramePicker(parent, startTime, endTime, baseFrame);

      if (parent) {
        parent.subPicker = newPicker;
      }

      this.skeleton.pickerPanel.appendChild(newPicker.content);

    } finally {
      this.endFetch();
    }
  }

  FrameExtractorTool.prototype.renderFramePicker = async function (framePicker) {
    if (!framePicker || framePicker.type !== 'framePicker') {
      throw 'unknown type passed to renderFramePicker()';
    }

    const self = this;
    let pickerContent = document.createElement('div');
    pickerContent.setAttribute('class', 'frameExtractor-picker');

    var photoViewerName = 'pv_' + framePicker.id;
    let pickerLabel = document.createElement('div');
    pickerLabel.setAttribute('class', 'frameExtractor-heading');
    pickerLabel.innerText = '';
    pickerContent.appendChild(pickerLabel);

    var frameId = 0;
    var lastLabel = '';
    framePicker.frames.forEach(f=>{
      var container = document.createElement('div');
      container.setAttribute('class', 'frameExtractor-frame');

      let currentFrameId = frameId++;
      let closePhotoViewerInput = document.createElement('input');
      closePhotoViewerInput.setAttribute('type', 'radio');
      closePhotoViewerInput.setAttribute('name', photoViewerName);
      closePhotoViewerInput.setAttribute('id', photoViewerName + '_close_' + currentFrameId);
      closePhotoViewerInput.setAttribute('class', 'frameExtractor-photoviewer');
      let showPhotoViewerInput = document.createElement('input');
      showPhotoViewerInput.setAttribute('type', 'radio');
      showPhotoViewerInput.setAttribute('name', photoViewerName);
      showPhotoViewerInput.setAttribute('id', photoViewerName + '_view_' + currentFrameId);
      showPhotoViewerInput.setAttribute('class', 'frameExtractor-photoviewer');

      let prevPhotoViewerLabel = document.createElement('label');
      prevPhotoViewerLabel.setAttribute('for', photoViewerName + '_view_' + (currentFrameId-1));
      let prevPhotoViewerLabelContent = document.createElement('div');
      prevPhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-prev');
      prevPhotoViewerLabelContent.setAttribute('alt', 'previous photo');
      prevPhotoViewerLabel.appendChild(prevPhotoViewerLabelContent);
      container.appendChild(prevPhotoViewerLabel);

      let nextPhotoViewerLabel = document.createElement('label');
      nextPhotoViewerLabel.setAttribute('for', photoViewerName + '_view_' + (currentFrameId+1));
      let nextPhotoViewerLabelContent = document.createElement('div');
      nextPhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-next');
      nextPhotoViewerLabelContent.setAttribute('alt', 'next photo');
      nextPhotoViewerLabel.appendChild(nextPhotoViewerLabelContent);
      container.appendChild(nextPhotoViewerLabel);

      let closePhotoViewerLabel = document.createElement('label');
      closePhotoViewerLabel.setAttribute('for', photoViewerName + '_close_' + currentFrameId);
      let closePhotoViewerLabelContent = document.createElement('div');
      closePhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-close');
      closePhotoViewerLabelContent.setAttribute('alt', 'close photo viewer');
      closePhotoViewerLabel.appendChild(closePhotoViewerLabelContent);
      container.appendChild(closePhotoViewerLabel);

      var timeId = f.currentTime.toFixed(2).replace('.', '_');
      lastLabel = f.currentTime.toFixed(2);
      var label = '' + lastLabel + 's';

      if (pickerLabel.innerText === '') {
        pickerLabel.innerText = lastLabel;
      }

      var selectorInput = self.skeleton.root.querySelectorAll('#frameExtractor-isExtracted-' + timeId);
      if (selectorInput.length >= 1) {
        container.classList.add('frameExtractor-isExtracted');
      }
      container.classList.add('frameExtractor-frame-' + timeId);

      var ele = document.createElement('img');
      ele.setAttribute('class', 'frameExtractor-image nodemand');
      ele.setAttribute('src', f.image);
      ele.setAttribute('alt', label);
      container.appendChild(ele);

      var aside = document.createElement('aside');
      aside.setAttribute('class', 'frameExtractor-caption nodemand');
      var asideSpan = document.createElement('span');
      asideSpan.innerText = label;
      aside.appendChild(asideSpan);
      container.appendChild(aside);

      if (framePicker.canHaveSubPicker) {
        var newPicker = document.createElement('div');
        newPicker.setAttribute('class', 'frameExtractor-newPicker');
        newPicker.setAttribute('alt', 'create new frame picker surrounding this frame');
        newPicker.addEventListener('click', async function(e) {
          e.stopImmediatePropagation();
          await self.openNewFramePicker (framePicker, f);
        });
        container.appendChild(newPicker);
      }

      /* TODO: This code seems to be causing the browser crashes right?
      var isExtractedStyle = document.createElement('style');
      isExtractedStyle.setAttribute('type', 'text/css');
      var styleText = '#frameExtractor-isExtracted-' + lastLabel.replace('.', '_') + ':checked ~ .frameExtractor-content .frameExtractor-frame-' + lastLabel.replace('.', '_') + ' .frameExtractor-isExtracted {display:block !important;}';
      styleText += '#frameExtractor-isExtracted-' + lastLabel.replace('.', '_') + ':checked ~ .frameExtractor-content .frameExtractor-frame-' + lastLabel.replace('.', '_') + ' .frameExtractor-extract {display:none;}';
      if (isExtractedStyle.styleSheet) {
        isExtractedStyle.styleSheet.cssText = styleText;
      } else {
        isExtractedStyle.innerHTML = styleText;
      }
      container.appendChild(isExtractedStyle);*/

      var isExtractedNode = document.createElement('div');
      isExtractedNode.setAttribute('class', 'frameExtractor-isExtractedIcon');
      isExtractedNode.setAttribute('alt', 'shown if frame has been extracted');
      isExtractedNode.innerHTML = '&#x2714;';
      container.appendChild(isExtractedNode);

      var maximizer = document.createElement('div');
      maximizer.setAttribute('class', 'frameExtractor-maximize');
      maximizer.setAttribute('alt', 'show image maximized');
      maximizer.addEventListener('click', function (e) {
          e.stopImmediatePropagation();
          showPhotoViewerInput.checked = true;
      });
      container.appendChild(maximizer);

      var extractor = document.createElement('div');
      extractor.setAttribute('class', 'frameExtractor-extract');
      extractor.setAttribute('alt', 'extract image from video');
      extractor.addEventListener('click', function (e) {
        e.stopImmediatePropagation();
        self.extractFrame(framePicker, f, container);
      });
      container.appendChild(extractor);

      pickerContent.appendChild(closePhotoViewerInput);
      pickerContent.appendChild(showPhotoViewerInput);
      pickerContent.appendChild(container);
    });

    pickerLabel.innerText = '' + pickerLabel.innerText + 's to ' + lastLabel + 's';

    return pickerContent;
  }

  FrameExtractorTool.prototype.renderConfirmDialog = function (questionText, confirmText, cancelText, confirmAction=null, cancelAction=null) {
    var container = document.createElement('div');
    container.setAttribute('class', 'frameExtractor-confirm');

    var questionTextNode = document.createElement('div');
    questionTextNode.setAttribute('class', 'frameExtractor-confirmText');
    questionTextNode.innerText = questionText;
    container.appendChild(questionTextNode);

    var confirmYesContainer = document.createElement('div');
    container.appendChild(confirmYesContainer);
    var confirmYes = document.createElement('a');
    confirmYesContainer.appendChild(confirmYes);

    confirmYesContainer.setAttribute('class', 'frameExtractor-confirmYes');
    confirmYes.setAttribute('href', 'javascript:void(0)');
    confirmYes.setAttribute('class', 'pure-button pure-button-primary');
    confirmYes.innerText = confirmText;

    confirmYes.addEventListener('click', function () {
      container.remove();
      if (confirmAction) { confirmAction(); }
    });

    var confirmNoContainer = document.createElement('div');
    container.appendChild(confirmNoContainer);
    var confirmNo = document.createElement('a');
    confirmNoContainer.appendChild(confirmNo);

    confirmNoContainer.setAttribute('class', 'frameExtractor-confirmNo');
    confirmNo.setAttribute('href', 'javascript:void(0)');
    confirmNo.setAttribute('class', 'pure-button pure-button-primary');
    confirmNo.innerText = cancelText;

    confirmNo.addEventListener('click', function () {
      container.remove();
      if (cancelAction) { cancelAction(); }
    });
    
    window.document.body.appendChild(container);
  }

  FrameExtractorTool.prototype.extractFrame = function (framePicker, frame, selectorContent) {
    // TODO: skip if frame has already been extracted
   
    let extract = {
      frame: frame,
      framePicker: framePicker
    };

    this.extracted.push(extract);
    this.onExtract(this.target, extract);


    let content = this.renderExtractedFrame(extract, this.extracted.length);
    extract.content = content;
    this.skeleton.extractedPanel.appendChild(content);
  }

  FrameExtractorTool.prototype.fixupExtractedPhotoViewer = function () {
    let photoViewerName = 'pvextracted';
    var self = this;
    let currentFrameId = 0;
    this.extracted.forEach(extract=> {
      currentFrameId += 1;
      var inputs = extract.content.querySelectorAll('input.frameExtractor-photoviewer');
      inputs.forEach(input=> {
        if (input.id.contains('_close_')) {
          input.setAttribute('id', photoViewerName + '_close_' + currentFrameId);
        } else if (input.id.contains('_view_')) {
          showPhotoViewerInput.setAttribute('id', photoViewerName + '_view_' + currentFrameId);
        }
      });
      var labels = extract.content.querySelectorAll('label');
      labels.forEach(label=>{
        if (label.classList.contains('frameExtractor-photoViewer-prev')) {
          label.setAttribute('for', photoViewerName + '_view_' + (currentFrameId-1));
        } 
        else if (label.classList.contains('frameExtractor-photoViewer-next')) {
          label.setAttribute('for', photoViewerName + '_view_' + (currentFrameId+1));
        }
        else if (label.classList.contains('frameExtractor-photoViewer-close')) {
          label.setAttribute('for', photoViewerName + '_close_' + currentFrameId);
        }
      });
    });
  }

  FrameExtractorTool.prototype.renderExtractedFrame = function (extract, currentFrameId) {
    var label = '' + extract.frame.currentTime.toFixed(2);

    var stateNode = document.createElement('input');
    stateNode.setAttribute('type', 'checkbox');
    stateNode.setAttribute('checked', 'checked');
    stateNode.setAttribute('id', 'frameExtractor-isExtracted-' + label.replace('.', '_'));
    stateNode.setAttribute('class', 'frameExtractor-isExtracted');
    this.skeleton.form.insertBefore(stateNode, this.skeleton.form.firstChild);

    var extractedFrameNodes = this.skeleton.form.querySelectorAll('.frameExtractor-frame-' + label.replace('.', '_'));
    extractedFrameNodes.forEach(efn=>{
      efn.classList.add('frameExtractor-isExtracted');
    });
    extract.checkbox = stateNode;

    var parentContainer = document.createElement('div');
    parentContainer.setAttribute('class', 'frameExtractor-extractedFramePanel');

    var container = document.createElement('div');
    container.setAttribute('class', 'frameExtractor-frame');

    const self = this;

    let photoViewerName = 'pvextracted';

    let closePhotoViewerInput = document.createElement('input');
    closePhotoViewerInput.setAttribute('type', 'radio');
    closePhotoViewerInput.setAttribute('name', photoViewerName);
    closePhotoViewerInput.setAttribute('id', photoViewerName + '_close_' + currentFrameId);
    closePhotoViewerInput.setAttribute('class', 'frameExtractor-photoviewer');
    let showPhotoViewerInput = document.createElement('input');
    showPhotoViewerInput.setAttribute('type', 'radio');
    showPhotoViewerInput.setAttribute('name', photoViewerName);
    showPhotoViewerInput.setAttribute('id', photoViewerName + '_view_' + currentFrameId);
    showPhotoViewerInput.setAttribute('class', 'frameExtractor-photoviewer');

    let prevPhotoViewerLabel = document.createElement('label');
    prevPhotoViewerLabel.setAttribute('for', photoViewerName + '_view_' + (currentFrameId-1));
    let prevPhotoViewerLabelContent = document.createElement('div');
    prevPhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-prev');
    prevPhotoViewerLabelContent.setAttribute('alt', 'previous photo');
    prevPhotoViewerLabel.appendChild(prevPhotoViewerLabelContent);
    container.appendChild(prevPhotoViewerLabel);

    let nextPhotoViewerLabel = document.createElement('label');
    nextPhotoViewerLabel.setAttribute('for', photoViewerName + '_view_' + (currentFrameId+1));
    let nextPhotoViewerLabelContent = document.createElement('div');
    nextPhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-next');
    nextPhotoViewerLabelContent.setAttribute('alt', 'next photo');
    nextPhotoViewerLabel.appendChild(nextPhotoViewerLabelContent);
    container.appendChild(nextPhotoViewerLabel);

    let closePhotoViewerLabel = document.createElement('label');
    closePhotoViewerLabel.setAttribute('for', photoViewerName + '_close_' + currentFrameId);
    let closePhotoViewerLabelContent = document.createElement('div');
    closePhotoViewerLabelContent.setAttribute('class', 'frameExtractor-photoViewer-close');
    closePhotoViewerLabelContent.setAttribute('alt', 'close photo viewer');
    closePhotoViewerLabel.appendChild(closePhotoViewerLabelContent);
    container.appendChild(closePhotoViewerLabel);

    var ele = document.createElement('img');
    ele.setAttribute('class', 'frameExtractor-image nodemand');
    ele.setAttribute('src', extract.frame.image);
    ele.setAttribute('alt', label);
    container.appendChild(ele);

    var aside = document.createElement('aside');
    aside.setAttribute('class', 'frameExtractor-caption nodemand');
    var asideSpan = document.createElement('span');
    asideSpan.innerText = label;
    aside.appendChild(asideSpan);
    container.appendChild(aside);

    var maximizer = document.createElement('div');
    maximizer.setAttribute('class', 'frameExtractor-maximize');
    maximizer.setAttribute('alt', 'show image maximized');
    maximizer.addEventListener('click', function (e) {
        e.stopImmediatePropagation();
        showPhotoViewerInput.checked = true;
    });
    container.appendChild(maximizer);
    var remover = document.createElement('div');
    remover.setAttribute('class', 'frameExtractor-remove');
    remover.setAttribute('alt', 'cancel extraction');
    remover.addEventListener('click', function (e) {
        e.stopImmediatePropagation();
        self.renderConfirmDialog('Are you sure you want to cancel extracting this frame?', 'Yes', 'No',
          function () {
            self.extracted = self.extracted.filter(i=>i !== extract);
            self.onUnExtract(self.target, extract);
            parentContainer.remove();
            stateNode.remove();
            var extractedFrameNodes = self.skeleton.form.querySelectorAll('.frameExtractor-frame-' + label.replace('.', '_'));
            extractedFrameNodes.forEach(efn=>{
              efn.classList.remove('frameExtractor-isExtracted');
            });
            self.fixupExtractedPhotoViewer();
          });
    });
    container.appendChild(remover);

    parentContainer.appendChild(closePhotoViewerInput);
    parentContainer.appendChild(showPhotoViewerInput);
    parentContainer.appendChild(container);

    return parentContainer;
  }

  FrameExtractorTool.prototype.clearContent = function() {
    while (this.skeleton.videoReferencePanel.firstChild) {
      this.skeleton.videoReferencePanel.firstChild.remove();
    }
    // empty out the frame extractor
    while (this.skeleton.extractedPanel.firstChild) {
      this.skeleton.extractedPanel.firstChild.remove();
    }
    while (this.skeleton.pickerPanel.firstChild) {
      this.skeleton.pickerPanel.firstChild.remove();
    }
    var inputs= this.skeleton.form.querySelectorAll('input.frameExtractor-isExtracted');
    inputs.forEach(i=>i.remove());
  }

  FrameExtractorTool.prototype.openHandler = async function (target, url, metadata) {
    this.show();
    if (this.url === url) { return; }

    this.clearContent();

    var fps = null;
    if (!fps && metadata.exifTool.VideoFrameRate) {
      fps = parseInt(metadata.exifTool.VideoFrameRate);
    }
    if (!fps && metadata.ffprobe) {
      var ffprobeText = '' + metadata.ffprobe;
      var fpsExtract = ffprobeText.match(/([0-9]+).?([0-9]+)?\s+fps/);
      if (fpsExtract) {
        fps = parseInt(fpsExtract[1]);
      }
    }
    if (!fps) {
      fps = 25; // just a random guess
    }

    var endTime;
    if (!endTime && metadata.exifTool.Duration) {
      endTime = parseFloat(metadata.exifTool.Duration);
    }
    if (!endTime && metadata.ffprobe) {
      var ffprobeText = '' + metadata.ffprobe;
      var durationExtract = ffprobeText.match(/Duration: ([0-9][0-9]:)([0-9][0-9]:)([0-9][0-9])([0-9]+)?/);
      if (durationExtract) {
        endTime = parseInt(durationExtract[1])*60*60 + parseInt(durationExtract[2])*60 + parseInt(durationExtract[3]);
        if (durationExtract[4]) {
          endTime = parseFloat('' + endTime + '.' + durationExtract[4]);
        }
      }
    }

    this.target = target;
    this.fps = fps;
    this.url = url;
    this.metadata = metadata;
    this.startTime = 0;
    this.endTime = endTime;

    await this.openNewFramePicker();
  }

  FrameExtractorTool.prototype.cleanupExtractor = async function () {
    this.extracted = [];
    this.extractorData = null;
  };

  FrameExtractorTool.prototype.setupForExtract = async function (videoUrl) {
    if (!this.isFetching) {
      throw 'dont setup extractor without entering fetch state first';
    }
    if (this.extractorData && this.extractorData.videoUrl === videoUrl) {
      return this.extractorData;
    }

    await this.cleanupExtractor();
    this.extractorData = {
      videoUrl: videoUrl,
      seekResolve: null,
      canvas: null,
      video: null,
      context: null
    };

    // fully download it first (no buffering):
    let videoBlob = await fetch(videoUrl).then((r) => r.blob());
    let videoObjectUrl = URL.createObjectURL(videoBlob);
    let video = document.createElement("video");
    const self = this;

    video.addEventListener("seeked", async function () {
      if (self.extractorData.seekResolve) self.extractorData.seekResolve();
    });

    video.src = videoObjectUrl;

    var referenceVideo = document.createElement('video');
    referenceVideo.src = videoUrl;
    referenceVideo.setAttribute('class', 'frameExtractor-referenceVideo');
    referenceVideo.setAttribute('controls', 'controls');

    this.skeleton.videoReferencePanel.appendChild(referenceVideo);

    // workaround chromium metadata bug (https://stackoverflow.com/q/38062864/993683)
    while (
      (video.duration === Infinity || isNaN(video.duration)) &&
      video.readyState < 2
    ) {
      await new Promise((r) => setTimeout(r, 1000));
      video.currentTime = 10000000 * Math.random();
    }
    let duration = video.duration;

    let canvas = document.createElement("canvas");
    let context = canvas.getContext("2d");
    let [w, h] = [video.videoWidth, video.videoHeight];
    canvas.width = w;
    canvas.height = h;

    self.extractorData.video = video;
    self.extractorData.canvas = canvas;
    self.extractorData.context = context;
    self.extractorData.duration = duration;

    return this.extractorData;
  }

  FrameExtractorTool.prototype.extractFramesFromVideo = async function (seekPerFrame, startFrame = 0, maxFrames = 200) {
    var self = this;

    return new Promise(async (resolve) => {
      let frames = [];
      let currentTime = startFrame / this.fps;
      let context = self.extractorData.context;
      let video = self.extractorData.video;
      let canvas = self.extractorData.canvas;
      let duration = self.extractorData.duration;

      while (currentTime < duration) {
        video.currentTime = currentTime;
        await new Promise((r) => (self.extractorData.seekResolve = r));

        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        let base64ImageData = canvas.toDataURL('image/jpeg', 0.8);
        frames.push({
          currentTime: currentTime,
          nextTime: currentTime + seekPerFrame,
          isFirst: startFrame === 0,
          isLast: currentTime + seekPerFrame >= duration,
          seekPerFrame: seekPerFrame,
          image: base64ImageData,
          width: canvas.width,
          height: canvas.height
        });

        if (frames.length > maxFrames) { break; }

        currentTime += seekPerFrame;
      }
      resolve(frames);
    });
  }

  modules.FrameExtractorTool = FrameExtractorTool;
})(window);
