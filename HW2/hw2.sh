#!/bin/sh

help_message="hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json"

while getopts :i:o:c:j opt;do
	case $opt in
		i) inputfile=$OPTARG ;;
		o) outputdir=$OPTARG ;;
		c) outputtype=$OPTARG
		   if [ "$outputtype" = "csv" ]; then
			   delimeter=","
		   elif [ "$outputtype" = "tsv" ]; then
			   delimeter="\t"
		   fi ;;
		j) outputinfo=true ;;
		?) echo "$help_message" >&2
		   exit 1 ;;
	esac
done

# no input file or directory
if [ ! -e "$inputfile" ] || [ "${inputfile##*.}" != "hw2" ] || [ -z "$outputdir" ]; then
	echo "$help_message" >&2
	exit 1
fi

mkdir -p "${outputdir}"

# .csv or .tsv file
if [ "$outputtype" = "csv" ]; then
	printf "filename%ssize%smd5%ssha1\n" "$delimeter" "$delimeter" "$delimeter" > "$outputdir"/files."$outputtype"
elif [ "$outputtype" = "tsv" ]; then
	printf "filename\tsize\tmd5\tsha1\n" > "$outputdir"/files."$outputtype"
fi

# info.json
if [ "$outputinfo" ]; then
	name=$(yq -r '.name' "$inputfile")
	author=$(yq -r '.author' "$inputfile")
	date=$(date -Iseconds -r "$(yq -r '.date' "$inputfile")")
	jq -n "{\"name\": \"$name\", \"author\": \"$author\", \"date\": \"$date\"}" > "$outputdir"/info.json
fi

invalid=0

decode(){
	currentfile="$1"
	fcount=$(yq -r '.files | length' "$currentfile")

	for id in $(seq 0 $((fcount-1))); do
		fname=$(yq -r ".files[$id].name" "$currentfile")
		ftype=$(yq -r ".files[$id].type" "$currentfile")
		fdata=$(yq -r ".files[$id].data" "$currentfile" | base64 -d)
		md5=$(yq -r ".files[$id].hash.md5" "$currentfile")
		sha1=$(yq -r ".files[$id].hash.\"sha-1\"" "$currentfile")
		
		echo "$id" "$currentfile" "$fname" "$ftype"
		
		if [ "$(dirname "$fname")" != "." ]; then
			mkdir -p "$outputdir"/"$(dirname "$fname")"
		fi

		echo "$fdata" > "$outputdir"/"$fname"
		size=$(stat -f %z "$outputdir"/"$fname")
		
		if [ "$outputtype" = "csv" ]; then
			printf "%s%s%s%s%s%s%s\n" "$fname" "$delimeter" "$size" "$delimeter" "$md5" "$delimeter" "$sha1" >> "$outputdir/files.$outputtype"
		elif [ "$outputtype" = "tsv" ]; then
			printf "%s\t%s\t%s\t%s\n" "$fname" "$size" "$md5" "$sha1" >> "$outputdir/files.$outputtype"
		fi

		correct_md5=$(md5sum "$outputdir"/"$fname" | cut -d " " -f 1)
		correct_sha1=$(sha1sum "$outputdir"/"$fname" | cut -d " " -f 1)
		if [ "$md5" != "$correct_md5" ] || [ "$sha1" != "$correct_sha1" ]; then
			invalid=$((invalid+1))
		fi

		if [ "$ftype" = "hw2" ]; then
			decode "$outputdir"/"$fname"
			currentfile="$1"
		fi
	done
}

decode "$inputfile"

exit "$invalid"
