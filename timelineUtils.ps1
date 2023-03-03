function TimelineUtils-Get-GroupDeltaRange {
  return [TimeSpan]::FromMinutes(45);
}

function TimelineUtils-Get-DateFormats 
{
  return @(
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.ffffff';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d\d\d\d\d';
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.fffff';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d\d\d\d';
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.ffff';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d\d\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.fff';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.ff';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss.f';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd.HHmmss';
        'regex' = '\d\d\d\d\d\d\d\d\.\d\d\d\d\d\d';
    },
    @{ 
        'dateFormat' = 'yyyy:MM:dd HH:mm:sszzz';
        'regex' = '\d\d\d\d:\d\d:\d\d\s*\d\d:\d\d:\d\d[+-]\d\d:\d\d';
    },
    @{ 
        'dateFormat' = 'yyyy:MM:dd HH:mm:sszz';
        'regex' = '\d\d\d\d:\d\d:\d\d\s*\d\d:\d\d:\d\d[+-]\d\d';
    },
    @{ 
        'dateFormat' = 'yyyy:MM:dd HH:mm:ssz';
        'regex' = '\d\d\d\d:\d\d:\d\d\s*\d\d:\d\d:\d\d[+-]\d?\d';
    },
    @{ 
        'dateFormat' = 'yyyy:MM:dd HH:mm:ss';
        'regex' = '\d\d\d\d:\d\d:\d\d\s*\d\d:\d\d:\d\d';
    },
    # oukitel wp 13
    @{ 
        'dateFormat' = 'yyyyMMdd_HHmmss';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d\.\d\d\d\d\d\d';
    },
    # skydio drone
    @{ 
        'dateFormat' = 'yyyyMMddHHmmss';
        'regex' = '\d\d\d\d\d\d\d\d\d\d\d\d\d\d';
    },
    # 10 digit timestamps start at 09/09/2001 so any fairly recent timestamp will hit here
    # [DateTimeOffset]::FromUnixTimeSeconds('9'*9)
    @{
        'regex' = '-?\d{10,15}';
        'mode' = 'unixTimestamp';
        'belowExif' = $true;
    },
    # samsung screenshots
    @{ 
        'dateFormat' = 'yyyyMMdd-HHmmss';
        'regex' = '\d\d\d\d\d\d\d\d_\d\d\d\d\d\d'
    },
    @{ 
        'dateFormat' = 'yyyyMMdd';
        'regex' = '\d\d\d\d\d\d\d\d';
        'belowExif' = $true;
    },
    @{
        'regex' = '-?\d{1,15}';
        'mode' = 'unixTimestamp';
        'belowExif' = $true;
    }
  );
}
function TimelineUtils-Get-MinYear {
  return ([DateTime]::Now).AddYears(-70).Year;
}
function TimelineUtils-Get-MaxYear {
  return ([DateTime]::Now).AddYears(2).Year;
}
function TimelineUtils-Get-ExifIndex {
  $dateFormats = TimelineUtils-Get-DateFormats;
# calculate the place in the date formats ordering where exif data should start going
  for ($EXIFINDEX = 0; $EXIFINDEX -lt $dateFormats.Length; $EXIFINDEX++) {
    if ($dateFormats[$EXIFINDEX].belowExif) { break; }
  }
  return $EXIFINDEX;
}

function TimelineUtils-TryParse-Timestamp($text) {
  $dateFormats = TimelineUtils-Get-DateFormats;
  foreach ($df in $dateFormats) {
    if (!$df.dateFormat) { continue; }
    if (!$df.regexCompiled) {
      $df.regexCompiled = [Regex]::New($df.regex, 'Compiled');
    }

    # sort matches in reverse order so when handling a full path name, we consider a date in the filename
    # before we worry about a date in the folder name
    $sortIdx = 0;
    $dates = $df.regexCompiled.Matches($text) | sort-object {$sortIdx--};

    $result = [ref]([DateTime]::MinValue);
    $i = 0;
    foreach ($date in $dates) {
      if ([DateTime]::TryParseExact($date.Value, $df.dateFormat, $null, ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AllowWhiteSpaces), $result)) { 
          return $result; 
      }
    }
  }
  return $false;
}

