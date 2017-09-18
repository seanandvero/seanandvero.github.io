#!/bin/bash

for f in *.png;
do
  fnoext=`basename "$f" .png`
  name="$fnoext"_thumb.png
  dropbox_uploader.sh upload $f wedding/$name
  url=`dropbox_uploader.sh share wedding/$name | sed 's/^.*\(http.*\)$/\1/g'`

  echo thumb "$fnoext".JPG $url >> wedding_final_thumb_shares.txt
done
