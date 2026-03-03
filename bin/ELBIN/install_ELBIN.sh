#!/bin/bash
# Install the /ELBIN and /ELDOM tools

echo
echo "Create /ELBIN /ELDOM www-data:www-data";
sudo mkdir /ELBIN /ELDOMS;
sudo chown www-data:www-data /ELBIN /ELDOMS;
sudo chmod g+w /ELBIN /ELDOMS;

echo
echo "Copy Files";
sudo cp -puv bin/* /ELBIN;
sudo cp -puv doms/* /ELDOMS;

# Add alias to ~/.bashrc
check=`grep -c -e"alias cip" ~/.bashrc `;
if [ $check == 0 ]; then
  echo
  echo "Adding aliases to ~/.bashrc";
  cat alias.txt >>~/.bashrc;
  cat alias.txt;
  source ~/.bashrc;
fi

exit 1;


