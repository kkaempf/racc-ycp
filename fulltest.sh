#!/bin/sh

for f in `find /usr/share/YaST2 -name \*.ycp`; do
  echo $f
  if [ $f != "/usr/share/YaST2/clients/proxy_proposal.ycp" ];
  then
    ruby rbycp.rb -I /usr/share/YaST2/include -I /usr/share/YaST2/modules $f
  fi
  if [ $? -ne 0 ]; 
  then
    break
  fi
done