function TimelineUtils-Timestamp-FindTimestamps($text, $maxCount = $null, $exifTooldata=$null, $magickData=$null) {
  $opts = @();
  $dateFormats = TimelineUtils-Get-DateFormats;
  $matchGroups = @()

  if ($text) {
    $dfOrder = 0;
    foreach ($df in $dateFormats) {
      $dfOrder++;
      if (!$df.regexCompiled) {
        $df.regexCompiled = [Regex]::New($df.regex, 'Compiled');
      }

      # sort matches in reverse order so when handling a full path name, we consider a date in the filename
      # before we worry about a date in the folder name
      $sortIdx = 0;
      $dates = $df.regexCompiled.Matches($text) | sort-object {$sortIdx--};

      $i = 0;
      foreach ($date in $dates) {
        $fpos = $text.Substring(0, $date.Index);
        $fpos = $fpos.Length - $fpos.Replace('/','').Length;

        $matchGroups += @{ 'date' = $date; 'df' = $df; 'idx' = $i; 'dfOrder' = $dfOrder; 'fpos'=$fpos; }
        $i += 1;
      }
    }
  }

  if ($exifTooldata) {
    $exifData = $exifTooldata;
    $exifFields = @(
      @{ 'fieldName' = 'DateTimeOriginal'; }, 
      @{ 'fieldName' = 'MediaCreateDate'; }, 
      @{ 'fieldName' = 'OriginalCreateDateTime'; }, 
      @{ 'fieldName' = 'TrackCreateDate'; }, 
      @{ 'fieldName' = 'CreateDate'; }, 
      @{ 'fieldName' = 'CreationTime'; }, 
      @{ 'fieldName' = 'DateCreated'; }, 
      @{ 'fieldName' = 'DigitalCreationDate'; }, 
      @{ 'fieldName' = 'DateTime'; }, 
      @{ 'fieldName' = 'CreationDate'; }, 
      @{ 'fieldName' = 'OriginalDate'; }, 
      @{ 'fieldName' = 'ShotDate'; }, 
      @{ 'fieldName' = 'When'; }, 
      @{ 'fieldName' = 'DataCreateDate'; }, 
      @{ 'fieldName' = 'CameraDateTime'; }, 
      @{ 'fieldName' = 'ModifyDate'; }, 
      @{ 'fieldName' = 'MediaModifyDate'; }, 
      @{ 'fieldName' = 'TrackModifyDate'; }, 
      @{ 'fieldName' = 'GPSDateStamp'; }, 
      @{ 'fieldName' = 'GPSDateTime'; }, 
      @{ 'fieldName' = 'FileModifyDate'; }, 
      @{ 'fieldName' = 'ModDate'; }, 
      @{ 'fieldName' = 'DataModifyDate'; }, 
      @{ 'fieldName' = 'DateSent'; }, 
      @{ 'fieldName' = 'ReferenceDate'; }, 
      @{ 'fieldName' = 'ReleaseDate'; }, 
      @{ 'fieldName' = 'DateTimeDigitized'; }
    );
   
   for ($i = 0; $i -lt $exifFields.Length; $i++) {
     $field = $exifFields[$i].fieldName;
     if (!$exifData.$field) { continue; }

      $val = $exifData.$field;

      $valDate = TimelineUtils-TryParse-Timestamp $val;
      if (!$valDate) {
        write-warning ('unable to parse exif date ' + $field + ' with value ' + $val + ' for text ' + $text);
        continue;
      }

      if ($valDate.Value) { $valDate = $valDate.Value; }

      $matchGroups += @{ 'date' = $valDate; 'df' = @{ 'mode' = 'parsed'; }; 'dfOrder' = (TimelineUtils-Get-ExifIndex); 'idx' = $i; 'fpos' = 1; };
   }
  } else {
    # exiftool gives us stuff for almost every file so maybe its worthwhile to warn here instead of verbose?
    write-warning ('no exif tool data for text ' + $text + ', skipping exiftool date extraction.');
  }

  if ($magickData) {
    $magickFields = @(
      @{ 'fieldName' = 'exif:DateTimeOriginal'; }, 
      @{ 'fieldName' = 'exif:DateTime'; }, 
      @{ 'fieldName' = 'date:create'; }, 
      @{ 'fieldName' = 'date:modify'; }
    );
   
   for ($i = 0; $i -lt $exifFields.Length; $i++) {
     $field = $exifFields[$i].fieldName;
     if (!$exifData.$field) { continue; }

      $val = $exifData.$field;

      $valDate = TimelineUtils-TryParse-Timestamp $val;
      if (!$valDate) {
        write-warning ('unable to parse magick date ' + $field + ' with value ' + $val + ' for text ' + $text);
        continue;
      }
      if ($valDate.Value) { $valDate = $valDate.Value; }

      $matchGroups += @{ 'date' = $valDate; 'df' = @{ 'mode' = 'parsed'; }; 'dfOrder' = (TimelineUtils-Get-ExifIndex); 'idx' = $i; 'fpos' = 1; };
   }
  } else {
    write-verbose ('no imagemagick data for text ' + $text + ', skipping imagemagick date extraction.');
  }

  # sort matches in reverse order by where they appeared in the textet- resolve ties by
  # taking the date format group that appeared first in the list
  $matchGroups = $matchGroups | sort-object { -$_.fpos }, { $_.dfOrder }, { -$_.date.Length };

  foreach ($match in $matchGroups) {
    if ($maxCount) {
      if (($opts | measure-object).Count -ge $maxCount) {
        break;
      }
    }

    $df = $match.df;
    $date = $match.date;
    $finalDate = $null;
    switch ($df.mode) {
      'unixTimestamp' {
        $dec = [decimal]0;
        if ([decimal]::TryParse($date.Value, [ref]$dec)) {
          if ($dec -ge -62135596800000 -and
              $dec -le 253402300799999) {
            $finalDate = [DateTimeOffset]::FromUnixTimeMilliseconds($date.Value).DateTime;
          }
        }
      }
      'parsed' {
        $finalDate = $date;
      }
      $null {
        $parsed = [DateTime]::MinValue;
        if ([DateTime]::TryParseExact($date.Value, $df.dateFormat, [CultureInfo]::InvariantCulture, 0, [ref]$parsed)) {
          $finalDate = $parsed;
        }
      }
    }

    if ($finalDate) {
      if ($finalDate.Year -gt (TimelineUtils-Get-MinYear) -and ($finalDate.Year) -lt (TimelineUtils-Get-MaxYear)) {
        $opts += $finalDate;
      }
    }
  }

  return $opts;
}

