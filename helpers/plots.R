#!/usr/bin/env Rscript
# guix shell python r r-reticulate r-pacman r-dplyr r-tidyr r-ggplot2 -- ./plots.R
if(! 'pacman' %in% installed.packages()) install.packages('pacman')
pacman::p_load(dplyr, tidyr, ggplot2, reticulate, ggrepel, cowplot, lubridate)
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
        rename(DATE=date)
        # 20250625 - have more than one per day. give up on matching excel by date
        # |> mutate(DATE=gsub(' .*','',DATE))

    # names are
    # c("X.1", "snr", "alias", "bkoff", "tsnr", "DATE", "scanner", "test", "Y", "Z", "X2", "Y2", "Z2", "XY", "S2", "B0")
    unlink(fname)
    return(d)
}

#' Pull tempurature from excel and merge with data
#' @param d dataframe with 'DATE' and 'scanner' columns. likely from read_flywheel()
#' @return dataframe with new 'Temp' column
add_temp <- function(d){
    tempr <- readxl::read_excel('tempurature_log.xlsx') # DATE `PRISMA 1` `PRISMA 2` PRISMA 3`
    tmpr_day <- tempr |>
        rename_with(\(x) gsub('RISMA ','risma',x)) |>
        mutate(day=gsub(' .*','',DATE)) |>
        # TODO: will want to grab Prisma|7T when terra x comes online?
        select(day, matches('Prisma'))  |>
        pivot_longer(-day, names_to='scanner', values_to='Temp')
        # columns: day, scanner, Temp

    d_tmpr <- d |>
        mutate(day=gsub(' .*','',DATE)) |>
        merge(tmpr_day, by=c('day','scanner'), all.x=T) |>
        select(-day)
}
upload_img <- function(img_path){
    up <- import("wiki_upload")
    up$upload_snr(img_path)
}

#' upload csv to wiki using wiki_upload.py via reticulate
#' creates a temporary file that is removed
#' @param d row per QA likely from read_flywheel() |> add_temp()
#' @param wiki_name upload file name
upload_csv <- function(d, wiki_name='PhantomQC.csv'){
    up <- import("wiki_upload")
    wiki_root <- Sys.getenv("WIKIROOT")
    # without this, python code would also default to WIKIROOT and error if empty
    if(!nzchar(wiki_root)) wiki_root <- "https://wiki.mrrc.pitt.edu/"

    dw <- up$DokuWiki(wiki_root)

    tempcsv <- tempfile("PhantomQC", fileext = c(".csv"))
    d_stats_wide <- d |> long_stats() |> stats_to_wide()
    write.csv(d_stats_wide, tempcsv, row.names=F)
    tryCatch(dw$upload_file(tempcsv, wiki_name=wiki_name, binary=FALSE),
             finally=\() unlink(tempcsv))
}

long_stats <- function(d){

  # had columns for each measure. want row unique to day+scanner+measure
  d_long <- d |>
      mutate(DATE=lubridate::ymd_hms(DATE)) |>
      gather('m','v',-DATE, -scanner) |>
      # also have a bunch of values we can ingore for now
      mutate(mtype=case_when(
                 grepl('ALIAS|SNR|Temp', m, ignore.case=T) ~ "snr",
                 grepl('^(X|Y|Z|B0)$', m) ~ "shim",
                 .default = 'ignore'))

  # use v_prct for plotting and v greater than 3*SD for highlighting
  d_stat <- d_long |>
      group_by(scanner, m) |>
      mutate(v_mean=mean(v, na.rm=T),
             v_sd  = sd(v, na.rm=T),
             v_prct = (v - v_mean)/v_mean * 100,
             v_gtsd = abs(v-v_mean) > 3*v_sd)
}
stats_to_wide <- function(d_stats){
   d_stats|>
     filter(m!='X.1') |>
     pivot_wider(id_cols=c('DATE','scanner'),
                 names_from=c('m'),
                 values_from=matches('^v'),
                 values_fn=first) |>
    rename_with(\(x) gsub('^v_','',x))
}

