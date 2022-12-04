DROP TABLE IF EXISTS files;

-- Hack by https://stackoverflow.com/questions/5090858/how-do-you-change-the-character-encoding-of-a-postgres-database/5091083#5091083
-- to allow save filenames which are not valid UTF-8! Otherwise we get error: invalid byte sequence for encoding "UTF8"
UPDATE pg_database SET ENCODING = pg_char_to_encoding('SQL_ASCII') WHERE datname = 'filedupes';

-- For choosen algorithms see hashing.test
CREATE TABLE files(
	dir text NOT NULL,
	filename text NOT NULL,
	inode BIGINT NOT NULL,
	size BIGINT NOT NULL,
	md5 CHAR(32) NOT NULL,
	xxhash CHAR(16) NOT NULL,
	type text,
	for_del boolean NOT NULL DEFAULT false,
	for_del_dir boolean NOT NULL DEFAULT false,
	link_to text,
	link_to_canonic text,
	link_to_type text,
	link_broken boolean GENERATED ALWAYS AS ('symbolic link' = type AND '' = link_to_type) STORED,
		PRIMARY KEY(dir, filename)
);

-- By https://stackoverflow.com/questions/25287639/how-to-identify-if-a-value-in-column-can-be-encoded-to-latin-in-postgres
CREATE OR REPLACE FUNCTION is_utf8(input text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
	PERFORM convert_to(input, 'utf-8');
		RETURN true;
EXCEPTION
	WHEN OTHERS THEN
		RETURN false;
END;
$$;
