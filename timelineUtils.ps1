
$script:DATEFORMATS = @(
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
      'dateFormat' = 'yyyy:MM:dd HH:mm:ss';
      'regex' = '\d\d\d\d:\d\d\:\d\d \d\d:\d\d:\d\d';
  },
  # 10 digit timestamps start at 09/09/2001 so any fairly recent timestamp will hit here
  # [DateTimeOffset]::FromUnixTimeSeconds('9'*9)
  @{
      'regex' = '-?\d{10,15}';
      'mode' = 'unixTimestamp';
  }
  @{
      'mode' = 'exifJpg';
      'regex' = '\.jpg$';
  },
  @{ 
      'dateFormat' = 'yyyyMMdd';
      'regex' = '\d\d\d\d\d\d\d\d';
  },
  @{
      'regex' = '-?\d{1,15}';
      'mode' = 'unixTimestamp';
  }
);
$script:MINYEAR = 1950;
$script:MAXYEAR = 3000;


function TimelineUtils-Timestamp-FindTimestamps($text, $maxCount = $null) {
  $opts = @();

  $matchGroups = @()

  $dfOrder = 0;
  foreach ($df in $script:DATEFORMATS) {
    $dfOrder++;
    if (!$df.regexCompiled) {
      $df.regexCompiled = [Regex]::New($df.regex, 'Compiled');
    }

    # sort matches in reverse order so when handling a full path name, we consider a date in the filename
    # before we worry about a date in the folder name
    $script:sortIdx = 0;
    $dates = $df.regexCompiled.Matches($text) | sort-object {$script:sortIdx--};

    $i = 0;
    foreach ($date in $dates) {
      $fpos = $text.Substring(0, $date.Index);
      $fpos = $fpos.Length - $fpos.Replace('/','').Length;

      $matchGroups += @{ 'date' = $date; 'df' = $df; 'idx' = $i; 'dfOrder' = $dfOrder; 'fpos'=$fpos; }
      $i += 1;
    }
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
      'exifJpg' {
        if (test-path $text) {
          $res = identify -format '%[EXIF:DateTimeOriginal]' $text;
          $parsed = [DateTime]::MinValue;
          if ([DateTime]::TryParseExact($res, 'yyyy:MM:dd HH:mm:ss', [CultureInfo]::InvariantCulture, 0, [ref]$parsed)) {
            $finalDate = $parsed;
          } else {
            $res = identify -format '%[EXIF:DateTime]' $text;
            $parsed = [DateTime]::MinValue;
            if ([DateTime]::TryParseExact($res, 'yyyy:MM:dd HH:mm:ss', [CultureInfo]::InvariantCulture, 0, [ref]$parsed)) {
              $finalDate = $parsed;
            } else {
              $res = identify -format '%[date:modify]' $text;
              $parsed = [DateTime]::MinValue;
              if ([DateTime]::TryParse($res, $null, 'RoundtripKind', [ref]$parsed)) {
                $finalDate = $parsed;
              }
            }
          }
        }
      }
      'unixTimestamp' {
        $dec = [decimal]0;
        if ([decimal]::TryParse($date.Value, [ref]$dec)) {
          if ($dec -ge -62135596800000 -and
              $dec -le 253402300799999) {
            $finalDate = [DateTimeOffset]::FromUnixTimeMilliseconds($date.Value).DateTime;
          }
        }
      }
      $null {
        $parsed = [DateTime]::MinValue;
        if ([DateTime]::TryParseExact($date.Value, $df.dateFormat, [CultureInfo]::InvariantCulture, 0, [ref]$parsed)) {
          $finalDate = $parsed;
        }
      }
    }

    if ($finalDate) {
      if ($finalDate.Year -gt ($script:MINYEAR) -and ($finalDate.Year) -lt ($script:MAXYEAR)) {
        $opts += $finalDate;
      }
    }
  }

  return $opts;
}

function TimelineUtils-Acquire-Timestamp($files) {
  $results = @();
  foreach ($file in $files) {
    if ($file.isTimelineFile) { $results += $file; continue; }

    $fname = $file;
    if ($file.FullName) {
      $fname = $file.FullName;
    }
    write-host ('Acquire timestamp ' + $fname);

    $timestamps = TimelineUtils-Timestamp-FindTimestamps $fname -MaxCount 1;
    $result = @{
      'FullName' = $fname;
      'filename' = TimelineUtils-Strip-PathPrefix $fname;
      'datetime' = $timestamps | select -First 1;
      'isTimelineFile' = $true;
      'generatedOn' = [DateTime]::Now;
    }
    $epoch = new-object DateTime @(1970,1,1);
    $result.filenameNoPath = split-path -leaf $fname;
    $result.datetimeJavascript = ($result.datetime - $epoch).TotalMilliseconds;

    if (!$result.datetime) {
      if (test-path $fname) {
        $result.datetime = (gci $file).CreationTime;
      }
    }
    $results += $result;
  }
  return $results;
}

$script:GROUP_DELTA_RANGE = [TimeSpan]::FromMinutes(45);

