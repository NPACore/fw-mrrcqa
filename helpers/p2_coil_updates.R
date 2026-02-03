#!/usr/bin/env Rscript

# 20251008WF - init
pacman::p_load(dplyr, lubridate)

env_or_default <- function(envvar, defaults) {
  x <- Sys.getenv(envvar) |> strsplit(",") |> unlist()
  if(is.na(x[1])) x <- defaults
  return(x)
}

# initially only P2 tsnr, but now want all and fwhm
# Sys.setenv(SCANNERS="Prisma1,Prisma2,Prisma3"); 
# Sys.setenv(MEASURES="fwhm"); 
scanners <- env_or_default("SCANNERS", c("Prisma2"))
measures <- env_or_default("MEASURES", c("tsnr"))

csv_url <- "https://wiki.mrrc.pitt.edu/lib/exe/fetch.php?media=phantomqc.csv"

events <- c(visual_fail=ymd('2024-11-04'),
            new_tx     =ymd('2025-08-04'),
            new_body   =ymd('2025-10-08'),
            last_week = today() - days(7))


# Pitt's subdomain cert is suspect, ignore HTTPS/SSL security  
d <- read.csv(curl::curl(csv_url, handle = curl::new_handle(ssl_verifypeer = 0)))

# bin into initial acquisitions, after tx box replaced, after body replace
d_p2 <- d |>
    filter(scanner %in% scanners, # do we only want specific scanners?
           !gtsd_Z                # not failed shim
  ) |>
  mutate(d_ymd=gsub(' .*','',DATE)) |> 
  group_by(scanner,
           dateblk=cut(ymd_hms(DATE),
                       c(as_datetime(0), events, now()),
                       c('early',  names(events)))) |>
  summarise(.groups = "drop", # silence warning about 1-length groups?
	    first=min(d_ymd),
	    last=max(d_ymd),
	    across(all_of(measures),
		   lst(n=\(x) length(which(!is.na(x))),
		       mean=\(x) mean(x,na.rm=T),
		       sd=\(x) sd(x,na.rm=T))))

cat("# ===== Long =====\n")
print.data.frame(d_p2, row.names=F)

cat("# ===== Wide (mean only) =====\n")
d_p2 |> tidyr::pivot_wider(id_cols=c(dateblk), names_from=c(scanner), values_from=matches('^n$|_mean')) |> print.data.frame(row.names=F, width=999)

if(FALSE)
   d|> transmute(date=ymd_hms(DATE), tsnr) |>
   filter(date>=events['new_body']) |>
   ggplot() +
   aes(x=date, y=!!measures[1]) + geom_point() + see::theme_modern()
