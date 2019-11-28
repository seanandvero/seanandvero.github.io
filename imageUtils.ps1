function ImageUtils-Generate-FolderName() {
  $res = $null;
  do {
    $guid = [Guid]::NewGuid().ToByteArray();
    $res = [Convert]::ToBase64String($guid, 0, 15);
  } while ($res.Contains('@') -or $res.Contains('+') -or $res.Contains('/'));
  return $res;
}

function ImageUtils-Rename-MessageFile($files) {
  $result = @();
  foreach ($file in $files) {
    $file = ImageUtils-Normalize-File $file;

    $fn = [System.IO.Path]::GetFilenameWithoutExtension($file);
    $parent = split-path -parent $file;
    $ext = [System.IO.Path]::GetExtension($file);
    if (!$fn.StartsWith('Message_')) { 
      $result += $file;
      continue; 
    }

    $nn = $fn.Substring('Message_'.Length);
    write-host 'nn1' $nn;
    $nn = [DateTimeOffset]::FromUnixTimeMilliseconds($nn).DateTime;
    write-host 'nn3' $nn;
    $nn = $nn.ToString('yyyyMMdd_HHmmss');
    write-host 'nn4' $nn;
    $suf = $ext;
    $cnt = 0;
    write-host 'suf' $suf;
    while (test-path ($nn + $suf)) {
      $cnt++;
      $suf = '' + $cnt + $ext;
      write-host 'suf' $suf;
    }

    $nn = $nn + $suf;
    write-host 'nnf' $nn;
    mv $file (join-path $parent $nn);
    $result += $nn;
  }
  return $result;
}

