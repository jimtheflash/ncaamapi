library(dplyr)
library(httr2)
library(jsonlite)
library(lubridate)
library(rvest)

## NOT RUN
# season_divisions <- list(
#   "2014_15" = "12320",
#   "2015_16" = "12700",
#   "2016_17" = "13100",
#   "2017_18" = "13533",
#   "2018_19" = "16700",
#   "2019_20" = "17060",
#   "2020_21" = "17420",
#   "2021_22" = "17783",
#   "2022_23" = "17940",
#   "2023_24" = "18221"
#   )
#
# hdrs <- list(
#   "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
#   "Accept-Encoding" = "gzip, deflate, br",
#   "Accept-Language" = "en-US,en;q=0.9",
#   "Sec-Ch-Ua" = '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
#   "Sec-Ch-Ua-Mobile" = "?0",
#   "Sec-Ch-Ua-Platform" = "macOS",
#   "Sec-Fetch-Dest" = "document",
#   "Sec-Fetch-Mode" = "navigate",
#   "Sec-Fetch-Site" = "same-origin",
#   "Sec-Fetch-User" = "?1",
#   "Upgrade-Insecure-Requests" = "1",
#   "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
#   )
#
# qry <- list(
#   "utf8" = "%E2%9C%93",
#   "season_division_id" = "",
#   "game_date" = "",
#   "conference_id" = "0",
#   "tournament_id" = "",
#   "commit" ="Submit"
#   )
#
#
# all_seasons_list <- list()
# for (i in names(season_divisions)) {
#
#   id <- season_divisions[[i]]
#   year_part <- as.numeric(sapply(strsplit(i, '_'), function(x) x[[1]]))
#   int_start <- ymd(paste0(year_part, '-10-10'))
#   int_end <- ymd(paste0(year_part+1, '-04-10'))
#   season_dates <- seq(int_start, int_end, by='day')
#
#   url_string <- paste0('https://stats.ncaa.org/season_divisions/', id, '/livestream_scoreboards')
#
#   all_dates_list <- list()
#   for (j in season_dates) {
#
#     j <- as.Date(j)
#     date_string <- paste0(month(j), '/', day(j), '/', year(j))
#     qry$game_date <- date_string
#
#     message('attempting to grab games for ', date_string)
#
#     resp <- request(url_string) |>
#       req_headers(!!!hdrs) |>
#       req_url_query(!!!qry) |>
#       req_perform()
#
#     if (resp$status_code != 200) {
#       message('request failed with status was ', resp$status_code, ' for date ', j)
#       next
#     }
#
#     links <- resp |>
#       resp_body_html() |>
#       html_nodes('a') |>
#       html_attr('href')
#
#     box_score_links <- grep('box_score', links, value = TRUE)
#     game_ids <- unique(sapply(strsplit(box_score_links, '/'), function(x) x[[3]]))
#
#     all_dates_list[[date_string]] <- game_ids
#     rm(resp, game_ids)
#     qry$game_date <- ""
#     gc()
#     Sys.sleep(runif(1, 2, 15))
#
#   }
#
#   all_seasons_list[[i]] <- all_dates_list
#
#   }
#
# # ok so there's a LOT of game_ids
# game_ids <- unique(unlist(sapply(all_seasons_list, function(x) unique(unlist(x)))))
# write(game_ids, 'game_ids.txt')


# TIME TO GET THE BOX AND PBP DATA
game_ids <- readLines('game_ids.txt')
# once you have the game_ids you can use those to get box scores and pbp
# also good to have a list of successes and failures i think
error_list <- c()
success_list <- c()
for (id in game_ids) {
  if (id %in% success_list) next
  Sys.sleep(runif(1, 3, 10))
  message('trying to get box and pbp for id ', id)

  # start with box scores! these are really a bunch of html tables
  box_url <- paste0('https://stats.ncaa.org/contests/', id, '/box_score')
  box_html <- read_html(box_url)
  box_tables <- html_table(box_html) |>
    bind_rows()

  # box_tables should be a list of tibbles; if it isn't, something is wrong, add to the error list
  if (nrow(box_tables) < 1) {
    message('issue with box_tables for id ', id, ', adding to error_list and moving on...')
    error_list[[length(error_list) + 1]] <- id
    next
  }

  # AH! but the pbp id is actually...different!
  links <- box_html |>
    html_nodes('a') |>
    html_attr('href')

  pbp_link <- grep('play_by_play', links, value = TRUE)

  pbp_url <- paste0('https://stats.ncaa.org', pbp_link)

  pbp_html <- read_html(pbp_url)

  pbp_tables <- html_table(pbp_html) |>
    bind_rows()

  if (nrow(pbp_tables) < 1) {
    message('issue with pbp_tables for id ', id, ', adding to error_list and moving on...')
    error_list[[length(error_list) + 1]] <- id
    next
  }

  output <- list(box=box_tables,
                 pbp=pbp_tables)

  output_path <- paste0('ncaam_contest_', id, '.json')
  write_json(output, output_path)
  message('wrote ', output_path)
  success_list[[length(success_list) + 1]] <- id

}

