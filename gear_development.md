
prose: https://docs.flywheel.io/Developer_Guides/dev_gear_building_tutorial_part_2_creating_your_first_gear/
code: https://github.com/NPACore/fw-mrrcqa/blob/main/Makefile

"Briefly":
```
  edit Dockerfile run.{py,m,sh}       # actual utility/analysis code
  docker build                        # bundle as reproducible env.

  edit manifest.json                  # setup for flywheel
  fw-beta gear build .                # build local flywheel env; ; NB. rebuilds and retags docker using Dockerfile
  fw-beta gear config --new           # create local test settings

  # add settings/inputs that would be set from flywheel web gui
  fw-beta gear config --input phantom_dicom=$(PWD)/input/phantom_dicom/trunc.zip
  fw-beta gear run                    # test out gear locally with config.json settings built above
  fw-beta gear upload                 # finally, send to flywheel for everyone to access
```
