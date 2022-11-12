SELECT *
FROM files

SELECT
	inode, COUNT(*)
	, array_agg(dir || '/' || filename) as files
FROM files
WHERE NOT dir like '%/.git/%'
GROUP BY inode
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC


SELECT
	md5, crc32, xxhash, COUNT(*)
	, array_agg(dir || '/' || filename) as files
FROM files
--WHERE NOT dir like '%/.git/%'
WHERE size > 0
	AND NOT dir like '%/.git/%'
GROUP BY md5, crc32, xxhash
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC

CREATE INDEX files__md5 ON files(md5);
CREATE INDEX files__crc32 ON files(crc32);
CREATE INDEX files__xxhash ON files(xxhash);

-- Inspect collisions
WITH md5 as (
	SELECT
		md5 as hash
		,COUNT(*) as cnt
		,array_agg(dir || '/' || filename) as files
		,array_agg(DISTINCT crc32) as crc32s
		,array_agg(DISTINCT xxhash) as xxhashs
	FROM files
	WHERE size > 0
	GROUP BY md5
--	HAVING COUNT(*) > 1
	ORDER BY COUNT(*) DESC
), crc32 as (
	SELECT
		crc32 as hash
		,COUNT(*) as cnt
		,array_agg(dir || '/' || filename) as files
		,array_agg(DISTINCT md5) as md5s
		,array_agg(DISTINCT xxhash) as xxhashs
	FROM files
	WHERE size > 0
	GROUP BY crc32
--	HAVING COUNT(*) > 1
	ORDER BY COUNT(*) DESC
), xxhash AS (
	SELECT
		xxhash as hash
		,COUNT(*) as cnt
		,array_agg(dir || '/' || filename) as files
		,array_agg(DISTINCT crc32) as crc32s
		,array_agg(DISTINCT md5) as md5s
	FROM files
	WHERE size > 0
	GROUP BY xxhash
--	HAVING COUNT(*) > 1
	ORDER BY COUNT(*) DESC
)
--SELECT
--	(SELECT COUNT(*) FROM md5) as md5_count
--	,(SELECT COUNT(*) FROM crc32) as crc32_count
--	,(SELECT COUNT(*) FROM xxhash) as xxhash_count
	-- Result (probably have CRC collisions?):
-- md5_count|crc32_count|xxhash_count|
-- ---------+-----------+------------+
--    424806|     424782|      424806|
-- Look at collisions deeper:
SELECT 'md5' as hash_type, hash, files, null as md5s, crc32s, xxhashs
FROM md5
WHERE cardinality(crc32s) > 1 OR cardinality(xxhashs) > 1
UNION ALL
SELECT 'crc32' as hash_type, hash, files, md5s, null as crc32s, xxhashs
FROM crc32
WHERE cardinality(md5s) > 1 OR cardinality(xxhashs) > 1
UNION ALL
SELECT 'xxhash' as hash_type, hash, files, md5s, crc32s, null as xxhashs
FROM xxhash
WHERE cardinality(crc32s) > 1 OR cardinality(md5s) > 1


SELECT
--	convert_from(encode(dir, 'escape'), 'UTF-8')
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
