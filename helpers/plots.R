#!/usr/bin/env Rscript
if(! 'pacman' %in% installed.packages()) install.packages('pacman')
pacman::p_load(dplyr, tidyr, ggplot2, reticulate)
use_virtualenv("../.venv")

# read in from excel sheets. one per scanner
read_excel <- function(xls_fname='../v2/20250312/DailyQA.xlsx') {
    d <- paste0('Prisma',1:3) |>
        lapply( \(n) readxl::read_excel(xls_fname,sheet=n) |>
                     mutate(scanner=n)) |>
        bind_rows()
}

# using flywheel db
read_flywheel <- function(){
    # had hoped to reuse python code within R
    # but numpy.int64/nan is hard to handle?
    fname <- tempfile("fw_snr", fileext = c(".csv"))
    snr_py <- import("snr_from_db")
    snr_py$SNR()$all_shim_and_snr_csv(fname)

    # to match excel, DATE only has day (no time). no index
    d <- read.csv(fname) |>
        select(-X) |>
        rename(DATE=date) |>
        mutate(DATE=gsub(' .*','',DATE))

    unlink(fname)
    return(d)
}
upload_img <- function(img_file){
    up <- import("wiki_upload")
    up$upload_snr(img_file)
}


gen_plot <- function(d) {
  # had columns for each measure. want row unique to day+scanner+measure
  d_long <- d |>
      mutate(DATE=lubridate::ymd(DATE)) |>
      gather('m','v',-DATE, -scanner) |>
      # also have a bunch of values we can ingore for now
      mutate(mtype=case_when(
                 grepl('ALIAS|SNR', m, ignore.case=T) ~ "snr",
                 grepl('^(X|Y|Z|B0)$', m) ~ "shim",
                 .default = 'ignore'))
  
  # use v_prct for plotting and v greater than 3*SD for highlighting
  d_stat <- d_long |>
      group_by(scanner, m) |>
      mutate(v_mean=mean(v, na.rm=T),
             v_sd  = sd(v, na.rm=T),
             v_prct = (v - v_mean)/v_mean * 100,
             v_gtsd = abs(v-v_mean) > 3*v_sd)
  
  # subset the suspicous values (based on sd)
  suspect <- d_stat|>filter(m %in% c('SNR','tSNR','Z'),v_gtsd)
  
  # plot lines for all and points for suspect values
  p <- d_stat |>
   filter(mtype!='ignore') |>
   ggplot() +
      aes(x=DATE, y=v_prct, color=m) +
      geom_line() +
      geom_point(data=suspect, color='red') +
      ggrepel::geom_text_repel(data=suspect, aes(label=m, color=NULL)) +
      facet_grid(mtype~scanner, scale='free_y') +
      labs(x="Day",y="percent from mean", title="Phantom QC",
           subtitle="flag SNR or Z w/ SD > 3") +
      theme_bw()
}

main <- function() {
   d <- read_flywheel()
   p <- gen_plot(d)
   ggsave(p, file='PhantomQC.png', width=14, height=3.57)
}
