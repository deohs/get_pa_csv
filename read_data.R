# Read CSV files downloaded from Purple Air into a single data frame 
# and then produce a scatter plot to view the data

# Load packages, installing as needed
if (!requireNamespace("pacman", quietly = TRUE)) install.packages('pacman')
pacman::p_load(here, dplyr, tidyr, readr, purrr, ggplot2)

# Define path to data files
data_dir <- here("data")

# Import CSV files into a single data frame, sort and remove duplicates
fp <- list.files(data_dir, "*_pm25.csv", full.names = TRUE, recursive = TRUE)
df <- map_df(fp, read_csv, col_types = 'Tcnnnn', show_col_types = FALSE,
             locale = locale(tz = Sys.timezone())) %>% 
  arrange(sensor_index, time_stamp) %>% 
  distinct(sensor_index, time_stamp, .keep_all = TRUE)

# Reshape data for plotting
df_long <- df %>% 
  select(time_stamp, sensor_index, pm2.5_atm_a, temperature_a, humidity_a) %>% 
  pivot_longer(c(-time_stamp, -sensor_index), 
               names_to = "variable", values_to = "value")

# Plot data
cbPalette <- c("#56B4E9", "#E69F00", "#CC79A7")
g <- ggplot(df_long, aes(time_stamp, value, color = variable)) + 
  geom_line(linewidth = 0.5, alpha = 0.7) + 
  facet_wrap(. ~ sensor_index, nrow = 3) + 
  scale_colour_manual(values = cbPalette) + theme_linedraw() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1))

# Create images folder
images_dir <- here("images")
dir.create(images_dir, showWarnings = FALSE, recursive = TRUE)

# Save plot
ggsave(here(images_dir, "pa_data.png"), plot = g, width = 8, height = 5)
