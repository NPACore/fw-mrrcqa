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
measures <- env_or_default("MEASURES", c("tsnr","fwhm","Y"))
use_lastweek <- env_or_default("LASTWEEK", "1")

csv_url <- "https://wiki.mrrc.pitt.edu/lib/exe/fetch.php?media=phantomqc.csv"

events <- read.table('events.tsv',header=T) |> mutate(eventdate=ymd(eventdate))
# maybe we want just the specified events?
if(use_lastweek == "1") events <- rbind(events, data.frame(eventdate= today() - days(7), scanner=paste0("Prisma",c(1:3)), event="last_week"))
# only last_week and earlier
if(use_lastweek == "only") events <- data.frame(eventdate= today() - days(7), scanner=paste0("Prisma",c(1:3)), event="last_week")


# Pitt's subdomain cert is suspect, ignore HTTPS/SSL security  
d <- read.csv(curl::curl(csv_url, handle = curl::new_handle(ssl_verifypeer = 0))) |> mutate(DATE=ymd_hms(DATE))

d_events <- d |>
    left_join(events |> group_by(scanner) |> mutate(nextdate=lead(eventdate, default=today()+days(1))) |> ungroup(),
              by=join_by(x$scanner==y$scanner, x$DATE >= y$eventdate, x$DATE <= y$nextdate)) |>
    mutate(event=ifelse(is.na(event), 'early',event))

# bin into initial acquisitions, after tx box replaced, after body replace
d_p2 <- d_events |>
    filter(scanner %in% scanners, # do we only want specific scanners?
           !gtsd_Z                # not failed shim
  ) |>
  mutate(d_ymd=gsub(' .*','',DATE)) |> 
  group_by(scanner, event) |>
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
d_p2 |> tidyr::pivot_wider(id_cols=c(event), names_from=c(scanner), values_from=matches('^n$|_mean')) |> print.data.frame(row.names=F, width=999)

if(FALSE) {
   library(ggplot2)
   #png("/tmp/QA.png") #rsixel::sixel()
   d_long <- d_events |> select(DATE,event, scanner, all_of(measures)) |>
       tidyr::pivot_longer(all_of(measures), values_to="value", names_to="measure") |>
       group_by(DATE,event,scanner,measure) |> mutate(event_date=mean(DATE[!is.na(value)])) |> ungroup()

   d_longng_stat <- d_long |> group_by(scanner,event, measure) |>
       summarise(n=length(which(!is.na(value))), DATE=mean(DATE[!is.na(value)]), value=mean(value,na.rm=T))

   ggplot(d_long) +
       aes(x=DATE, y=value, color=event) +
       geom_point() +
       facet_wrap(measure~scanner, scales='free') +
       geom_violin(aes(x=event_date), alpha=.5) +
       #geom_point(aes(size=n,fill=event),shape=21,color='black',data=d_long_stat) +
       theme_bw()
      #+ see::theme_modern()
   #dev.off()
}
