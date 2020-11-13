function VideoUtils-Edit-Rotate90
{
  param ($files);

  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }

    $ext = [System.IO.Path]::GetExtension($file);
    $tmp1 = [Guid]::NewGuid().ToString("N") + $ext;
    $tmp2 = [Guid]::NewGuid().ToString("N") + $ext;

# strip metadata rotation field which causes issues
    ffmpeg -i $file -c copy -metadata:s:v:0 rotate=0 $tmp1;
# rotate pixel matrix
    ffmpeg -i $tmp1 -vf transpose=1 $tmp2;

    rm $tmp1;
    mv $tmp2 $file;
  }
}

function VideoUtils-Concatenate-Merge {
  param ($filesIn, $fileOut);

  $guidFilename = [Guid]::NewGuid().ToString('N');
  $nl = [Environment]::NewLine;
  $outData = '';

  $last_md5 = $null;
  foreach ($file in $filesIn) {
    $fname = $file;
    if ($file.FullName) { $fname = $file.FullName; }

    $output = ffmpeg -nostats -hide_banner -i $fname -an -f framemd5 -c copy - 2>$null
    
    $tb_num = 1;
    $tb_den = 1;
    $inpoint = [decimal]0;
    $needsNextMd5 = $false;

    $lines = $output.Split("`n")

    foreach ($line in $lines ) {
      if ($line.StartsWith('#tb')) {
        $mt = $line | select-string '(\d+)\/(\d+)';
        $tb_num = [decimal]$mt.Matches.Groups[1].Value;
        $tb_den = [decimal]$mt.Matches.Groups[2].Value;
      }
      elseif (!$line.StartsWith('#')) {
        $mt = $line | select-string -Pattern '(?<=[ ]*)([0-9a-z]+)(?=,?)' -AllMatches;
        $md5 = $mt.Matches[-1].Value;
        $pts_time = [decimal]$mt.Matches[2].Value * $tb_num / $tb_den;

        if ($last_md5 -and $md5 -eq $last_md5) {
          $inpoint = $pts_time;
          $needsNextMd5 = $true;
        } elseif ($needsNextMd5) {
          $inpoint = $pts_time;
          $needsNextMd5 = $false;
        }
      }
    }
    $last_md5 = $md5;

    $outData += 'file ' + $fname + $nl;
    $outData += 'inpoint ' + $inpoint + $nl;
  }

  $outData | out-file $guidFilename;

  ffmpeg -hide_banner -nostats -f concat -safe 0 -i $guidFilename -c copy $fileOut 2>$null;

  rm $guidFilename;
}

function VideoUtils-Concatenate-Videos {
  param ($filesIn, $fileOut);

  $guidFilename = [Guid]::NewGuid().ToString('N');
  $filesIn = gci $filesIn;

  $filesIn | foreach-object { 'file ' + $_.FullName; } | out-file $guidFilename;

  ffmpeg -f concat -safe 0 -i $guidFilename -c copy $fileOut;

  rm $guidFilename;
}

function VideoUtils-Copy-Subsequence {
  param ($fileOut, $startTime, $endTime, $fileIn);

  $timePattern = '^([0-9]+:)?([0-9]+:)?[0-9]+$';
  if ($startTime -notmatch $timePattern) { throw 'Start time should be like 00:00:00'; }
  if ($endTime -notmatch $timePattern) { throw 'End time should be like 00:00:00'; }
  
  ffmpeg -ss $startTime -t $endTime -i $fileIn  -c copy  $fileOut
}

function VideoUtils-Preview-Colors {
  param ($brightness, $saturation, $contrast, $file, [Switch]$al);

  $args = '';
  $prefix = 'eq=';
  if ($al) {
    $args += 'pp=al';
    $prefix = ',eq=';
  }
  if ($brightness) {
    $args += $prefix + 'brightness=' + $brightness;
    $prefix = ':';
  }
  if ($saturation) {
    $args += $prefix + 'saturation=' + $saturation;
    $prefix = ':';
  }
  if ($contrast) {
    $args += $prefix + 'contrast=' + $contrast;
    $prefix = ':';
  }

  ffplay -vf $args $file;
}

function VideoUtils-Edit-Colors {
  param ($brightness, $saturation, $contrast, [Switch]$al, $file);

  $args = '';
  $prefix = 'eq=';
  if ($al) {
    $args += 'pp=al';
    $prefix = ',eq=';
  }
  if ($brightness) {
    $args += $prefix + 'brightness=' + $brightness;
    $prefix = ':';
  }
  if ($saturation) {
    $args += $prefix + 'saturation=' + $saturation;
    $prefix = ':';
  }
  if ($contrast) {
    $args += $prefix + 'contrast=' + $contrast;
    $prefix = ':';
  }

  $ext = [System.IO.Path]::GetExtension($file);
  $path = split-path -parent $file;
  $tmp1 = [Guid]::NewGuid().ToString("N") + $ext;
  $tmp1 = join-path $path $tmp1;

  ffmpeg -i $file -vf $args -c:a copy $tmp1;
  mv $tmp1 $file;
}

function VideoUtils-Edit-ColorsWithDefault {
  param ($files);

  foreach ($file in $files) {
    VideoUtils-Edit-Colors -brightness '0.16' -saturation 1.45 -contrast '1.4' -al -file $file;
  }
}
