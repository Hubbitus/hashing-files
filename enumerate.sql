
DROP TABLE IF EXISTS files;

-- For choosen algorithms see hashing.test
CREATE TABLE files(
	dir BLOB NOT NULL,
	filename BLOB NOT NULL,
	inode BIGINT NOT NULL,
	size BIGINT NOT NULL,
	md5 CHAR(32) NOT NULL,
	crc32 CHAR(8) NOT NULL,
	xxhash VARCHAR(1024) NOT NULL
) DEFAULT CHARACTER SET = utf8mb4