function ImageUtils-Edit-ApplyExif($files) {
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    mogrify -auto-orient $file;
  }
}
function ImageUtils-Edit-StripMeta($files) {
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    mogrify -strip $file;
  }
}
function ImageUtils-Edit-ApplyBlur($files) {
  $tmpFilename = [Guid]::NewGuid().ToString('N') + '.jpg';
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $dims = ImageUtils-Get-Dimensions $file;

    $off = @();
    foreach ($i in 1..4) {
      $offt = [decimal](Get-Random);
      $offt /= [decimal][int32]::MaxValue;

      $offt *= [decimal]0.35;

      if ((get-random -max 2 -min 0) -eq 0) {
        $offt = [decimal]1 - $oft - [decimal]0.15;
      } else {
        $offt += [decimal]0.15;
      }

      if ($i -eq 1 -or $i -eq 4) {
        $offt *= [decimal]$dims.width;
      } else {
        $offt *= [decimal]$dims.height;
      }

      $offt = $offt.ToString('F2');
      $off += $offt;
    }

    $color = @(1,0,0,0,1,0,0,0,1);
    foreach ($i in 0..8) {
      $color[$i] = [decimal]$color[$i];
      $colort = [decimal](Get-Random);
      $colort /= [decimal][int32]::MaxValue;
      $colort *= [decimal]0.5;

      if ($color[$i] -gt 0) {
        $color[$i] -= $colort;
      } else {
        $color[$i] += $colort;
      }

      $color[$i] = $color[$i].ToString('F2');
    }


    $bd1 = '0.0 0.0 0.0 1.0 0.0 0.0 0.75 0.75 ' + $off[0] +  ' 0.5';
    $bd2 = '0.0 0.0 0.0 1.0 0.0 0.0 0.5 0.5 0.5 ' + $off[1];
    $bd3 = '0.0 0.0 0.5 0.5 0.0 0.0 0 1.0 0.5 ' + $off[2];
    $bd4 = '0.0 0.0 0.75 0.75 0.0 0.0 0 1.0 ' + $off[3] + ' 0.5';

    $rcstr = '' + $color;
    #$rcstr = '1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0';

    convert $file -recolor $rcstr -resize 0.25% -resize 40000% -scale 4% -scale 2500%  -distort Barrel $bd1 -distort BarrelInverse $bd1 -distort Barrel $bd2 -distort BarrelInverse $bd2 -distort Barrel $bd3 -distort BarrelInverse $bd3 -distort Barrel $bd4 -distort BarrelInverse $bd4 $tmpFilename;
    mv $tmpFilename $file;
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

function ImageUtils-Edit-PreprocessForWebsite($files, [switch]$pBlur) {
  foreach ($file in $files) {
    if (!$file.FullName) {
      $file = gci $file;
    }
    $file = $file.FullName;

    $pwFile = $file + '.password.txt';
    if (test-path $pwFile) {
      $blur = $true;
    } else {
      $blur = $pBlur;
    }

    $filenameOnly = (split-path $file -leaf);
    $foldername = split-path -parent $file;
    $parent = split-path -parent $foldername;
    $fileNoExt = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly);
    $articleFolder = join-path $parent $fileNoExt;
    
    ImageUtils-Edit-ApplyExif $file;

    $articleRoot = $foldername;
    if ($blur) {
      $fnEnc = (ImageUtils-Generate-FolderName) + (ImageUtils-Generate-FolderName) + '_dec';
      $fnEnc = (join-path $foldername $fnEnc);
      mkdir $fnEnc;
      cp $file $fnEnc;
      $f2 = join-path $fnEnc $filenameOnly;
      
      ImageUtils-Generate-SrcSets $f2;
      ImageUtils-Edit-ApplyBlur $file;

      # blurred files have no metadata
      ImageUtils-Edit-StripMeta $file;

      $dfn = $file + '.description.txt';
      if (test-path $dfn) {
        mv $dfn $fnEnc;
      }
      $pfn = $file + '.password.txt';
      if (test-path $pfn) {
        mv $pfn $fnEnc;
      }

      $articleRoot = $fnEnc;
    }

    if (test-path $articleFolder) {
      $true | out-file (join-path $articleRoot ($filenameOnly + '.hasArticle.txt')) -NoNewline;

      $zips = (join-path $articleFolder '*.zip');
      if (test-path $zips) {
        foreach ($zip in $zips) {
          $zip = gci $zip;
          unzip $zip.FullName -d $articleFolder;
          rm $zip.FullName;
        }
      }

      $ais = gci -path (join-path $articleFolder '*.jpg') -recurse -force;
      $ams = gci -path (join-path $articleFolder '*.mp4') -recurse -force;

      $nais = @();
      foreach ($ai in $ais) {
        # +1 here is for the trailing '/' which is not present on articlefolder var
        $newPath = $ai.FullName.Substring($articleFolder.Length + 1);
        $newPath = join-path $articleRoot $newPath;

        $aparent = split-path -parent $newPath;
        if (!(test-path $aparent)) {
          new-item $aparent -itemtype directory;
        }

        cp $ai.FullName $newPath;
        $nais += (gci $newPath);
      }
      
      $nams = @();
      foreach ($am in $ams) {
        # +1 here is for the trailing '/' which is not present on articlefolder var
        $newPath = $am.FullName.Substring($articleFolder.Length + 1);
        $newPath = join-path $articleRoot $newPath;

        $aparent = split-path -parent $newPath;
        if (!(test-path $aparent)) {
          new-item $aparent -itemtype directory;
        }

        cp $am.FullName $newPath;
        $nams += (gci $newPath);
      }

      ImageUtils-Edit-ApplyExif $nais;
      ImageUtils-Generate-Srcsets $nais;

      $articleGallery = $nais + $nams;
      $articleGallery += gci (join-path $articleRoot $filenameOnly);

      $articleGallery = $articleGallery | sort-object;
      $galleryHtml = ImageUtils-Generate-GalleryHtml $articleGallery;
      $galleryFilename = (ImageUtils-Get-GalleryFilename $articleRoot);
      $galleryHtml | Out-File $galleryFilename;

      $articleHtml = ImageUtils-Generate-GalleryArticleHtml $galleryFilename; 
      $articleFilename = (ImageUtils-Get-GalleryFilename $articleRoot -name 'article.html');
      $articleHtml | out-file $articleFilename;
    }

    ImageUtils-Generate-Srcsets $file;
  }
}

