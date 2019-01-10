#!/bin/bash

#set -x
set -eE  # same as: `set -o errexit -o errtrace`
set -o pipefail
shopt -s expand_aliases

### Init table
# Access without password assumed! Password must be stored in ~/.pgpass
alias sql='psql -qX1n -v ON_ERROR_STOP=1 -U filedupes_u -h 127.0.0.1 --dbname filedupes'
sql < enumerate.sql

DIR=/mnt/data/BACKUP.mirror.store

# Files in incorrect encoding:
#DIR=/mnt/data/BACKUP.mirror.store/bela.note.vera/bela/u-Pashy/ТРЕНИНГИ/общение/спор/
# File with ' in name
#DIR=/mnt/data/BACKUP.mirror.store/bela.note.vera/bela/Music/Enigma

# md5sum chash with \ (slash). See https://unix.stackexchange.com/questions/313733/various-checksums-utilities-precede-hash-with-backslash
#DIR=/mnt/data/BACKUP.mirror.store/bela.note.vera/bela/.local/share/gvfs-metadata/

FILES_TOTAL=$( find $DIR -type f | pv -l | wc -l )
echo FILES_TOTAL=$FILES_TOTAL

SQL_INSERT_PATTERN="INSERT INTO files (dir, filename, inode, size, md5, crc32, xxhash) VALUES('%s', '%s', %d, %d, '%s', '%s', '%s')"

time {
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

# Handle all file names by http://stackoverflow.com/a/1120952/307525
find $DIR -type f -print0 | \
	pv -0 -lpteIra -s $FILES_TOTAL | \
	while IFS= read -r -d $'\0' F; do
#		echo "File:$F"
		{
			echo $( insertString "$( dirname "$F" )" "$( basename "$F" )" $( stat --format=%i "$F" ) $( stat --format=%s "$F" ) "$( md5sum < "$F" | cut -d' ' -f1 )" "$( crc32 "$F" )" "$( xxhsum -H1 < "$F" 2>/dev/null | cut -d' ' -f1 )" ) | sql
		}
		# &

		# At most as number of cores (http://stackoverflow.com/a/16594627/307525) "
		[ $( jobs | wc -l ) -ge $( nproc ) ] && wait || true
	done
wait
} 2>&1 | tee process.log