function TimelineUtils-New-FileObject($fname) {
  if ($fname.FullName) {
    $fname = $fname.FullName;
  }

  $result = @{
    'FullName' = $fname;
    'filename' = TimelineUtils-Strip-PathPrefix $fname;
    'isTimelineFile' = $true;
    'generatedOn' = [DateTime]::Now;
  }
  $result.filenameNoPath = split-path -leaf $fname;
  return $result;
}

function TimelineUtils-Acquire-Timestamp($file) {
  if (!$file.isTimelineFile) {
    throw 'acquire timestamp expects existing timeline file as argument, try calling TimelineUtils-Attach-MetadataToFile instead';
  } else {
    write-verbose 'take collected metadata and try to make an educated guess abotu the files creation date';
  }

  $fname = $file.FullName;
  write-host ('Acquire timestamp ' + $fname);
  $exifToolData = $file.exifTool;
  $magickData = $file.magickJson;

  $timestamps = TimelineUtils-Timestamp-FindTimestamps $fname -exifTooldata $exifToolData -magickData $magickData;

  $file.allTimestamps = $timestamps;
  $file.datetime = $timestamps | select -first 1;
  $epoch = new-object DateTime @(1970,1,1);
  $file.datetimeJavascript = ($file.datetime - $epoch).TotalMilliseconds;

  if (!$file.datetime) {
    if (test-path $fname) {
      write-warning ('extracting timestamp from file ' + $fname + ' failed, using create date as fallback');
      $file.datetime = (gci $fname).CreationTime;
      $file.isFallbackDate = $true;
    }
  }

  return $file;
}


