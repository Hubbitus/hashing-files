SELECT COUNT(*)
FROM files

SELECT *
FROM files

-- Hardlinks (same inode)
SELECT
	inode, COUNT(*)
	, array_agg(dir || '/' || filename) as files
FROM files
WHERE NOT dir like '%/.git/%'
GROUP BY inode
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC


SELECT
	md5, xxhash, COUNT(*)
	, array_agg(dir || '/' || filename) as files
FROM files
--WHERE NOT dir like '%/.git/%'
WHERE size > 0
	AND NOT dir like '%/.git/%'
GROUP BY md5, xxhash
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC


-- Inspect collisions
WITH md5 as (
	SELECT
		md5 as hash
		,COUNT(*) as cnt
		,array_agg(dir || '/' || filename) as files
		,array_agg(DISTINCT xxhash) as xxhashs
		,array_agg("size") as sizes
	FROM files
	WHERE size > 0
	GROUP BY md5
--	HAVING COUNT(*) > 1
	ORDER BY COUNT(*) DESC
), xxhash AS (
	SELECT
		xxhash as hash
		,COUNT(*) as cnt
		,array_agg(dir || '/' || filename) as files
		,array_agg(DISTINCT md5) as md5s
		,array_agg("size") as sizes
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
SELECT 'md5' as hash_type, hash, files, ARRAY[hash] as md5s, xxhashs, sizes
FROM md5
WHERE cardinality(xxhashs) > 1
UNION ALL
SELECT 'xxhash' as hash_type, hash, files, md5s, ARRAY[hash] as xxhashs, sizes
FROM xxhash
WHERE cardinality(md5s) > 1

-- Some filenames are not in UTF-8:
SELECT
--	convert_from(encode(dir, 'escape'), 'UTF-8')
	convert_from(dir, 'UTF-8')
	,dir
	,*
FROM files
;


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