<# This function is only really useful prior to the imageutils-edit-preprocessForWebsite command runs #>
function ImageUtils-Assign-ArticleFolder($files) {
  foreach ($file in $files) {
    $file = ImageUtils-Normalize-File $file;

    $filenameOnly = (split-path $file -leaf);
    $foldername = split-path -parent $file;
    $fileNoExt = [System.IO.Path]::GetFileNameWithoutExtension($filenameOnly);
    $articleFolder = join-path $foldername $fileNoExt;
 
    if (!(test-path $articleFolder)) {   
      mkdir $articleFolder;
    }
  }
}

function ImageUtils-Assign-Description($files, [Parameter(Mandatory=$true)][string]$description) {
  ImageUtils-Describe-File -files $files -description $description;
}

function ImageUtils-Describe-File($files, [Parameter(Mandatory=$true)][string]$description) {
  $files = ImageUtils-Filter-Srcsets $files;
  foreach ($file in $files) {
    if ($file.FullName) { $file = $file.FullName; }
  
    $dfn = $file + '.description.txt';

    $description | out-file $dfn -NoNewline;
  }
}

function ImageUtils-Assign-Password($files, [Parameter(Mandatory=$true)][string]$password) {
  $files = ImageUtils-Filter-Srcsets $files;
  $result = @();
  foreach ($file in $files) {
    if ($file.FullName) { $file = $file.FullName; }
 
    $pfn = $file + '.password.txt'; 

    $password | out-file $pfn -NoNewline;

    $result += @($file, $pfn);
  }
  return $result;
}

function ImageUtils-Partition-IntoFolders($files) {
  $results = @();
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $foldername = ImageUtils-Generate-FolderName;
    $foldername = join-path (split-path $file -parent) $foldername;

    mkdir $foldername;
    cp $file $foldername;

    $results += (join-path $foldername (split-path -leaf $file));

    $dfn = ($file + '.description.txt');
    if (test-path $dfn) {
      cp $dfn $foldername;
    }

    $pfn = ($file + '.password.txt');
    if (test-path $pfn) {
      cp $pfn $foldername;
    }
  }

  return $results;
}

function ImageUtils-Get-Dimensions($files) {
  $result = @();
  foreach ($file in $files) {
    if ($file.FullName) { $file = $file.FullName; }

    $x = &identify -verbose $file | where {$_.Contains('Geometry:')};
    if (($x | measure).Count -ne 1) { 
      throw ('Unable to find dimensions for file ' + $file);
    }

    $idx1 = $x.IndexOf('Geometry: ') + 'Geometry: '.Length;
    $idx2 = $x.IndexOf('x');
    $idx3 = $x.IndexOf('+');
    
    $width = [int]$x.Substring($idx1, $idx2 - $idx1);
    $height = [int]$x.Substring($idx2 + 1, $idx3 - $idx2 - 1);

    $result += @{ 'width' = $width; 'height' = $height; };
  }
  return $result;
}

function ImageUtils-Set-RootUrl {
  param ($rootUrl);

  $global:ImageUtils_RootUrl = $rootUrl;
}

function ImageUtils-Get-RootUrl {
  param ($rootUrl);

  if (!$rootUrl) {
    $rootUrl = $global:ImageUtils_RootUrl;
  }

  if (!$rootUrl) {
    throw 'Root url not defined';
  }

  if ($rootUrl.EndsWith('/')) {
    $rootUrl = $rootUrl.Substring(0, $rootUrl.Length-1);
  }
  
  return $rootUrl;
}

function ImageUtils-Generate-GridLinkHtml($files, [string]$rootUrl) {
  $files = ImageUtils-Filter-Srcsets $files;
  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $result = '<!-- grid generated ' + [DateTime]::Now.ToString('u') + ' -->';
  $result += [Environment]::Newline;
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $foldername = split-path -leaf (split-path -parent $file);
   
    $result += '<link rel="prefetch" class="demand" crossorigin="anonymous" type="text/html" href="';
    $result += $rootUrl + '/' + $foldername + '/grid.html';
    $result += '" />';
    $result += [Environment]::Newline;
  }
  $result += '<!-- end grid generation ' + [DateTime]::Now.ToString('u') + ' -->';
  $result += [Environment]::Newline;

  return $result;
}

