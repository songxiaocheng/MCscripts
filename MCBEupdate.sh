#!/usr/bin/env bash

# Exit if error
set -e
files='worlds whitelist.json permissions.json server.properties'
pack_dirs='resource_packs behavior_packs'
syntax='`./MCBEupdate.sh $server_dir $minecraft_zip`'

case $1 in
--help|-h)
	echo 'Update Minecraft Bedrock Edition server keeping packs, worlds, whitelist, permissions, and properties. Other files will be removed. You can convert a Windows $server_dir to Ubuntu and vice versa.'
	echo "$syntax"
	echo '$minecraft_zip cannot be in $server_dir. Remember to stop server before updating.'
	exit
	;;
esac
if [ "$#" -lt 2 ]; then
	>&2 echo Not enough arguments
	>&2 echo "$syntax"
	exit 1
elif [ "$#" -gt 2 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

server_dir=$(realpath "$1")
backup_dir=/tmp/$(basename "$server_dir")
if [ -f "$backup_dir" ]; then
	>&2 echo "Backup dir $backup_dir already exists, check and remove it"
	exit 7
fi

minecraft_zip=$(realpath "$2")
if [ -n "$(find "$server_dir" -wholename "$minecraft_zip")" ]; then
	>&2 echo '$minecraft_zip cannot be in $server_dir'
	exit 6
fi
# Test extracting $minecraft_zip partially quietly
unzip -tq "$minecraft_zip"

echo "Enter Y if you stopped the server you're updating"
read -r input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
if [ "$input" != y ]; then
	>&2 echo "$input != y"
	exit 5
fi

cd "$server_dir"
trap 'rm -rf "$backup_dir"; echo fail > version' ERR
cp -r . "$backup_dir"
# Copy all files in $backup_dir no overwriting
trap 'cp -rn "$backup_dir"/. .; rm -rf "$backup_dir"; echo fail > version' ERR
# List all files except . and ..
rm -r $(find "$server_dir" -maxdepth 1 | grep -v "^$server_dir$")
trap 'rm -rf $(find "$server_dir" -maxdepth 1 | grep -v "^$server_dir$"); cp -r "$backup_dir"/. .; rm -rf "$backup_dir"; echo fail > version' ERR
unzip "$minecraft_zip"
# Trim off $minecraft_zip after last .zip
basename "${minecraft_zip%.zip}" > version

for pack_dir in $pack_dirs; do
	# 3rd party packs
	# grep fails if there's no match
	packs=$(ls "$backup_dir/$pack_dir" | grep -Ev 'vanilla|chemistry' || true)
	# Escape \ while reading line from $packs
	echo "$packs" | while read -r pack; do
		cp -r "$backup_dir/$pack_dir/$pack" "$pack_dir/"
	done
done
for file in $files; do
	cp -r "$backup_dir/$file" .
done
rm -r "$backup_dir"