gen_plot <- function(d) {

  d_stat <- long_stats(d)

  # subset the suspicous values (based on sd)
  suspect <- d_stat|>filter(m %in% c('snr','tsnr','Z'),v_gtsd)

  # current values only, for labeling
  d_today <- d_stat|>filter(m %in% c('tsnr','Z'),DATE==max(DATE))
  
  # plot lines for all and points for suspect values
  lastday <- format(max(d_stat$DATE), "%m/%d")
  tsnr_string <- d_stat |>
    filter(format(DATE, "%Y%m%d") == max(format(d_stat$DATE, "%Y%m%d")), m=='tsnr') |>
    with(paste(scanner,round(v,1), sep=":", collapse=", ")) |>
    gsub(pattern='Prisma', replacement='P')

  p <- d_stat |>
   filter(mtype!='ignore') |>
   ggplot() +
      aes(x=DATE, y=v_prct, color=m) +
      geom_vline(data=suspect,aes(xintercept=DATE),
                 color="darkgray", linetype=3) +
      geom_line() +
      geom_point(data=suspect, color='red') +
      ggrepel::geom_text_repel(data=suspect, aes(label=m, color=NULL)) +
      ggrepel::geom_label_repel(data=d_today,
                               aes(label=round(v,1),color=m)) +
      facet_grid(mtype~scanner, scale='free_y') +
      labs(x="Day",y="percent from mean",
           title=paste0("Phantom QC ", lastday, format(now()," (gen %Y-%m-%d %H:%M)")),
           subtitle=paste0("flag SNR or Z w/ SD > 3; ", tsnr_string)) +
      theme_bw()

}

#' main function run if file executed as script
#' fetch FW data. uploads row per QA measure csv file to wiki. plots. uploads plot
#' Use NOUPLOAD=1 to disable uploading (NB unset NOUPLOAD to undo; NOUPLOAD=0 still disables)
main <- function() {
   d_fw <- read_flywheel()
   d <- add_temp(d_fw)
   # dont upload if NOUPLOAD environment variable is set
   upload <- length(Sys.getenv("NOUPLOAD"))!=0

   # upload to wiki
   if(upload) upload_csv(d, 'PhantomQC.csv')
   # save a local copy
   write.csv(d,'PhantomQC.csv',row.names=F)

   p <- gen_plot(d)
   # like above: save local copy and upload to wiki
   ggsave(p, file='PhantomQC.png', width=14, height=3.57)
   if(upload) upload_img('PhantomQC.png')
}

#' dead code. used to compare matlab excel output with flywheel(octave)/R/python generated
compare_excel_fw <- function(d, d.x) {
   x <- d.x |> select(DATE,tsnr=tSNR,scanner) |> mutate(from='excel')
   f<- d|>select(DATE,tsnr,scanner)|>mutate(from='fw')
   p_vals <- rbind(x,f) |> ggplot() +
       aes(x=lubridate::ymd(DATE),y=tsnr, color=from) +
       geom_point(alpha=.7) +
       facet_grid(scanner~.) +
       theme_bw() +
       theme(legend.position="inside",
             legend.direction = "horizontal",
             legend.position.inside=c(.5,1)) +
       labs(x="date", title="tsnr over time")

   dx.long <- d.x |>
       select(date=DATE,scanner, snr=SNR,alias=ALIAS,tsnr=tSNR,Z) |>
       pivot_longer(cols=c(snr,alias,tsnr,Z))
   d.long <- d |> select(date=DATE,scanner, snr,alias,tsnr,Z) |>
       pivot_longer(cols=c(snr,alias,tsnr,Z))
   long.m <- merge(dx.long,d.long, by=c("date","scanner", "name"), suffixes=c('_x','_f')) |> mutate(x_f = value_x-value_f)
   long.stats <- long.m |> group_by(scanner,name) |> summarise(mean(x_f), n=n(), md=median(x_f), mx=max(x_f), mn=min(x_f), sd=sd(x_f))

   p_box <- ggplot(long.m) +
       aes(y=x_f, x=name, fill=scanner) +
       geom_boxplot() +
       theme_bw() +
       theme(legend.position="inside",
             legend.direction = "horizontal",
             legend.position.inside=c(.5,1)) +
       labs(x="measure",y="excel - flywheel", title="difference of meassures")

  cowplot::plot_grid(p_vals, p_box, nrow=2)

  dx.p <- gen_plot(d.x) + ggtitle('excel')
  d.p <- gen_plot(d) + ggtitle('fw')
  cowplot::plot_grid(dx.p, d.p, nrow=2)

}

# if run by script, not sourced
if (sys.nframe() == 0) main()

