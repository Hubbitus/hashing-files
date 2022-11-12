# hashing-files
Solution (bash, hash, postgres) to enumerate directories with several hashes (md5sum, crc32, xxhash) to build database of tree, sizes, etc. The main advantage is to analyze and easy handle duplicates in big backups!

# Setup env

## Dependencies
For run it please install next dependencies (all of them in official repos of Fedora atleast):
* podman
* podman-compose
* md5sum
* rhash
* tree
* du

## Run container

First set password for the container and write it into `.pgpass`:

```bash
echo "POSTGRES_PASSWORD={my_cool_pass}" > .env
source .env
echo "127.0.0.1:5432:filedupes:filedupes_u:${"POSTGRES_PASSWORD}" >> ~/.pgpass
```

And then just run the postgres container:
```bash
podman-compose up -d
```

> **Note** Docker/docker-compose also should work if you use such old tools.

### Confi

# Main entrypoint
Please look ad [FULL.run](FULL.run) script.
