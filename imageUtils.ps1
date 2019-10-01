function ImageUtils-Generate-FolderName() {
  $res = $null;
  do {
    $guid = [Guid]::NewGuid().ToByteArray();
    $res = [Convert]::ToBase64String($guid, 0, 15);
  } while ($res.Contains('@') -or $res.Contains('+') -or $res.Contains('/'));
  return $res;
}

function ImageUtils-Edit-ApplyExif($files) {
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    mogrify -auto-orient $file;
  }
}

function ImageUtils-Filter-Srcsets ($files) {
  if (!$files) { return $null; }

  $result = @();
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $dir = [System.IO.Path]::GetDirectoryName($file);
    $ext = [System.IO.Path]::GetExtension($file);
    $rootName = [System.IO.Path]::GetFilenameWithoutExtension($file);
    $len = $null;
    if ($rootName.EndsWith('_2048')) {$len=5;}
    if ($rootName.EndsWith('_1024')) {$len=5;}
    if ($rootName.EndsWith('_640')) {$len=4;}
    if ($rootName.EndsWith('_480')) {$len=4;}
    if ($rootName.EndsWith('_320')) {$len=4;}
    if ($rootName.EndsWith('_240')) {$len=4;}
    if ($rootName.EndsWith('_160')) {$len=4;}
    if ($rootName.EndsWith('_80')) {$len=3;}
    if ($len) { $rootName = $rootName.Substring(0, $rootName.Length - $len); }
    $rootName = join-path $dir ($rootName + $ext);

    if ($rootName -ne $file -and (test-path $rootName)) {
      continue;
    }
    
    $result += (gci $rootName);
  }
  return $result;
}

function ImageUtils-Generate-Srcsets($files) {
  if (!$files) { return; }
  # Maybe add a switch to disable but in general you wouldn't want to double generate
  $files = ImageUtils-Filter-Srcsets $files;

  foreach ($file in $files) { 
    if ($file.FullName) {
      $file = $file.FullName;
    }

    $ne = join-path (split-path $file -parent) ([System.IO.Path]::GetFileNameWithoutExtension( (split-path $file -leaf) ));

    $srcSets = @(
      @{ p=($ne+'_2048.jpg');r='2048x2048';}, 
      @{ p=($ne+'_1024.jpg');r='1024x1024';}, 
      @{ p=($ne+'_640.jpg');r='640x640';}, 
      @{ p=($ne+'_320.jpg');r='320x320';}, 
      @{ p=($ne+'_240.jpg');r='240x240';}, 
      @{ p=($ne+'_160.jpg');r='160x160';}, 
      @{ p=($ne+'_80.jpg');r='80x80';}
    );

    foreach ($srcset in $srcSets) {
      if (!(test-path $srcset.p)) {
        convert $file -resize $srcset.r $srcset.p;
      }
    }
  }
}

function ImageUtils-Partition-IntoFolders($files) {
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $foldername = ImageUtils-Generate-FolderName;
    $foldername = join-path (split-path $file -parent) $foldername;
    mkdir $foldername;
    cp $file $foldername;
    $file = join-path $foldername (split-path $file -leaf);
    
    ImageUtils-Edit-ApplyExif $file;
    ImageUtils-Generate-Srcsets $file;
  }
}

function ImageUtils-Generate-GalleryHtml([string]$rootUrl, [string]$thumbSuffix, $files) {
  $files = ImageUtils-Filter-Srcsets $files;

  if ($rootUrl.EndsWith('/')) {
    $rootUrl = $rootUrl.Substring(0, $rootUrl.Length-1);
  }

  $id_base = 'pv_' + (ImageUtils-Generate-FolderName);
  $result = '';
  $result += '<html><body>';
  $result += '<div class="masonflex" id="' + $id_base + '">';
  $idx = 0;
  $max = ($files | measure).Count;
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.Name;
    }
    $idx += 1;
    $result += '<div class="masonflex-panel photoCollage">';
    $result += '<div class="photoViewerDialog">';
    $result += '<input type="radio" name="' + $id_base + '" id="' + $id_base + '_close_' + $idx + '" class="photoViewer" />';
    $result += '<input type="radio" name="' + $id_base + '" id="' + $id_base + '_view_' + $idx + '" class="photoViewer" />';
    $result += '<div class="photoViewer">';
    if ($idx -gt 1) {
      $result += '<label for="' + $id_base + '_view_' + ($idx-1) + '">';
      $result += '<div class="prev"></div>';
      $result += '</label>';
    }
    if ($idx -lt $max) {
      $result += '<label for="' + $id_base + '_view_' + ($idx+1) + '">';
      $result += '<div class="next"></div>';
      $result += '</label>';
    }
    $result += '<label for="' + $id_base + '_close_' + ($idx) + '">';
    $result += '<div class="close"></div>';
    $result += '</label>';

    $result += '<img class="pure-img" src="' + $rootUrl + '/' + $file  + '" />'
    $result += '</div></div>';

    $result += '<label class="photoViewer" onclick="" for="' + $id_base + '_view_' + $idx + '">';
    $thumb = [System.IO.Path]::GetFileNameWithoutExtension($file);
    $thumb += $thumbSuffix + [System.IO.Path]::GetExtension($file);
    $result += '<img class="pure-img" src="' + $rootUrl + '/' + $thumb + '"></img>';
    $result += '</label></div>';
  }

  $result += '</div>';
  $result += '<script type="text/javascript">';
  $result += 'var ele = document.getElementById("' + $id_base + '");';
  $result += 'var mf = new MasonFlex(ele, {})';
  $result += '</script>';

  return $result;
}