function ImageUtils-Get-GridMultiplier($files) {
  $result = @();
  $epsilon = [decimal]0.95;
  foreach ($file in $files) {
    $size = ImageUtils-Get-Dimensions $file;
    $mult = 2;
    if ($size.height * $epsilon -gt $size.width) {
      $mult = 1;
    }
    $result += $mult;
  }
  return $mult;
}

function ImageUtils-Normalize-File($file) {
  return (gci $file).FullName;
}

function ImageUtils-Generate-IndexHtml($files) {
  $indexHtml = '<!-- Generated On ' + ([DateTime]::Now).ToString() + ' -->';
  $gridCount = -1;
  $articles = @();

  $renderCurrentArticles = {
    param ($articles);

    if (($articles | measure).count -le 0) { return; }

    $indexHtml = '';
    $controlHtml = '';
    $contentHtml = '';
    $articleId = 1;
    foreach ($article in $articles) {
      $intermediate = ImageUtils-Generate-ArticleData $article -articleIdInRow ($articleId++);
      $controlHtml += $intermediate.controlHtml;
      $contentHtml += $intermediate.contentHtml;
    }
    $indexHtml += $controlHtml;
    $indexHtml += $contentHtml;

    return $indexHtml;
  };

  foreach ($file in $files) {
    $file = ImageUtils-Normalize-File $file;

    $gridMult = ImageUtils-Get-GridMultiplier $file;
    $oldRow = [Math]::Truncate($gridCount / 6);
    $gridCount += $gridMult;
    $newRow = [Math]::Truncate($gridCount / 6);
    if ($oldRow -lt $newRow) {
      $indexHtml += (& $renderCurrentArticles $articles);
      $articles = @();
    }

    $gridData = ImageUtils-Generate-GridData $file
    $indexHtml += $gridData.gridHtml;

    if ($gridData.hasArticle) {
      $articles += $file;
    }
  }
  $indexHtml += (& $renderCurrentArticles $articles);
  $articles = @();

  $indexHtml += '<!-- End Generated On ' + ([DateTime]::Now).ToString() + ' -->';

  return $indexHtml;
}

<# This is a legacy function which returns grid html data without performing other precedent or subsequent steps
   involved in generating the state of the art code #>
function ImageUtils-Generate-GridHtml($files, $description, $password, [switch]$withArticle, [string]$rootUrl) {
  $results = ImageUtils-Generate-GridData @args;
  $result = '';
  foreach ($data in $results) {
    $result += $data.gridHtml;
  }
  return $result;
}

