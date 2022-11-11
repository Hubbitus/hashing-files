SELECT
	convert_from(encode(dir, 'escape'), 'UTF-8')
	convert_from(dir, 'UTF-8')
	,dir
	,*
FROM files
;

SELECT *
FROM pg_collation;


SELECT pg_char_to_encoding('UTF8'), pg_char_to_encoding('SQL_ASCII')

-- https://stackoverflow.com/questions/5090858/how-do-you-change-the-character-encoding-of-a-postgres-database/5091083#5091083
update pg_database set encoding = pg_char_to_encoding('SQL_ASCII') where datname = 'filedupes'


SELECT *
FROM pg_database

SET client_encoding = 'SQL_ASCII';

SHOW client_encoding;

SELECT
	filename::bytea
--	,convert_to(filename, 'UTF-8')
	,convert_from(filename, 'UTF-8')
FROM files
WHERE
	is_utf8(filename) = false
-- WHERE filename LIKE '%.odt'

SELECT *
FROM files
WHERE
	is_utf8(filename)


SELECT COUNT(*)
FROM files
