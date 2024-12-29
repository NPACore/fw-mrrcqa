# Helpers
The `helpers/` directory incluces scripts outside the container. 
These are used to ...

## Overview
<!-- NB: below used as snip in index.md.
Change line numbers there too when adding/removing bullets here! -->

  * run the gear on all missing to recover from gear rule or automation issue. [run-gears-via-sdk][]
  * update the flywheel session container database info [updating-the-flywheel-db][]
  * upload an up-to-date plot
     * from a script [creating-a-summary-plot][]
     * within an SDK enabled gear [Program.run][]

## Updating the Flywheel DB
::: helpers.updatedb
    options:
      docstring_style: sphinx
      heading_level: 3

## Run Gears via SDK
::: helpers.run_all_mrrcqa
    options:
      docstring_style: sphinx
      heading_level: 3

## Creating a summary plot
::: helpers.snr_from_db
    options:
      docstring_style: sphinx
      heading_level: 3

## Uploading
::: helpers.wiki_upload
    options:
      docstring_style: sphinx
      heading_level: 3