function ImageUtils-Generate-GridData($files, $pDescription, $pPassword, [switch]$pWithArticle, [string]$rootUrl) {
  $thumbSuffix = '_640';
  $files = ImageUtils-Filter-Srcsets $files;

  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $epsilon = [decimal]0.95;
  $result = @();
  
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
   
    $filename = split-path -leaf $file;
    $decFolder = gci (split-path -parent $file) -attributes Directory | where {$_.Name.EndsWith('_dec')};
    if (($decFolder|measure).Count -eq 1) {
      $decFile = join-path $decFolder.FullName $filename;
      $propFile = $decFile;
    } else {
      $propFile = $file;
    }

    if (test-path ($propFile + '.description.txt')) {
      $description = [System.IO.File]::ReadAllText($propFile + '.description.txt');
    } else {
      $description = $pDescription;
    }
    if (test-path ($propFile + '.password.txt')) {
      $password = [System.IO.File]::ReadAllText($propFile + '.password.txt');
    } else {
      $password = $pPassword;
    }
    if (test-path ($propFile + '.hasArticle.txt')) {
      $withArticle = $true;
    } else {
      $withArticle = $pWithArticle;
    }

    if (!$description) {
      $description = 'todo: description';
    }
    $parentFolder = ImageUtils-Get-SubdirForRoot $file;
    $id = 'gh_' + (ImageUtils-Get-SubdirNoDecryption $parentFolder);

    $size = ImageUtils-Get-Dimensions $file;
    $class = 'u-med-1-3';
    if ($size.height * $epsilon -gt $size.width) {
      $class = 'u-med-1-6';
    }

    $gridHtml = '';

    $gridHtml += '<div class="photo-box u-1 ' + $class + '">';
    if ($withArticle) {
      $gridHtml += '<label class="article" onclick="" for="' + $id + '">';
    }

    $thumb = [System.IO.Path]::GetFileNameWithoutExtension($filename);
    $thumb += $thumbSuffix + [System.IO.Path]::GetExtension($filename);
    $gridHtml += '<img src="' + $rootUrl + '/' + $parentFolder + '/' + $thumb + '"';

    if ($password) {
      $gridHtml += ' alt="hidden" ';

      if (($decFolder|measure).Count -ne 1) {
        throw ('Unable to resolve decrypted image folder for file ' + $file);
      }

      $attrName = ImageUtils-Generate-EncryptionAttribute $password;
      $gridHtml += $attrName + '-alt="';
      $gridHtml += ImageUtils-Encrypt-AttributeValue $password $description;
      $gridHtml += '" ';

      $decUrl = $rootUrl + '/' + $parentFolder + '/' + $decFolder.Name + '/' + $thumb;
      $gridHtml += $attrName + '-src="';
      $gridHtml += ImageUtils-Encrypt-AttributeValue $password $decUrl;
      $gridHtml += '"';
    } else {
      $gridHtml += ' alt="' + $description + '"';
    }

    $gridHtml += '/>';
    if ($withArticle) {
      $gridHtml += '</label>';
    }
    $gridHtml += '</div>';

    $result += @{
      'gridHtml' = $gridHtml;
      'hasArticle' = $withArticle;
    };
  }

  return $result;
}

function ImageUtils-Get-EncryptedFile ($files) {
  $result = @();
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    
    $filename = split-path -leaf $file;
    $folder = split-path -parent (split-path -parent $file);

    $result += join-path $folder $filename;
  }
  return $result;
}

function ImageUtils-Get-DecryptedFile ($files) {
  $result = @();
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $parent = split-path -parent $file;
    $filename = split-path -leaf $file;

    $decFolder = gci $parent -attributes Directory | where {$_.Name.EndsWith('_dec')}
    if (($decFolder|measure).Count -ne 1) {
      throw ('Unable to resolve decrypted image folder for file ' + $file);
    }

    $result += join-path $decFolder.FullName $filename;
  }
  return $result;
}

function ImageUtils-Get-SubdirForRoot ($path) {
  if ($path.FullName) {
    $path = $path.FullName;
  }

  $result = $null;
  do {
    $path = split-path -parent $path;
    $leaf = split-path -leaf $path;
    if ($result) {
      $result = join-path $leaf $result;
    } else {
      $result = $leaf;
    }
  } while ($path.EndsWith('_dec'));

  return $result;
}
function ImageUtils-Get-SubdirNoDecryption ($path) {
  if ($path.FullName) {
    $path = $path.FullName;
  }
  while ($path.EndsWith('_dec')) {
    $path = split-path -parent $path;
  }
  return $path;
}

<#
  This function is a legacy function for generating 'dumb' article html and should be avoided,
  manual editing would be required here (reordering controls and changing articleState class numbers),
  to generate 'state-of-the-art' html content
#>
function ImageUtils-Generate-ArticleHtml {
  $intermediate = ImageUtils-Generate-ArticleData @args;

  $resultHtml = '';
  foreach ($result in $intermediate) {
    $resultHtml += $result.controlHtml + $result.contentHtml;
  }
  return $resultHtml;
}

