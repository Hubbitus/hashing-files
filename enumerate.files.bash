#!/bin/bash

: ${1?"Not enough arguments: `basename $0` dir"}

DIR="${1}"

psql --help 1>/dev/null || { echo "Problem: [psql] is not installed, or not in the path!"; exit 1; }
xxhsum --help 2>/dev/null || { echo "Problem: [xxhsum] is not installed, or not in the path!"; exit 2; }
crc32 || { echo "Problem: [crc32] is not installed, or not in the path!"; exit 3; }
md5sum --help 1>/dev/null 2>/dev/null || { echo "Problem: [crc32] is not installed, or not in the path!"; exit 4; }

#set -x
set -eE  # same as: `set -o errexit -o errtrace`
set -o pipefail
shopt -s expand_aliases

### Init table
# Access without password assumed! Password must be stored in ~/.pgpass:
# echo 127.0.0.1:5432:filedupes:filedupes_u:<password> >> ~/.pgpass
alias sql='psql -qX1n -v ON_ERROR_STOP=1 -U filedupes_u -h 127.0.0.1 --dbname filedupes'
sql -e < enumerate.sql

THREADS=$[ $( nproc ) - 2 ]

echo 'Calculate amount of files to process:'
FILES_TOTAL=$( find $DIR -type f | pv -l | wc -l )
echo FILES_TOTAL=$FILES_TOTAL

SQL_INSERT_PATTERN="INSERT INTO files (dir, filename, inode, size, md5, crc32, xxhash) VALUES('%s', '%s', %d, %d, '%s', '%s', '%s')"

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
	printf "$SQL_INSERT_PATTERN" "${1//\'/''}" "${2//\'/''}" "$3" "$4" "$5" "$6" "$7"
}

time {
#n=0
# Handle all file names by http://stackoverflow.com/a/1120952/307525
find $DIR -type f -print0 | \
	pv -0 -s $FILES_TOTAL -f -w 150 --format="%b/$FILES_TOTAL {%t} %p {remaining %e} {finish at %I} {%r (avg: %a)}" | \
	while IFS= read -r -d $'\0' F; do
#		[ $((n++%1000)) -eq 0 ] && echo $n
		{
			echo $( insertString "$( dirname "$F" )" "$( basename "$F" )" $( stat --format=%i "$F" ) $( stat --format=%s "$F" ) "$( md5sum < "$F" | cut -d' ' -f1 )" "$( crc32 "$F" )" "$( xxhsum -H1 < "$F" 2>/dev/null | cut -d' ' -f1 )" ) | sql #"
		} &

		# At most as number of cores (http://stackoverflow.com/a/16594627/307525)
		[ $( jobs | wc -l ) -ge $THREADS ] && wait || true
	done
wait
} 2>&1 | tee process.log

echo 'DONE'
