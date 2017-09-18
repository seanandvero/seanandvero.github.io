#!/bin/bash

for f in *.JPG;
do
  filename=`basename "$f"`
  fnoext=`basename "$f" .JPG`

  url=`dropbox_uploader.sh share wedding/$filename | sed 's/^.*\(http.*\)$/\1/g'`

  echo $filename $url >> wedding_final_shares.txt
done
