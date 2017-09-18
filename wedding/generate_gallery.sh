#!/bin/bash

OF="gallery_generated.html"

echo "<div class=\"root\">" > $OF

TOTAL=`ls *.JPG|wc -l`
SUBPATH="wedding/final"
SUBPATH_SMALL="wedding/final_thumb"
let "index=1"
viewers=""
while read p; 
do
  name=`echo $p |sed 's/^\(.*JPG\)\( http.*\)\(http.*\)$/\1/g'`
  full=`echo $p |sed 's/^\(.*JPG\)\( http.*\)\(http.*\)$/\2/g'`
  thumb=`echo $p |sed 's/^\(.*JPG\)\( http.*\)\(http.*\)$/\3/g'`

  ds="data-src"
  let "prev=index-1"
  let "next=index+1"

  echo "    <div class=\"photo-box u-1 u-med-1-3 u-lrg-1-6\">" >> $OF
  echo "      <label class=\"photoViewer\" onclick=\"\" for=\"photoViewer_wedding_$index\">" >> $OF
  echo "        <img src=\"dashinfinity.svg\" $ds=\"$thumb\">" >> $OF
  echo "        </img>" >> $OF
  echo "      </label>" >> $OF
  echo "    </div>" >> $OF

  viewers+=`echo "    <input type=\"radio\" name=\"photoViewer\" id=\"photoViewer_wedding_$index\" class=\"photoViewer\" />"`
  viewers+=`echo "    <div class=\"photoViewer\">"`
  if [ $index != "1" ]; then
    viewers+=`echo "      <label for=\"photoViewer_wedding_$prev\"><div class=\"prev\"></div></label>"`
  fi
  if [ $index != "$TOTAL" ]; then
    viewers+=`echo "      <label for=\"photoViewer_wedding_$next\"><div class=\"next\"></div></label>"`
  fi
  viewers+=`echo "      <label for=\"photoViewer_wedding_none\"><div class=\"close\"></div></label>"`
  viewers+=`echo "      <img src="dashinfinity.svg" $ds=\"$full\" />"`
  viewers+=`echo "    </div>"`

  if ! ((index%6)); then
    echo $viewers >> $OF
    viewers=""
  fi

  let "index=next"
done <wedding_images.txt

if [ -n "$viewers" ]; then
    echo $viewers >> $OF
fi

echo "  </div>" >> $OF