function ImageUtils-Generate-ArticleData($files, $password, [string]$rootUrl, [int]$articleIdInRow=1) {
  $files = ImageUtils-Filter-Srcsets $files;
  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $epsilon = [decimal]0.95;
  $result = @();
  
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
   
    $parentFolder = ImageUtils-Get-SubdirForRoot $file;
    $filename = split-path -leaf $file;
    $id = 'gh_' + (ImageUtils-Get-SubdirNoDecryption $parentFolder);

    $decFolder = gci $parentFolder -attributes Directory | where {$_.Name.EndsWith('_dec')}
    if (($decFolder|measure).Count -eq 1) {
      $propFile = join-path $decFolder $filename;
    } else {
      $propFile = $file;
    }

    if (test-path ($propFile + '.password.txt')) {
      $password = [System.IO.File]::ReadAllText($propFile + '.password.txt');
    }

    $controlHtml = '';
    $contentHtml = '';

    $controlHtml += '<input type="radio" name="article" id="' + $id + '" class="articleState' + $articleIdInRow + '" />';
    $contentHtml += '<div class="text-box u-1 full-row article">';
    $contentHtml += '<label class="articleClose" for="closeArticle">Close</label>';
    $contentHtml += '<div class="clear"></div>';
    $contentHtml += '<link rel="prefetch" class="demand" type="text/html" crossorigin="anonymous" ';
    if ($password) {
      $contentHtml += 'href="encrypted_placeholder.html" ';

      if (($decFolder|measure).Count -ne 1) {
        throw ('Unable to resolve decrypted image folder for file ' + $file);
      }
      $decUrl = $rootUrl + '/' + $parentFolder + '/' + $decFolder.Name + '/article.html';
      
      $attrName = ImageUtils-Generate-EncryptionAttribute $password;
      $contentHtml += $attrName + '-href="';
      $contentHtml += ImageUtils-Encrypt-AttributeValue $password $decUrl;
      $contentHtml += '"';
    } else {
      $contentHtml += 'href="' + $rootUrl + '/' + $parentFolder + '/' + 'article.html"';
    }
    $contentHtml += '/>';

    $contentHtml += '<div class="clear"></div>';
    $contentHtml += '<label class="articleClose" for="closeArticle">Close</label>';
    $contentHtml += '</div>';

    $result += @{
      'controlHtml' = $controlHtml;
      'contentHtml' = $contentHtml;
    };
  }

  return $result;
}

function ImageUtils-Get-GalleryFiles($path) {
  if (!(test-path $path -PathType Container)) {
    $path = split-path -parent $path;
  }

  return (gci (join-path $path '*.jpg')) + (gci (join-path $path '*.mp4'));
}
function ImageUtils-Get-GalleryFilename($path, $name) {
  if (!$name) {
    $name = 'gallery.html';
  }
  if (!(test-path $path -PathType Container)) {
    $path = split-path -parent $path;
  }

  return (join-path $path $name);
}

function ImageUtils-Generate-GalleryHtml($files, [string]$rootUrl) {
  $thumbSuffix = '_640';
  $files = ImageUtils-Filter-Srcsets $files;
  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $id_base = 'pv_' + (ImageUtils-Generate-FolderName);
  $result = '';
  $result += '<html><body>';
  $result += '<div class="masonflex" id="' + $id_base + '">';
  $idx = 0;
  $max = ($files | measure).Count;
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $parentFolder = ImageUtils-Get-SubdirForRoot $file;
    $filename = split-path -leaf $file;
    $thumb = [System.IO.Path]::GetFileNameWithoutExtension($filename);
    $extension = [System.IO.Path]::GetExtension($filename);
    $thumb += $thumbSuffix + $extension;

    $result += '<div class="masonflex-panel photoCollage">';

    if ($extension -eq '.mp4') {
      $result += '<video controls="controls" crossorigin="anonymous" src="' + $rootUrl + '/' + $parentFolder + '/' + $filename  + '"></video>';
    } else {
      $idx += 1;
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

      $result += '<img class="pure-img" src="' + $rootUrl + '/' + $parentFolder + '/' + $filename  + '" />'
      $result += '</div></div>';

      $result += '<label class="photoViewer" onclick="" for="' + $id_base + '_view_' + $idx + '">';
      $result += '<img class="pure-img" src="' + $rootUrl + '/' + $parentFolder + '/' + $thumb + '"></img>';
      $result += '</label>';
    }
    $result += '</div>';
  }

  $result += '</div>';
  $result += '<script type="text/javascript">';
  $result += 'var ele = document.getElementById("' + $id_base + '");';
  $result += 'var mf = new MasonFlex(ele, {})';
  $result += '</script>';
  $result += '</body>';
  $result += '</html>';

  return $result;
}

