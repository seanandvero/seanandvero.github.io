function VideoUtils-Edit-Rotate90
{
  param ($files);

  foreach ($file in $files) {
    if ($file.FullName) {
      $file = $file.FullName;
    }

    $ext = [System.IO.Path]::GetExtension($file);
    $tmp1 = [Guid]::NewGuid.ToString("N") + '.' + $ext;
    $tmp2 = [Guid]::NewGuid.ToString("N") + '.' + $ext;

# strip metadata rotation field which causes issues
    ffmpeg -i $file -c copy -metadata:s:v:0 rotate=0 $tmp1;
# rotate pixel matrix
    ffmpeg -i $tmp1 -vf transpose=1 $tmp2;

    rm $tmp1;
    mv $tmp1 $file;
  }
}

function VideoUtils-Copy-Subsequence {
  param ($fileOut, $startTime, $endTime, $fileIn);

  $timePattern = '^([0-9]+:)?([0-9]+:)?[0-9]+$';
  if ($startTime -notmatch $timePattern) { throw 'Start time should be like 00:00:00'; }
  if ($endTime -notmatch $timePattern) { throw 'End time should be like 00:00:00'; }
  
  ffmpeg -ss $startTime -t $endTime -i $fileIn  -c copy  $fileOut
}
