#!/usr/bin/env Rscript

# 20251008WF - init
pacman::p_load(dplyr, lubridate)

csv_url <- "https://wiki.mrrc.pitt.edu/lib/exe/fetch.php?media=phantomqc.csv"

events <- c(visual_fail=ymd('2024-11-04'),
            new_tx     =ymd('2025-08-04'),
            new_body   =ymd('2025-10-08'))


# Pitt's subdomain cert is suspect, ignore HTTPS/SSL security  
d <- read.csv(curl::curl(csv_url, handle = curl::new_handle(ssl_verifypeer = 0)))

# bin into initial acquisitions, after tx box replaced, after body replace
d_p2 <- d |>
    filter(scanner=='Prisma2', # only p2
           !gtsd_Z             # not failed shim
  ) |>
  mutate(d_ymd=gsub(' .*','',DATE)) |> 
  group_by(dateblk=cut(ymd_hms(DATE),
                       c(as_datetime(0), events, now()),
                       c('early',  names(events)))) |>
  summarise(first=min(d_ymd), last=max(d_ymd),n=n(), across(c(tsnr), lst(mean,sd)))

print.data.frame(d_p2, row.names=F)

if(FALSE)
   d|> transmute(date=ymd_hms(DATE), tsnr) |>
   filter(date>=events['new_body']) |>
   ggplot() +
   aes(x=date, y=tsnr) + geom_point() + see::theme_modern()