function TimelineUtils-Group-FilesByDate($files) {
  $res = $files | sort-object -descending { $_.datetime } | foreach-object {
    $lastDate = [DateTime]::MaxValue;
    $currentGroup = @();
    $groups = @();
    $range= [TimeSpan]::FromMinutes(45);
    $groupid = 0;
  } {
    if ($lastDate - $_.datetime -gt $range) {
      if (($currentGroup | measure).Count -gt 0) {
        $groups += @{
          'id' = $groupid++;
          'files' = $currentGroup;
        }
      }
      $currentGroup = @();
    }

    $currentGroup += $_;
    $lastDate = $_.datetime;
  } {
    if (($currentGroup | measure).Count -gt 0) {
        $groups += @{
          'id' = $groupid++;
          'files' = $currentGroup;
        }
    }

    return $groups;
  }
  return $res;
}

$script:PATH_PREFIX = $null;
function TimelineUtils-Configure-PathPrefix ($prefix) {
  if (!$prefix.EndsWith('/')) {
    $prefix += '/';
  }
  $script:PATH_PREFIX = $prefix;
}
function TimelineUtils-Get-PathPrefix () {
  if (!$script:PATH_PREFIX) {
    throw 'Path prefix is not defined';
  }

  return $script:PATH_PREFIX;
}
function TimelineUtils-Strip-PathPrefix ($filename) {
  $pp = (TimelineUtils-Get-PathPrefix);

  if ($filename.FullName) { $filename = $filename.FullName; }
  $idx = $filename.IndexOf($pp);
  if ($idx -eq 0) {
    $filename = $filename.Substring($pp.Length);
  }
  return $filename;
}

function TimelineUtils-Collect-Metadata {
  param ($file);

  $result = @{
    'file' = $file;
  }
  if ($file.FullName) {
    $file = $file.FullName;
  }

  $item = Get-Item $file;
  $result.size = $item.Length;

  $ext = [System.IO.Path]::GetExtension($file);
  $result.extension = $ext;

  $result.isImage = $isImage = [bool](& mediainfo --Inform="Image;%Format%" $file);
  $result.isVideo = $isVideo = [bool](& mediainfo --Inform="Video;%Format%" $file);

    # we want to skip running image magick on files we know are videos
  if ($isImage) {
    $result.htmlTag= 'img';
    $magickData = (convert $file json: 2>$null) | convertfrom-json;
    if ($magickData) {
      $magickData = $magickData.image;
      $result.magickJson = $magickData;

      # preserving this for legacy 
      $output = identify -verbose $file;
      $output = $output | Select-Object @{ Name = 'a'; Expression = {$_.ToString()} } | select-object -ExpandProperty 'a'
      $output = $output -join [environment]::NewLine;

      $result.orientation = $magickData.Orientation;
      $result.identify = $output;
      $result.htmlTag = 'img'; # as far as i know imagemagick does not support anything but images
      $result.geometry = '' + $magickData.Geometry.Width + 'x' + $magickData.Geometry.Height + '+' + $magickData.Geometry.x + '+' + $magickData.Geometry.y;
      $result.width = $magickData.Geometry.Width;
      $result.height = $magickData.Geometry.Height;
    }
  }

  $exifToolData = exiftool -json $file | convertfrom-json;
  if ($exifToolData) {
    $result.exifTool = $exifToolData;
  }

  if ($isVideo) {
    $result.htmlTag = 'video';

    $output = (& ffprobe -hide_banner -of flat -i $file 2>&1);
    $output = $output | Select-Object @{ Name = 'a'; Expression = {$_.ToString()} } | select-object -ExpandProperty 'a'
    $output = $output -join [environment]::NewLine;

    $json = (& ffprobe -hide_banner -print_format json -show_format -show_streams -show_versions $file 2>$null) | convertfrom-json;

    $result.ffprobe = $output;
    $result.width = $json.streams.width;
    $result.height = $json.streams.height;
    $result.ffprobeJson = $json;
  }

  return $result;
}