function ImageUtils-Generate-GalleryArticleHtml($files) {
  $result = '<html><body>';
  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;
  foreach ($file in $files) {
    $file = ImageUtils-Normalize-File $file;

    $parentFolder = split-path -parent $file;
    $encryptedRoot = split-path -parent (ImageUtils-Get-SubdirNoDecryption $parentFolder);
    $urlPath = $file.Substring($encryptedRoot.Length + 1);
    
    $url = $rootUrl + '/' + $urlPath;
    $result += '<link rel="prefetch" class="demand" crossorigin="anonymous" type="text/html" href="' + $url + '" />';
  }
  $result += '</body></html>';
  return $result;
}

function ImageUtils-Encrypt-AttributeValue ($password, $value) {
  $res = ImageUtils-Encrypt-AES256CBC $password $value;
  $res = ImageUtils-Encode-Attr32 $res;
  return $res;
}

function ImageUtils-Encode-Attr32([byte[]]$data) {
  $result = '';
  foreach ($byte in $data) {
    $byte = [byte]$byte;
    $result += $byte.ToString("x2");
  }
  return $result;
}

function ImageUtils-Generate-EncryptionAttribute($password)
{
  if ($password.password) {
    $password = $password.password;
  }

  $res = ImageUtils-Encrypt-AES256CBC $password $password -noiv;
  $res = ImageUtils-Hash-SHA256 $res

  return 'data-enc-' + (ImageUtils-Encode-Attr32 $res);
}

function ImageUtils-Hash-SHA256([byte[]]$data) {
  $hasher = [System.Security.Cryptography.SHA256]::Create();
  return $hasher.ComputeHash($data);
}

function ImageUtils-Encrypt-AES256CBC([string]$password, [string]$data, [switch]$noiv) {
  $key = ([System.Text.Encoding]::UTF8.GetBytes($password))

  foreach ($i in 1..20000) {
    $key = ImageUtils-Hash-SHA256 $key
  }

  $aes = [System.Security.Cryptography.Aes]::Create()
  $oldIv = $aes.IV
  $iv = [byte[]]@(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  $aes.IV = $iv
  $aes.Key = $key;
  $encryptor = $aes.CreateEncryptor($aes.Key, $aes.IV)
  $ms = new-object System.IO.MemoryStream
  $cs = new-object System.Security.Cryptography.CryptoStream @($ms, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
  $sw = new-object System.IO.StreamWriter $cs
  if (!$noiv) {
    $oldIvString = ([Convert]::ToBase64String($oldIv))
    $sw.Write($oldIvString);
  }
  $sw.Write($data);
  $sw.Flush()
  $sw.Dispose();
  $encryptedBytes = $ms.ToArray()
  return $encryptedBytes;
}

function ImageUtils-Append-PasswordMap
{
  param ($file, $account, $password);

  $map = ImageUtils-Generate-PasswordMap $account $password;

  $map | out-file $file -append;
}

function ImageUtils-Generate-PasswordMap
{
  param ($account, $password);

  if ($password.password) {
    $password = $password.password;
  }

  $res2 = ImageUtils-Encrypt-AES256CBC $account $password;
  $res = ImageUtils-Encrypt-AES256CBC $account $account -noiv;
  $res = ImageUtils-Hash-SHA256 $res

  $password = (ImageUtils-Encode-Attr32 $res2);
  $account = (ImageUtils-Encode-Attr32 $res);

  $res = 'cml.registerPassword("' + $account + '", "' + $password + '");';
  
  return $res;
}

function ImageUtils-Batch-Pipeline
{
  param ($files);

  $parts = ImageUtils-Partition-IntoFolders $files;
  ImageUtils-Edit-PreprocessForWebsite $parts;

  $parts2 = $parts | sort-object { split-path -leaf $_; } -Descending;

  ImageUtils-Generate-IndexHtml $parts2 | out-file 'index.html';

  return $parts2;
}
