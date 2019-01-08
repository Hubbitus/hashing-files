#!/bin/bash

#set -x
set -eE  # same as: `set -o errexit -o errtrace`
set -o pipefail
shopt -s expand_aliases

### Init table
#alias sql='mysql -u filedupes_u --password=HVYAwNtIe9 filedupes'
#alias sql='sudo docker exec -i hashingdb_db_1 mysql -u filedupes_u --password=HVYAwNtIe9 -h 127.0.0.1 filedupes'
alias sql='mysql -u filedupes_u --password=HVYAwNtIe9 -h 127.0.0.1 filedupes'
sql < enumerate.sql

#DIR=~
#DIR=/mnt/data/BACKUP.mirror.store
DIR=/mnt/data/BACKUP.mirror.store/bela.note.vera/bela/u-Pashy/ТРЕНИНГИ/общение/спор/
#DIR=/mnt/data/BACKUP.mirror.store/bela.note.vera/bela/u-Pashy/ТРЕНИНГИ/общение/спор/argument_files

FILES_TOTAL=$( find $DIR -type f | pv -l | wc -l )
echo FILES_TOTAL=$FILES_TOTAL

#FILES_TOTAL=435902

SQL_INSERT_PATTERN="INSERT INTO files (dir, filename, inode, size, md5, crc32, xxhash) VALUES('%s', '%s', %d, %d, '%s', '%s', '%s')"

time {
# https://unix.stackexchange.com/questions/39623/trap-err-and-echoing-the-error-line
err_report() {
	echo "Error [$? - $2] on line $1 [$(caller)]" >&2
	echo "ERROR process file [$F]" >&2
	# Exit from main script even if error happened in subshell. See https://unix.stackexchange.com/questions/48533/exit-shell-script-from-a-subshell/48542#48542
	sleep 1 # To see error-messages
	kill 0
}
trap 'err_report $LINENO $?' ERR

function insertString(){
	printf "$SQL_INSERT_PATTERN" "${1//\'/\'\'}" "${2//\'/\'\'}" "$3" "$4" "$5" "$6" "$7"
}

# Handle all file names by http://stackoverflow.com/a/1120952/307525
find $DIR -type f -print0 | \
	pv -0 -lptera -s $FILES_TOTAL | \
	while IFS= read -r -d $'\0' F; do
#		echo "File:$F"
		{
		echo $( insertString "$( dirname "$F" )" "$( basename "$F" )" $( stat --format=%i "$F" ) $( stat --format=%s "$F" ) "$(  md5sum "$F" | cut -d' ' -f1 )" "$( crc32 "$F" )" "$( xxhsum -H1 "$F" 2>/dev/null | cut -d' ' -f1 )" ) | sql
		}
		# &

		# At most as number of cores (http://stackoverflow.com/a/16594627/307525) "
		[ $( jobs | wc -l ) -ge $( nproc ) ] && wait || true
	done
wait
} 2>&1 | tee process.log