function TimelineUtils-Attach-MetadataToFile {
  param ($file);

  $file = TimelineUtils-New-FileObject $file;
  $metadata = TimelineUtils-Collect-Metadata $file.FullName;
  foreach ($key in $metadata.keys) {
    if ($key -eq 'file') { continue; }
    $file[$key] = $metadata[$key];
  }
  $file = TimelineUtils-Acquire-Timestamp $file;

  return $file;
}

function TimelineUtils-Attach-MetadataToFiles {
  param ($files);

  $result = @();
  foreach ($file in $files) {
    $result += TimelineUtils-Attach-MetadataToFile $file;
  }
  return $result;
}

function TimelineUtils-Attach-MetadataToGroups {
  param ($groups);

  foreach ($group in $groups) {
    foreach ($file in $group.files) {
      TimelineUtils-Attach-MetadataToFile $file;
    }
  }
}

function TimelineUtils-Generate-MetadataFilesForFile {
  param ($files, $outPath = $null);

  Add-Type -AssemblyName System.Web

  if ($outPath -and !$script:PATH_PREFIX) { 
    throw 'Path PREFIX must be set to use outPath';
  }

  foreach ($file in $files) {
    if (!$file.isTimelineFile) {
      write-warning 'skipping file in unexpected format: ' $file;
      continue;
    }

    $basePath = $file.FullName;
    if ($outPath) {
      $basePath = join-path $outPath (TimelineUtils-Strip-PathPrefix $file.FullName);
    }

    $parentPath = split-path -parent $basePath;
    if (!(Test-Path $parentPath -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $parentPath | out-null;
    }
    $metadataParentPath = TimelineUtils-Strip-PathPrefix $parentPath;

    if ($file.isVideo -and !($file.videoPreviews)) {
      try {
        $previews = VideoUtils-Generate-WebPreviews $file.FullName -outPath (pwd).Path
        $previews.original = (TimelineUtils-Strip-PathPrefix $file.FullName);
        if ($previews.webmPreview) {
          move-item $previews.webmPreview $parentPath;
          $previews.webmPreview = join-path $metadataParentPath (split-path -leaf $previews.webmPreview);
        }
        if ($previews.mp4Preview) {
          move-item $previews.mp4Preview $parentPath;
          $previews.mp4Preview = join-path $metadataParentPath (split-path -leaf $previews.mp4Preview);
        }
        $file.videoPreviews = $previews;
      } catch {
        $_;
        write-warning ('failure while generating web previews for ' + $file.FullName);
      }
    }

    $metadataFname = $basePath + '.metadata.json';

    TimelineUtils-Serialize-Metadata $file | out-file $metadataFname;
  }
}

function TimelineUtils-Serialize-Metadata
{
  param ($metadata);
  $sb = new-object System.Text.StringBuilder;

  $null = $sb.Append('{');
  $prefix = '"';
  foreach ($key in $metadata.Keys) {
    write-debug ('key: ' + $key)
    $value = $metadata[$key];
    if (!$value) { continue; }

    $keyJson = [System.Web.HttpUtility]::JavaScriptStringEncode($key);
    $valueJson = $value | convertto-json -depth 5;

    write-debug ('value: ' + $valueJson);

    $null = $sb.Append($prefix);
    $null = $sb.Append($keyJson);
    $null = $sb.Append('":');
    $null = $sb.Append($valueJson);

    $prefix = ',"';
  }
  $null = $sb.Append('}');

  return $sb.ToString();   
}

function TimelineUtils-Generate-MetadataFilesFromGroups {
  param ($groups, $outPath = $null);
  
  foreach ($group in $groups) {
    TimelineUtils-Generate-MetadataFilesForFile $group.files $outPath;
  }
}

function TimelineUtils-Get-MetadataPathForFile {
  param ($file, $metadataPath);

  $metaPath = TimelineUtils-Strip-PathPrefix $file;
  $metaPath = join-path $metadataPath $metaPath;
  $metaPath += '.metadata.json';

  return $metaPath;
}
function TimelineUtils-Get-FilesNeedingMetadata {
  param ($path, $metadataPath);

  $files = gci $path | where { !($_.Name -match '\.metadata(.[^.]*)?') } | where { !(test-path (TimelineUtils-Get-MetadataPathForFile $_.FullName $metadataPath)) };

  return $files;
}
function TimelineUtils-Get-FilesWithMetadata {
  param ($path);

  $files = gci $path | where { !($_.Name -match '\.metadata(.[^.]*)?') } | where { (test-path (TimelineUtils-Get-MetadataPathForFile $_.FullName $metadataPath)) };

  return $files | % { TimelineUtils-Attach-MetadataToFile $_; };
}

function TimelineUtils-Merge-Files {
  $result = @();

  foreach ($arg in $args) {
    foreach ($file in $arg) {
      $result += $file;
    }
  }
}

function TimelineUtils-Generate-GroupsJson {
  param ($groups, $outPath, $idx=1);

  Add-Type -AssemblyName System.Web

  $res = new-object System.Text.StringBuilder;
  $null = $res.Append('[');
  $groupPrefix = '';
  $remaining = @();
  $epoch = new-object DateTime @(1970,1,1);

  foreach ($group in $groups) {
    if ($res.Length -gt 1024000) {
      $remaining += $group;
      continue;
    }

    $minDate = $null; $maxDate = $null;

    $null = $res.Append($groupPrefix);
    $null = $res.Append('{"id":');
    $null = $res.Append($group.id);
    $null = $res.Append(',"files":[');
    $filePrefix = '"';
    foreach ($file in $group.files) {
      if (!$minDate -or $file.datetime -lt $minDate) {
        $minDate = $file.datetime;
      }
      if (!$maxDate -or $file.datetime -gt $maxDate) {
        $maxDate = $file.datetime;
      }

      $null = $res.Append($filePrefix);
      $null = $res.Append([System.Web.HttpUtility]::JavaScriptStringEncode($file.filename));
      $null = $res.Append('"');
      $filePrefix = ',"';
    }
    $null = $res.Append('],"minDate":"');
    $null = $res.Append(([long]($minDate - $epoch).TotalMilliseconds));
    $null = $res.Append('","maxDate":"');
    $null = $res.Append(([long]($maxDate - $epoch).TotalMilliseconds));
    $null = $res.Append('"}');
    $groupPrefix = ',';
  }
  $null = $res.Append(']');

  $res.ToString() | out-file (join-path $outPath ('timeline.groups.' + $idx + '.json'));

  if ($remaining) {
    TimelineUtils-Generate-GroupsJson $remaining $outPath ($idx+1);
  } else {
    $idx | out-file (join-path $outPath ('timeline.groups.max'));
  }
}

function TimelineUtils-Generate-FileDateIndex {
  param ($files, $outPath, $idx = 1);

  $res = new-object System.Text.StringBuilder;
  $null = $res.Append('{');
  $prefix = '';
  $remaining = @();
  foreach ($file in $files) {
    if ($res.Length -gt 1024000) {
      $remaining += $file;
      continue;
    }
    $null = $res.Append($prefix);
    $null = $res.Append('"');
    $null = $res.Append([System.Web.HttpUtility]::JavaScriptStringEncode($file.filename));
    $null = $res.Append('":{"filename":"');
    $null = $res.Append([System.Web.HttpUtility]::JavaScriptStringEncode($file.filename));
    $null = $res.Append('","datetime":"');
    $null = $res.Append([System.Web.HttpUtility]::JavaScriptStringEncode($file.datetime.ToString('o')));
    $null = $res.Append('","isTimelineFile":true}');
    $prefix = ',';
  }
  $null = $res.Append('}');

  $res.ToString() | out-file (join-path $outPath ('timeline.filedateindex.' + $idx + '.json'));

  if ($remaining) {
    TimelineUtils-Generate-FileDateIndex $remaining $outPath ($idx+1);
  } else {
    $idx | out-file (join-path $outPath 'timeline.filedateindex.max');
  }
}

function TimelienUtils-Test-ForFileDateIndex
{
  param ($metadataPath);

  $fname = join-path $metadataPath 'timeline.filedateindex.max';
  if (!(test-path $fname)) {
    throw ('Unable to locate timelien.filedateindex.max at location: ' + $metadataPath);
  }
}
function TimelineUtils-Load-FileDateIndex 
{
  param ($metadataPath);

  $fname = join-path $metadataPath 'timeline.filedateindex.max';
  if (!(test-path $fname)) {
    throw ('Unable to locate timelien.filedateindex.max at location: ' + $metadataPath);
  }

  $count = [decimal](get-content $fname);

  $result = @{};
  for ($i = 1; $i -le $count; $i++) {
    $fname = 'timeline.filedateindex.' + $i + '.json';
    $fname = join-path $metadataPath $fname;
    $index = get-content $fname | convertfrom-json;
    
    foreach ($prop in $index.psobject.properties) {
      $result[$prop.Name] = $prop.Value;
    }
  }

  return $result;
}

function TimelineUtils-Batch-GenerateMetadata {
  param ($prefixPath, $searchPath, $metadataPath, $batchCount=100);

  TimelineUtils-Configure-PathPrefix $prefixPath;
  $index = TimelineUtils-Load-FileDateIndex $metadataPath;
  $files = gci -path $searchPath -recurse -file;

  $files4 = @();
  $files2 = @();
  for ($i = 0; $i -lt $files.length; $i++) {
    write-debug ('file is: ' + $files[$i].FullName);
    $stripped = TimelineUtils-Strip-PathPrefix $files[$i];
    write-debug ('stripped is: ' + $stripped);

    if ($index.ContainsKey($stripped)) {
      write-debug ('Found ' + $stripped + ' in index');
      $files4 += $index[$stripped];
      continue;
    } else {
      write-host ('Missing ' + $stripped + ' in index');
    }

    $files2 += $files[$i];
    if ($files2.length -ge $batchCount) {
      $files3 = TimelineUtils-Attach-MetadataToFiles $files2;
      TimelineUtils-Generate-MetadataFilesForFile $files3 $metadataPath;
      foreach ($f in $files3) {
        $files4 += $f;
      }
      $files2 = @();
    }
  }
  if ($files2.length -gt 0) {
    $files3 = TimelineUtils-Attach-MetadataToFiles $files2;
    TimelineUtils-Generate-MetadataFilesForFile $files3 $metadataPath;
    foreach ($f in $files3) {
      $files4 += $f;
    }
    $files2 = @();
  }

  $groups = TimelineUtils-Group-FilesByDate $files4;

  write-host 'after this point the new index will be written to disk';

  TimelineUtils-Generate-GroupsJson $groups $metadataPath;
  TimelineUtils-Generate-FileDateIndex $files4 $metadataPath;
}

function TimelineUtils-Sync-FromDropboxToS3()
{
  param ($dropboxPath, $wasabiPath, [switch]$pretend);

  if (!$env:RCLONE_CONFIG_PASS) {
    throw 'you must set $env:RCLONE_CONFIG_PASS to run this command';
  }

  $tmpFilename = ([Guid]::NewGuid().ToString('N')) + '_' + ([DateTime]::Now.ToString('yyyyMMdd_HH_mm_ss'));
  $diffFilename = $tmpFilename + '.diff.rclone.txt';
  $errorFilename = $tmpFilename + '.error.rclone.txt';
  $missingFilename = $tmpFilename + '.missing.rclone.txt';

  & rclone check $dropboxPath $wasabiPath --differ $diffFilename --one-way --error $errorFilename --missing-on-dst $missingFilename;

  $files = get-content $missingFilename;
  $throttleLimit = 5;
  
  $files | % {
    $dropboxSrcPath = $dropboxPath + $_;
    $rcloneDestPath = $wasabiPath + $_;

    start-threadjob -throttleLimit $throttleLimit -ArgumentList $pretend,$dropboxSrcPath,$rcloneDestPath {
      param ($pretend, $dropboxSrcPath, $rcloneDestPath);

      if ($pretend) {
        write-host "rclone copyto $dropboxSrcPath $rcloneDestPath -P";
      } else {
        rclone copyto $dropboxSrcPath $rcloneDestPath -P;
      }
    }
  } | receive-job -wait -autoremovejob;
}

function TimelineUtils-Sync-FromGoProPlusToS3() {
  param ($goProSettings, $wasabiPath, [switch]$pretend, $tmpPath = $null);

  if (!$tmpPath) {
    $tmpPath = (pwd).Path;
  }
  if (!(test-path -PathType Container -Path $tmpPath)) {
    throw ('TmpPath does not exist at :' + $tmpPath);
  }

  $goProAuth = GoProPlus-Authenticate $goProSettings.username $goProSettings.password;
  $files = GoProPlus-ListAllFiles $goProAuth;

  foreach ($file in $files) {
    $file | add-member -type noteproperty -name 'downloaded_at' -value ([DateTime]::Now);

    $goProMeta = 'goProPlus.' + $file.id + '.goProPlus.json';
    $metaFile = (join-path $wasabiPath $goProMeta);

    if (test-path $metaFile) {
      # basic assumption that if the meta file has been created then the download was completed succesfully
      # but there are some other considerations that could be made like file changes / moments being recorded
      continue;
    }

    $dl2 = GoProPlus-Download2 $goProAuth $file;
    $extension = GoProPlus-GetExtensionFromDownload2 $dl2; # extension includes the '.'
    $origPrefix = 'captured_at_';
    if ($dl2.filename) {
      $origPrefix = [System.IO.Path]::GetFileNameWithoutExtension($dl2.filename) + '_at_';
    }
    if (!$file.captured_at) {
      write-warning 'unable to retrieve captured at for file ' + $file.id;
      continue;
    }
    $targetFilename = 'goProPlus.' + $file.id + '.' + $origPrefix + $file.captured_at.ToString('yyyyMMdd_hhmmss') + $extension;

    write-verbose ('Begin download for ' + $targetFilename)
    $dlResult = GoProPlus-Download -AppAuthToken $goProauth -download2 $dl2 -outputFileName (join-path $tmpPath $targetFilename);
    $file | convertto-json -depth 8 | out-file (join-path $tmpPath $goProMeta);

    move-item (join-path $tmpPath $targetFilename) (join-path $wasabiPath $targetFilename) -Verbose;
    move-item (join-path $tmpPath $goProMeta) (join-path $wasabiPath $goProMeta) -Verbose;
  }
}
function TimelineUtils-Regenerate-MetadataForFiles 
{
  param ($files, $outPath);

  foreach ($file in $files) { 
    if ($file.FullName) {
      $file = $file.FullName;
    }
    $targetFile = join-path (TimelineUtils-Get-PathPrefix) $file; 
    write-host 'target file' $targetFile; 
    $metadataFile = TimelineUtils-Get-MetadataPathForFile $targetFile $outPath; 
    write-host 'destination metadata file ' $metadataFile; 
    if (test-path $metadataFile) { 
      write-warning ('skipping metadata generation for file ' + $metadataFile + ' because it already exists');
      continue; 
    }
    $metadata = TimelineUtils-Attach-MetadataToFile $targetFile; 
    TimelineUtils-Generate-MetadataFilesForFile $metadata $outPath; 
  }
}
