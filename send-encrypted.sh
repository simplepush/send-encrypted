#!/bin/sh

usage() { echo "Usage: $0 -k <simplepush_key> -p <password> [-s <salt>] [-e <event>] [-t <title>] -m <message>" 1>&2; exit 0; }

while getopts ":k:p:s:e:t:m:" o; do
	case "${o}" in
		k)
			k=${OPTARG}
			;;
		p)
			p=${OPTARG}
			;;
		s)
			s=${OPTARG}
			;;
		e)
			e=${OPTARG}
			;;
		t)
			t=${OPTARG}
			;;
		m)
			m=${OPTARG}
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

if [ -z "${k}" ] || [ -z "${p}" ] || [ -z "${m}" ]; then
  usage
	return 1
fi

generate_key () {
    # First argument is password
	if [ -z "${s}" ]; then
    	echo -n "${1}${salt}" | sha1sum | awk '{print toupper($1)}' | cut -c1-32
	else
    	echo -n "${1}${s}" | sha1sum | awk '{print toupper($1)}' | cut -c1-32
	fi
}

encrypt () {
    # First argument is key
    # Second argument is IV
    # Third argument is data

    echo -n "${3}" | openssl aes-128-cbc -base64 -K "${1}" -iv "${2}" | awk '{print}' ORS='' | tr '+' '-' | tr '/' '_'
}

iv=`openssl enc -aes-128-cbc -k dummy -P -md sha1 | grep iv | cut -d "=" -f 2`

salt=1789F0B8C4A051E5

encryption_key=`generate_key "${p}"`

if [ -n "${t}" ]; then
    title_encrypted=`encrypt "${encryption_key}" "${iv}" "${t}"`
	  title="&title=${title_encrypted}"
else
	  title=""
fi

if [ -n "${e}" ]; then
	  event="&event=${e}"
else
	  event=""
fi

message=`encrypt "${encryption_key}" "${iv}" "${m}"`

curl --data "key=${k}${title}&msg=${message}${event}&encrypted=true&iv=$iv" "https://api.simplepush.io/send" > /dev/null 2>&1
