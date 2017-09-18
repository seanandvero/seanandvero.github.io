#!/bin/bash

SUBPATH_SMALL="../final_thumb"
for f in *.JPG;
do
  filename=`basename "$f"`
  fnoext=`basename "$f" .JPG`

  echo ... converting $filename to $fnoext.png
  convert $filename  -resize '200x200>' -background none -gravity center -extent 200x200 $SUBPATH_SMALL/$fnoext.png
done
