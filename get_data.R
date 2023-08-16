# Collect historical 10-minute average PM 2.5 PurpleAir data, saving as CSV, 
# one file for each station. Run daily (e.g., at midnight) as a scheduled task.
# 
# Example of a scheduled task using "cron" utility with this "crontab" entry:
# 00 00 * * * (cd /path/to/project; /usr/bin/Rscript --vanilla get_data.R)

# -----
# Setup
# -----

# Load packages, installing as needed
if (!requireNamespace("pacman", quietly = TRUE)) install.packages('pacman')
pacman::p_load(here, dplyr, readr, stringr, lubridate, httr, rvest, jsonlite)

# Initialize variables
site <- 'https://map.purpleair.com'
user_agent_str <- "Mozilla/5.0"
n_retries <- 20
sleep_secs <- 5
average_min <- 10
# "10 minute average history maximum time span is three (3) days."
days_history <- 2
ids <- as.character(c(178571, 13665, 164131, 107952, 165227, 10168, 
                      162961, 102818, 178569, 116223, 164113, 10188))
fields <- c("pm2.5_atm_a", "pm2.5_atm_b", "humidity_a", "humidity_b", 
            "temperature_a", "temperature_b")
data_dir <- here("data")
data_csv_file_suffix <- "_pm25.csv"

# ----------------
# Define functions
# ----------------

# Format time (in ISO 8601 format as expected by PurpleAir)
format_time <- function(time_stamp) {
  format_ISO8601(x = time_stamp, usetz = TRUE) %>% 
    str_replace('-(\\d\\d)(\\d\\d)$', '-\\1:\\2')
}

# Get token (and store the session ID in a cookie)
get_token <- function(site, referer, user_agent_str) {
  # Reset httr handle (and cookies) for site
  handle_reset(site)
  
  # Get session ID (stored in a cookie)
  url <- parse_url(site)
  resp <- GET(build_url(url), user_agent(user_agent_str))
  
  # Get token
  url$path <- 'token'
  url$query <- list('version' = "2.0.12")
  GET(build_url(url), user_agent(user_agent_str), 
      add_headers('Referer' = referer,
                  'Accept' = 'text/plain; charset=utf-8')) %>% 
    read_html() %>% html_text()
}

# Get sensor info (in order to get the "read key" for a station)
get_sensor_info <- function(site, referer, id, token, user_agent_str) {
  url <- parse_url(site)
  url$path <- paste0('v1/sensors/', id)
  fields <- c('sensor_index', 'name', 'location_type', 'latitude', 'longitude', 
              'altitude', 'channel_state', 'channel_flags', 'confidence', 
              'primary_key_a')
  fields_str <- paste(fields, collapse = ",")
  url$query <- list('token' = token, 'fields' = fields_str)
  GET(build_url(url), user_agent(user_agent_str), 
      add_headers('Referer' = referer, 
                  'Accept' = 'application/json; charset=utf-8'))
}

# Get data (for a station)
get_data <- function(site, referer, token, read_key, id, fields, 
                     average_min, days_history, user_agent_str) {
  current_time <- now()
  start_time <- current_time - days(days_history)
  start_timestamp <- start_time %>% format_time()
  end_timestamp <- current_time %>% format_time()
  fields_str <- paste(fields, collapse = ",")
  url <- parse_url(site)
  url$path <- paste0('v1/sensors/', id, '/history/csv')
  url$query <- list('fields' = fields_str, 
                    'read_key' = read_key, 
                    'start_timestamp' = start_timestamp, 
                    'end_timestamp' = end_timestamp, 
                    'average' = average_min, 
                    'token' = token)
  GET(build_url(url), user_agent(user_agent_str), 
      add_headers('Referer' = referer, 
                  'Accept' = 'text/csv; charset=utf-8'))
}

# Save results (to CSV)
save_results <- function(df, id, data_dir, data_csv_file_suffix) {
  fp <- here(data_dir, paste0(id, data_csv_file_suffix))
  if (!file.exists(fp)) {
    write_csv(x = df, file = fp)
  } else {
    write_csv(x = df, file = fp, col_names = FALSE, append = TRUE)
  }
}

# Get description
get_description <- function(resp) {
  read_html(resp$content) %>% html_text() %>% parse_json() %>% .$description
}

# ------------
# Main routine
# ------------

# Create data folder
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Get token
referer <- site
token <- get_token(site, referer, user_agent_str)
Sys.sleep(sleep_secs)

# Create an empty list to store sensor information
sensor_info <- list()

for (id in ids) {
  # Get read key
  resp <- get_sensor_info(site, referer, id, token, user_agent_str)
  read_key <- parse_json(resp)$sensor$primary_key_a
  
  # If read key is NULL, get new token and try again (up to n_retries times)
  n <- 0
  while(is.null(read_key) & n < n_retries) {
    n <- n + 1
    warning(paste0("Retry #", n, ": getting token and read key for ", id, "."))
    token <- get_token(site, referer, user_agent_str)
    Sys.sleep(sleep_secs)
    resp <- get_sensor_info(site, referer, id, token, user_agent_str)
    read_key <- parse_json(resp)$sensor$primary_key_a
  }
  
  if(!is.null(read_key)) {
    sensor_info[[id]] <- parse_json(resp) %>% .$sensor %>% as_tibble()
    resp <- get_data(site, referer, token, read_key, id, fields, 
                     average_min, days_history, user_agent_str)
    if (resp$status_code == 200) {
      # Read results into a dataframe and save as CSV
      csv <- rawToChar(resp$content)
      df <- read_csv(csv, show_col_types = FALSE, na = c("NA", "null")) %>% 
        arrange(sensor_index, time_stamp)
      # Note: The timezone in time_stamp is UTC ("Z"). 
      #       To see time_stamp values adjusted for your local timezone, use: 
      # df %>% mutate(time_stamp = as_datetime(time_stamp, tz = Sys.timezone()))
      save_results(df, id, data_dir, data_csv_file_suffix)
      Sys.sleep(sleep_secs)
    } else {
      stop(paste0("Cannot get data for ", id, ". ", get_description(resp)))
    }
  } else {
    stop(paste0("Cannot get read key for ", id, ". ", get_description(resp)))
  }
}

# Write sensor information to a CSV file
sensor_info_df <- bind_rows(sensor_info)
if (nrow(sensor_info_df) > 0) {
  write_csv(sensor_info_df, here(data_dir, "sensor_info.csv"))
}

# Show warnings
warnings()
