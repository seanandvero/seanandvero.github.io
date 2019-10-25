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

function ImageUtils-Edit-PreprocessForWebsite($files, [switch]$blur) {
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $filenameOnly = (split-path $file -leaf);
    $foldername = split-path -parent $file;
    $file = join-path $foldername $filenameOnly;
    
    ImageUtils-Edit-ApplyExif $file;

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

      $dfn = split-path -leaf $file;
      $dfn += '.description.txt';
      $dfn = join-path $foldername $dfn;
      if (test-path $dfn) {
        mv $dfn $fnEnc;
      }
    }

    ImageUtils-Generate-Srcsets $file;
  }
}

function ImageUtils-Describe-File($files, $description) {
  $files = ImageUtils-Filter-Srcsets $files;
  foreach ($file in $files) {
    if ($file.FullName) { $file = $file.FullName; }
  
    $folder = split-path -parent $file;
    $fn = split-path -leaf $file;
    $fn = $fn + '.description.txt';
    $fn = join-path $folder $fn;

    $description | out-file $fn -NoNewline;
  }
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

function ImageUtils-Generate-GridHtml($files, $description, $password, [switch]$withArticle, [string]$rootUrl) {
  $thumbSuffix = '_640';
  $files = ImageUtils-Filter-Srcsets $files;

  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $epsilon = [decimal]0.95;
  $result = '';
  
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
   
    if (test-path ($file + '.description.txt')) {
      $description = [System.IO.File]::ReadAllText($file + '.description.txt');
    }
    if (!$description) {
      $description = 'todo: description';
    }
    $parentFolder = split-path -leaf (split-path -parent $file);
    $filename = split-path -leaf $file;
    $id = 'gh_' + $parentFolder;

    $size = ImageUtils-Get-Dimensions $file;
    $class = 'u-med-1-3';
    if ($size.height * $epsilon -gt $size.width) {
      $class = 'u-med-1-6';
    }

    $result += '<div class="photo-box u-1 ' + $class + '">';
    if ($withArticle) {
      $result += '<label class="article" onclick="" for="' + $id + '">';
    }

    $thumb = [System.IO.Path]::GetFileNameWithoutExtension($filename);
    $thumb += $thumbSuffix + [System.IO.Path]::GetExtension($filename);
    $result += '<img src="' + $rootUrl + '/' + $parentFolder + '/' + $thumb + '"';

    if ($password) {
      $result += ' alt="hidden" ';


      $decFolder = gci (split-path -parent $file) -attributes Directory | where {$_.Name.EndsWith('_dec')}
      if (($decFolder|measure).Count -ne 1) {
        throw ('Unable to resolve decrypted image folder for file ' + $file);
      }

      $decFile = join-path $decFolder.FullName $filename;
      if (test-path ($decFile + '.description.txt')) {
        $description = [System.IO.File]::ReadAllText($decFile + '.description.txt');
      }
      if (!$description) {
        $description = 'todo: description';
      }

      $attrName = ImageUtils-Generate-EncryptionAttribute $password;
      $result += $attrName + '-alt="';
      $result += ImageUtils-Encrypt-AttributeValue $password $description;
      $result += '" ';

      $decUrl = $rootUrl + '/' + $parentFolder + '/' + $decFolder.Name + '/' + $thumb;
      $result += $attrName + '-src="';
      $result += ImageUtils-Encrypt-AttributeValue $password $decUrl;
      $result += '"';
    } else {
      $result += ' alt="' + $description + '"';
    }

    $result += '/>';
    if ($withArticle) {
      $result += '</label>';
    }
    $result += '</div>';
  }

  return $result;
}

function ImageUtils-Generate-ArticleHtml($files, $password, [string]$rootUrl) {
  $files = ImageUtils-Filter-Srcsets $files;
  $rootUrl = ImageUtils-Get-RootUrl $rootUrl;

  $epsilon = [decimal]0.95;
  $result = '';
  
  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }
   
    $parentFolder = split-path -leaf (split-path -parent $file);
    $filename = split-path -leaf $file;
    $id = 'gh_' + $parentFolder;

    $result += '<input type="radio" name="article" id="' + $id + '" class="articleState1" />';
    $result += '<div class="text-box u-1 full-row article">';
    $result += '<label class="articleClose" for="closeArticle">Close</label>';
    $result += '<div class="clear"></div>';
    $result += '<link rel="prefetch" class="demand" type="text/html" crossorigin="anonymous" ';
    if ($password) {
      $result += 'href="encrypted_placeholder.html" ';

      $decFolder = gci (split-path -parent $file) -attributes Directory | where {$_.Name.EndsWith('_dec')}
      if (($decFolder|measure).Count -ne 1) {
        throw ('Unable to resolve decrypted image folder for file ' + $file);
      }
      $decUrl = $rootUrl + '/' + $parentFolder + '/' + $decFolder.Name + '/article.html';
      
      $attrName = ImageUtils-Generate-EncryptionAttribute $password;
      $result += $attrName + '-href="';
      $result += ImageUtils-Encrypt-AttributeValue $password $decUrl;
      $result += '"';
    } else {
      $result += 'href="' + $rootUrl + '/' + $parentFolder + '/' + 'article.html"';
    }
    $result += '/>';

    $result += '<div class="clear"></div>';
    $result += '<label class="articleClose" for="closeArticle">Close</label>';
    $result += '</div>';
  }

  return $result;
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
  $result += '</body>';
  $result += '</html>';

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
