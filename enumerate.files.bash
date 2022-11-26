#!/bin/bash

: ${1?"Not enough arguments: `basename $0` dir"}

# FIND_ADDON outer env var used for find options. One example is to exclude unwanted files like:
# sudo -u backup FIND_ADDON='( -path */BACKUP.mirror.store.ROOT/* -o -path */_data/postgres ) -prune -o' ./enumerate.files.bash .

DIR="${1}"
: "${DIR_RES:=_data/$(date --iso-8601=s)}"
mkdir -p "${DIR_RES}"

xxhsum --help 2>/dev/null || { echo "Problem: [xxhsum] is not installed, or not in the path!"; exit 2; }
#crc32 || { echo "Problem: [crc32] is not installed, or not in the path!"; exit 3; }
# crc Perl implementation is buggy! See my bugreport https://github.com/redhotpenguin/perl-Archive-Zip/issues/97
# rhash CRC32 implementation will be used instead (by https://askubuntu.com/questions/303662/how-to-check-crc-of-a-file/1363857#1363857)
rhash --help 1>/dev/null 2>/dev/null || { echo "Problem: [rhash] is not installed, or not in the path!"; exit 3; }
md5sum --help 1>/dev/null 2>/dev/null || { echo "Problem: [md5sum] is not installed, or not in the path!"; exit 4; }

#set -x
set -eE # same as: `set -o errexit -o errtrace`
set -o pipefail
shopt -s expand_aliases

source _sql
sql < sql/enumerate-db.sql

# -1 may be usefull to make system more responcive for other tasks
THREADS=$[ $( nproc ) - 0 ]

echo 'Calculate amount of files to process:'
FILES_TOTAL=$( find $DIR ${FIND_ADDON} -not -type d | pv -l | wc -l )
echo FILES_TOTAL=$FILES_TOTAL

SQL_INSERT_PATTERN="INSERT INTO files (dir, filename, inode, size, md5, crc32, xxhash, type, link_to, link_to_canonic, link_to_type) VALUES('%s', '%s', %d, %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s')"

# https://unix.stackexchange.com/questions/39623/trap-err-and-echoing-the-error-line
err_report() {
	echo "Error [$?] on [$(caller)]" >&2
	echo "ERROR process file [$F]" >&2
	# Exit from main script even if error happened in subshell. See https://unix.stackexchange.com/questions/48533/exit-shell-script-from-a-subshell/48542#48542
	sleep 1 # To see error-messages
	kill 0
}
trap 'err_report $LINENO $?' ERR

function insertString(){
	printf "$SQL_INSERT_PATTERN" "${1//\'/\'\'}" "${2//\'/\'\'}" "$3" "$4" "$5" "$6" "$7" "$8" "${9//\'/\'\'}" "${10//\'/\'\'}" "${11//\'/\'\'}"
}

time {
#n=0
# Handle all file names by http://stackoverflow.com/a/1120952/307525
find $DIR ${FIND_ADDON} -not -type d -print0 | \
	pv -0 -s $FILES_TOTAL -f -w 150 --format="%b/$FILES_TOTAL {%t} %p {⏳~ %e} {✔~ %I} {%r (avg: %a)}" | \
	while IFS= read -r -d $'\0' F; do
		{
			link_target="$(readlink -n --canonicalize "$F" || :)" # Handle broken links
			echo $( insertString \
				"$( dirname "$F" )" \
				"$( basename "$F" )" \
				$( stat --format=%i "$F" ) \
				$( stat --format=%s "$F" ) \
				"$( [ -f "$link_target" ] && md5sum < "$F" | cut -d' ' -f1 )" \
				"$( [ -f "$link_target" ] && rhash --printf=%c --crc32 "$F" )" \
				"$( [ -f "$link_target" ] && xxhsum -H1 < "$F" 2>/dev/null | cut -d' ' -f1 )" \
				"$( stat --format=%F "$F" )" \
				"$( readlink -n "$F" || : )" \
				"${link_target}" \
				"$( [ -e "$link_target" ] && stat --format=%F "${link_target}" 2>/dev/null )" \
				) | sql
		} &

		# Configured parallelism (see http://stackoverflow.com/a/16594627/307525)
		[ $( jobs | wc -l ) -ge $THREADS ] && wait || true
	done
wait

echo 'Create DB indexes:'
sql < sql/enumerate-db.indexes.sql
} 2>&1 | tee "${DIR_RES}/enumerate-files.log"

echo 'DONE'