function TimelineUtils-Group-FilesByDate($files) {
  $res = TimelineUtils-Acquire-Timestamp $files | sort-object -descending { $_.datetime } | foreach-object {
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
  return $script:PATH_PREFIX;
}
function TimelineUtils-Strip-PathPrefix ($filename) {
  if ($filename.FullName) { $filename = $filename.FullName; }
  $idx = $filename.IndexOf($script:PATH_PREFIX);
  if ($idx -eq 0) {
    $filename = $filename.Substring($script:PATH_PREFIX.Length);
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
  switch ($ext) {
    { $_ -in @('.jpg','.png')} {
      $output = identify -verbose $file;
      $output = $output | Select-Object @{ Name = 'a'; Expression = {$_.ToString()} } | select-object -ExpandProperty 'a'
      $output = $output -join [environment]::NewLine;
      $result.identify = $output;
      $result.htmlTag = 'img';
      $result.extension = $ext;
      $result.orientation = $output | select-string -pattern '(?<=[^:]Orientation: )[A-Za-z0-9]*' | select-object -ExpandProperty Matches | select-object -first 1 | select-object -expandproperty Value;
      $result.geometry = $output | select-string -pattern '(?<=[^:]Geometry: )[A-Za-z0-9]*' | select-object -ExpandProperty Matches | select-object -first 1 | select-object -expandproperty Value;
      if ($result.geometry.IndexOf('x') -ne -1) {
        $result.width = $result.geometry.Substring(0, $result.geometry.IndexOf('x'));
        $result.height = $result.geometry.Substring($result.geometry.IndexOf('x')+1);
      }
    }
    { $_ -in @('.mp4','.avi') } {
      $output = (& ffprobe -hide_banner -of flat -i $file 2>&1);
      $output = $output | Select-Object @{ Name = 'a'; Expression = {$_.ToString()} } | select-object -ExpandProperty 'a'
      $output = $output -join [environment]::NewLine;
      $result.ffprobe = $output;
      $result.htmlTag = 'video';
      $result.width = $output | select-string -pattern '(?<=Video: ([^,]*,){2,3} )(\d+)(?=x\d+)'; 
      $result.width = $result.width.matches[0].value;
      $result.height = $output | select-string -pattern '(?<=Video: ([^,]*,){2,3} \d+x)(\d+)(?=[ ,])'; 
      $result.height = $result.height.matches[0].value;
    }
  }

  return $result;
}

function TimelineUtils-Attach-MetadataToFile {
  param ($file);

  if (!$file.isTimelineFile) {
    $file = TimelineUtils-Acquire-Timestamp $file;
  }
  $metadata = TimelineUtils-Collect-Metadata $file.FullName;
  foreach ($key in $metadata.keys) {
    if ($key -eq 'file') { continue; }
    $file[$key] = $metadata[$key];
  }

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
      New-Item -ItemType Directory -Force -Path $parentPath;
    }

    $metadataFname = $basePath + '.metadata.json';

    $sb = new-object System.Text.StringBuilder;

    $null = $sb.Append('{');
    $prefix = '"';
    foreach ($key in $file.Keys) {
      $null = $sb.Append($prefix);
      $null = $sb.Append([System.Web.HttpUtility]::JavaScriptStringEncode($key));
      $null = $sb.Append('":"');
      $null = $sb.Append([System.Web.HttpUtility]::JavaScriptStringEncode($file[$key]));
      $null = $sb.Append('"');

      $prefix = ',"';
    }
    $null = $sb.Append('}');
 
    $sb.ToString() | out-file $metadataFname;   
  }
}

function TimelineUtils-Generate-MetadataFilesFromGroups {
  param ($groups, $outPath = $null);
  
  foreach ($group in $groups) {
    TimelineUtils-Generate-MetadataFilesForFile $group.files $outPath;
  }
}

function TimelineUtils-Get-FilesNeedingMetadata {
  param ($path);

  $files = gci $path | where { !($_ -match '\.metadata(.[^.]*)?') } | where { !(test-path ($_.FullName + '.metadata.json')) };

  return TimelineUtils-Acquire-Timestamp $files; 
}
function TimelineUtils-Get-FilesWithMetadata {
  param ($path);

  $files = gci $path | where { !($_ -match '\.metadata(.[^.]*)?') } | where { (test-path ($_.FullName + '.metadata.json')) };

  return TimelineUtils-Acquire-Timestamp $files; 
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
    write-host ('file is: ' + $files[$i].FullName);
    $stripped = TimelineUtils-Strip-PathPrefix $files[$i];
    write-host ('stripped is: ' + $stripped);

    if ($index.ContainsKey($stripped)) {
      write-host ('Found ' + $stripped + 'in index');
      $files4 += $index[$stripped];
      continue;
    } else {
      write-host ('Missing ' + $stripped + 'in index');
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
  TimelineUtils-Generate-GroupsJson $groups $metadataPath;
  TimelineUtils-Generate-FileDateIndex $files4 $metadataPath;
}
