# Plot a map of a selection of PurpleAir sensor locations.

# This script uses ggmap. Here is the citation:
#
#   D. Kahle and H. Wickham. ggmap: Spatial Visualization with ggplot2. The R
#   Journal, 5(1), 144-161. URL
#   http://journal.r-project.org/archive/2013-1/kahle-wickham.pdf

# Clear workspace of all objects and unload all extra (non-base) packages.
rm(list = ls(all = TRUE))
if (!is.null(sessionInfo()$otherPkgs)) {
  res <- suppressWarnings(
    lapply(paste("package:", names(sessionInfo()$otherPkgs), sep = ""),
           detach,
           character.only = TRUE, unload = TRUE, force = TRUE
    )
  )
}

# Load packages.
if (!suppressPackageStartupMessages(require(pacman))) {
  install.packages("pacman", repos = "http://cran.us.r-project.org")
}
pacman::p_load(here, readr, dplyr, tidyr, maps, stringr, ggmap, ggrepel)

# Initialize variables
data_dir <- here("data")
images_dir <- here("images")
sensor_info_path <- here(data_dir, "sensor_info.csv")
most_recent_path <- here("data", "most_recent.csv")

# Create images folder
dir.create(images_dir, showWarnings = FALSE, recursive = TRUE)

# Get PurpleAir sensor information
if (file.exists(sensor_info_path)) {
  sensor_info <- read_csv(sensor_info_path, show_col_types = FALSE) %>% 
    mutate(location_type = 
             factor(location_type, labels = c('Outdoor', 'Indoor'))) %>% 
    mutate(label = 
             paste0(sensor_index, ": ", 
                    str_remove(str_replace_all(name, '_', ' '), 
                                '^(?:Indoor )?MV Clean Air Ambassador ?@ '),
                    ' (', location_type, ')'))
} else {
  stop(paste0("Can't read ", sensor_info_path, "!"))
}

# Get PurpleAir most recent data
if (file.exists(most_recent_path)) {
  most_recent <- read_csv(most_recent_path, col_types = 'nTnnn', 
                          show_col_types = FALSE,
                          locale = locale(tz = Sys.timezone()))
} else {
  stop(paste0("Can't read ", most_recent_path, "!"))
}

# Merge datasets
sensor_info <- sensor_info %>% left_join(most_recent, by = c('sensor_index'))
sensor_info <- sensor_info %>% 
  mutate(label = paste0(label, '\npm2.5_atm_a = ', round(pm2.5_atm_a)))
most_recent_time_stamp <- max(sensor_info$time_stamp)

# Create bounding box.
bbox <- make_bbox(longitude, latitude, sensor_info, f = .4)

# Plot map.
stamen_basemap <- get_stamenmap(bbox, zoom = 10, maptype = "terrain")
g <- ggmap(ggmap = stamen_basemap) + 
  geom_jitter(mapping = aes(x = longitude, y = latitude), data = sensor_info, 
             color = 'red', size = 2, alpha = 0.5, width = 0.008) +
  geom_label_repel(data = sensor_info, 
                   mapping = aes(x = longitude, y = latitude, label = label),
                   size = 1.75, vjust = .5, hjust = .5) +
  theme_void() +
  labs(x = NULL, y = NULL, fill = NULL,
       title = "PurpleAir Sensor Locations", 
       subtitle = paste("Most recent data as of:", 
                        format(most_recent_time_stamp, "%a %b %d %X %Y %Z"))) + 
  theme(plot.title = element_text(size = 10), 
        plot.subtitle = element_text(size = 8))

# Save the map as a JPG file.
image_path <- here(images_dir, "sensor_map.jpg")
ggsave(filename = image_path, width = 8, height = 13.5, scale = 0.5)

