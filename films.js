(function(module) { 
  var hashList = {}; 
  var oldHash = null; 
  var forcingRefresh = false;
  var onHashChange = function () {
    var shouldRefresh = false;
    if (oldHash && window.location.hash !== oldHash) {
      onCloseFilm(oldHash);
    }
    if (hashList.hasOwnProperty(window.location.hash)) {
      initializePlayer(hashList[window.location.hash]);
      shouldRefresh = !forcingRefresh;
    }
    oldHash = window.location.hash;

    if (shouldRefresh) {
      var finalHash = oldHash;
      forcingRefresh = true;
      setTimeout(function() {
        window.location.hash = '';
        setTimeout(function() {
          window.location.hash = finalHash;
          setTimeout(function() {
            forcingRefresh = false;
          }, 0);
        }, 0);
      }, 0);
    }
  }

  addEventListener('hashchange', event=> {
    onHashChange();
  });
  onHashChange();

  var initializePlayer = function(content) {
    if (content.initialized) { return; }
    if (!content.video) { throw 'video not assigned on content'; }

    var isAndroid = /(android)/i.test(navigator.userAgent);

    if (!isAndroid && content.filmUrlHls && content.video.canPlayType('application/vnd.apple.mpegurl')) {
      content.video.src = content.filmUrlHls;
      content.contentRoot.querySelector('.video-controller').style.display = 'none';
    } else {
      var video = content.video;
      var player = dashjs.MediaPlayer().create();
      player.initialize(content.video, content.filmUrl, true);
      player.updateSettings({
        'debug': {
          'logLevel': dashjs.Debug.LOG_LEVEL_NONE
        }
      });
      //FASTSWITCH was braeking android chrome, may adversely affect other browsers, so disabled for now, possibly look into enabling for known compatible browsers only?
      player.updateSettings({
        'streaming': {
          'buffer': {
            'fastSwitchEnabled': false
          }
        }
      });
      player.setAutoPlay(false);
      var controlbar = new ControlBar(player);
      controlbar.initialize(content.filmIdPrefix);
      video.dashPlayer = player;
      video.dashControlbar = controlbar;
    }
    content.initialized = true;
  }

  var onCloseFilm = function (filmId) {
    if (!hashList.hasOwnProperty(filmId)) { return; }
    if (!hashList[oldHash].initialized) {return;}
    if (!hashList[oldHash].video) {return;}
    if (!hashList[oldHash].video.dashPlayer) {return;}

    hashList[filmId].video.dashPlayer.pause();
  }
  var templateWriter = function (filmIdPrefix, thumbUrl, thumbAlt, filmUrl, filmUrlHls, extraContent) {
    var validationRegex = /["'#]/;
    if (validationRegex.test(filmIdPrefix)) { throw 'filmdIdPrefix ' + flimIdPrefix + ' contains invalid chars'; }
    if (validationRegex.test(thumbUrl)) { throw 'thumbUrl ' + thumbUrl + ' contains invalid chars'; }
    if (validationRegex.test(filmUrl)) { throw 'filmUrl ' + filmUrl + ' contains invalid chars'; }

    var content = {
      initialized: false,
      filmIdPrefix: filmIdPrefix,
      filmId: filmIdPrefix,
      filmUrl: filmUrl,
      filmUrlHls: filmUrlHls,
      thumbId: filmIdPrefix + '_thumb',
      thumbUrl: thumbUrl,
      key: '#' + filmIdPrefix,
      contentRoot: null,
      video: null
    }
    hashList[content.key] = content;

    document.write("<div class=\"photo-box u-1\" id=\"" + content.thumbId + "\"><a class=\"article\" href=\"#dunes_2023_film\">");
    document.write("  <img crossorigin=\"anonymous\" src=\"" + thumbUrl + "\" alt=\"" + thumbAlt + "\">");
    document.write("<\/a><\/div>");
    document.write("<div class=\"text-box u-1 full-row article\" id=\"" + content.filmId + "\">");
    document.write("  <a class=\"articleClose\" href=\"#" + content.thumbId + "\" onclick=\"window.FilmTemplating.handleClose('" + content.key + "');\">Close<\/a>");
    document.write("  <div class=\"clear\"><\/div>");
    document.write("  <div class=\"filmContainer\">");
    document.write("    <video crossorigin=\"anonymous\" class=\"nodemand\" src=\"" + filmUrl + "\"><\/video>");
    document.write("    <div class=\"video-controller unselectable\" id=\"" + filmIdPrefix + "videoController\">");
    document.write("        <div id=\"" + filmIdPrefix + "playPauseBtn\" class=\"btn-play-pause\" title=\"Play\/Pause\">");
    document.write("            <span id=\"" + filmIdPrefix + "iconPlayPause\" class=\"icon-play\"><\/span>");
    document.write("        <\/div>");
    document.write("        <span id=\"" + filmIdPrefix + "videoTime\" class=\"time-display\">00:00:00<\/span>");
    document.write("        <div id=\"" + filmIdPrefix + "fullscreenBtn\" class=\"btn-fullscreen control-icon-layout\" title=\"Fullscreen\"> <span class=\"icon-fullscreen-enter\"><\/span>");
    document.write("        <\/div>");
    document.write("        <div id=\"" + filmIdPrefix + "bitrateListBtn\" class=\"control-icon-layout\" title=\"Bitrate List\">");
    document.write("            <span class=\"icon-bitrate\"><\/span>");
    document.write("        <\/div>");
    document.write("        <input type=\"range\" id=\"" + filmIdPrefix + "volumebar\" class=\"volumebar\" value=\"1\" min=\"0\" max=\"1\" step=\".01\"\/>");
    document.write("        <div id=\"" + filmIdPrefix + "muteBtn\" class=\"btn-mute control-icon-layout\" title=\"Mute\">");
    document.write("            <span id=\"" + filmIdPrefix + "iconMute\" class=\"icon-mute-off\"><\/span>");
    document.write("        <\/div>");
    document.write("        <div id=\"" + filmIdPrefix + "trackSwitchBtn\" class=\"control-icon-layout\" title=\"A\/V Tracks\">");
    document.write("            <span class=\"icon-tracks\"><\/span>");
    document.write("        <\/div>");
    document.write("        <div id=\"" + filmIdPrefix + "captionBtn\" class=\"btn-caption control-icon-layout\" title=\"Closed Caption\">");
    document.write("            <span class=\"icon-caption\"><\/span>");
    document.write("        <\/div>");
    document.write("        <span id=\"" + filmIdPrefix + "videoDuration\" class=\"duration-display\">00:00:00<\/span>");
    document.write("        <div class=\"seekContainer\">");
    document.write("            <input type=\"range\" id=\"" + filmIdPrefix + "seekbar\" value=\"0\" class=\"seekbar\" min=\"0\" step=\"0.01\"\/>");
    document.write("        <\/div>");
    document.write("    <\/div>");
    document.write("  <\/div>");
    document.write("  <div class=\"clear\"><\/div>");
    document.write("  <a class=\"articleClose\" href=\"#" + content.thumbId + "\" onclick=\"window.FilmTemplating.handleClose('" + content.key + "');\">Close<\/a>");
    document.write("<\/div>");

    setTimeout(function() {
      var contentRoot = document.getElementById(content.filmId);
      content.video = contentRoot.querySelector('video');
      content.contentRoot = contentRoot;
      contentRoot.querySelector('.filmContainer').insertAdjacentElement('afterend', extraContent);
      onHashChange();
    }, 0);
  }

  module.FilmTemplating = {
    'generateFilm': templateWriter,
    'handleClose': onCloseFilm,
  };
})(window);
