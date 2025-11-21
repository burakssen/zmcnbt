# Todo: 

## Compression Support

- [ ] Gzip, Zlib compression
- [ ] add apis for read and write like (readCompressed, writeCompressed)

## SNBT Stringigied NBT Support

- [ ] add api for conversion to snbt and from snbt like (toSnbt, fromSnbt)

## Direct file operations for dat files

- [ ] add api for reading and writing to files.

## Utility

- [ ] (optional) add deep cloning for tags.
- [ ] (optional) path based access like (getPath, setPath). Basically this will be able to get a tag inside compound tag or be able to set a tag inside compound tag.

## Validation

- [ ] For large files add streaming api
- [ ] (optional) Iterator interface for compounds and lists
- [ ] Memory pooling - for frequently created and destroyed tags.

## Convenience

- [ ] (optional) Compound tag builder
- [ ] (optional) Typesafe getters and setter
