#!/bin/sh
#
# Push notifications using Simplepush
#
# Environment variables:
#  SIMPLEPUSH_KEY SIMPLEPUSH_PASSWORD SIMPLEPUSH_SALT

api_url=https://api.simplepush.io/send

main() {
	set -ef
	parse_options "$@" || :

	# Encrypt the data only when password is set
	[ -n "$password" ] && {
		iv=$(generate_iv)
		encryption_key=$(generate_key "$password" "$salt")
		message=$(encrypt "$encryption_key" "$iv" "$message")
		title=$(encrypt "$encryption_key" "$iv" "$title")
		encrypted=true
	} ||
		encrypted=false
		
	# Set curl options
	set -- \
		--silent \
		--data-urlencode "key=$key" \
		--data-urlencode "msg=$message" \
	
	$encrypted &&
		set -- "$@" \
			--data-urlencode "encrypted=true" \
			--data-urlencode "iv=$iv"
	
	[ -n "$title" ] &&
		set -- "$@" --data-urlencode "title=$title"
	
	[ -n "$event" ] &&
		set -- "$@" --data-urlencode "event=$event"
	
	curl "$@" "$api_url"
}

usage() {
	prog_name=${0##*/}
	help_text="Usage: $prog_name [options...]

Push notifications using Simplepush

	-e <event>    Event name
	-k <key>      Simplepush key
	-p <pass>     Encryption password
	-s <salt>     Encryption salt
	-t <title>    Title of the push message
	-m <message>  Message to push
	-h	      Display this help text and exit"

	[ $# -gt 0 ] && {
		exec >&2
		printf '%s: %s\n\n' "$prog_name" "$*"
	}
	printf %s\\n "$help_text"
	exit ${1:+1}
}

parse_options() {
	help=false
	key=$SIMPLEPUSH_KEY
	password=$SIMPLEPUSH_PASSWORD
	salt=${SIMPLEPUSH_SALT:-1789F0B8C4A051E5}

	while getopts :e:k:m:p:s:t:h opt; do
		case $opt in
			e) event=$OPTARG ;;
			k) key=$OPTARG ;;
			m) message=$OPTARG ;;
			p) password=$OPTARG ;;
			s) salt=$OPTARG ;;
			t) title=$OPTARG ;;
			h) help=true ;;
			:) usage \
				"option '$OPTARG' requires a parameter" ;;
			\?) usage \
				"unrecognized option '$OPTARG'" ;;
		esac
	done
	shift $((OPTIND-1))
	[ $# -gt 0 ] &&
		usage "unrecognized option '$1'"

	unset opt
	[ -z "$key"     ] && opt=k
	[ -z "$message" ] && opt=m
	[ -n "$opt"     ] &&
		usage "missing or empty mandatory option '$opt'"

	$help && usage
}

generate_iv() {
	openssl enc -aes-128-cbc -k dummy -P -md sha1 |
		sed -n '/^iv/ s/.*=//p'
}
generate_key() {
	_password=$1
	_salt=$2
	printf %s%s "$_password" "$_salt" \
		| sha1sum \
		| awk '{ print toupper(substr($1, 1, 32)) }'
}

encrypt() {
	_key=$1
	_iv=$2
	_data=$3
	printf %s "$_data" |
	    	openssl aes-128-cbc -base64 -K "$_key" -iv "$_iv" |
	    	tr +/ -_ | tr -d \\n
}

main "$@"
