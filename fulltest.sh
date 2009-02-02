#!/bin/sh

for f in `find /usr/share/YaST2 -name \*.ycp`; do
  echo $f
  ruby rbycp.rb -I /usr/share/YaST2/include $f
  if [ $? -ne 0 ]; 
  then
    break
  fi
done
