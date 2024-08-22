# MRRC Prisma Phantom QC
![](docs/QAphantcoil.png)
![](docs/screenshot.png)

## Testing

```
make test
make test-docker
```

Using octave `%!test` in-file tests. See bottom of [Program/readshimvalues.m](Program/readshimvalues.m).

## Interfacing with Flywheel
 * repo init with copy from https://gitlab.com/flywheel-io/scientific-solutions/tutorials/Gear-Building-Tutorial/-/tree/hello-world

 * for `nifti` as file type in `manifest.json`, see https://docs.flywheel.io/User_Guides/user_file_types_in_flywheel/
