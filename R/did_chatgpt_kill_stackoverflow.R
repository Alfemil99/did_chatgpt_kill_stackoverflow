# Load packages
library(tidyverse)
library(lubridate)
library(janitor)
library(scales)


# Read CSV files
questions <- read.csv("../data/raw/stackoverflow_questions_monthly.csv") |>
  clean_names() |>
  mutate(date = make_date(year, month, 1))

metrics <- read.csv("../data/raw/stackoverflow_question_metrics_monthly.csv") |>
  clean_names() |>
  mutate(
    date = make_date(year, month, 1),
    unanswered_ratio = unanswered_questions / questions,
    accepted_ratio = accepted_answer_questions / questions
    )

tags <- read.csv("../data/raw/stackoverflow_beginner_tags_monthly.csv") |>
  clean_names() |>
  mutate(date = make_date(year, month, 1))

survey <- read_csv("../data/raw/stackoverflow_ai_survey_summary.csv") |>
  clean_names()

trends <- read_csv(
  "../data/raw/google_trends_chatgpt.csv",
  skip = 2,
  col_names = FALSE
) |>
  rename(
    date = X1,
    chatgpt_interest = X2
  ) |>
  mutate(
    date = as.Date(date),
    chatgpt_interest = as.numeric(chatgpt_interest)
  )

# Shared theme
theme_alf_article <- function(base_size = 16) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(face = "bold", size = base_size + 8),
      plot.subtitle = element_text(size = base_size, margin = margin(b = 14)),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size - 2, color = "grey25"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey88"),
      plot.margin = margin(16, 20, 16, 16)
    )
}

# Plots
# Monthly Stack Overflow Questions
chatgpt_date <- as.Date("2022-11-30")

p_questions <- ggplot(questions, aes(x = date, y = questions)) +
  geom_line(linewidth = 1.25, color = "grey10") +
  geom_vline(
    xintercept = chatgpt_date,
    linetype = "dashed",
    linewidth = 0.8,
    color = "grey10"
  ) +
  annotate(
    "text",
    x = chatgpt_date + months(2),
    y = max(questions$questions, na.rm = TRUE) * 0.95,
    label = "ChatGPT released",
    hjust = 0,
    size = 4.5,
    fontface = "bold"
  ) +
  scale_y_continuous(labels = comma) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "Monthly Stack Overflow Questions",
    subtitle = "Question volume declined sharply after late 2022",
    x = NULL,
    y = "Questions per month"
  ) +
  theme_alf_article()

ggsave(
  "../figures/raw/figure_01_questions_per_month.svg",
  p_questions,
  width = 10,
  height = 5,
  dpi = 300
)

# Before After Summary
questions_summary <- questions |> 
  mutate(period = if_else(date < chatgpt_date, "Before ChatGPT", "After ChatGPT")) |> 
  group_by(period) |> 
  summarise(avg_questions = mean(questions, na.rm = TRUE), .groups = "drop") |>
  mutate(
    period = factor(period, levels = c("Before ChatGPT", "After ChatGPT")),
    label = comma(round(avg_questions))
  )

p_before_after <- ggplot(questions_summary, aes(x = period, y = avg_questions)) +
  geom_col(width = 0.58, fill = "grey35") +
  geom_text(aes(label = label), vjust = -0.45, size = 6, fontface = "bold") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Average Monthly Questions Before and After ChatGPT",
    subtitle = "Average monthly question volume fell from 140k to 33k",
    x = NULL,
    y = "Average questions per month"
  ) +
  theme_alf_article()

ggsave(
  "../figures/raw/figure_02_before_after_questions.png",
  p_before_after,
  width = 10,
  height = 5,
  dpi = 300
)

pre <- questions_summary$avg_questions[questions_summary$period == "Before ChatGPT"]
post <- questions_summary$avg_questions[questions_summary$period == "After ChatGPT"]

percent_change <- (post - pre) / pre * 100
percent_change

# Beginner Tags on Stack Overflow
tags_long <- tags |>
  select(
    date,
    python_questions,
    javascript_questions,
    html_questions,
    css_questions,
    java_questions
  ) |>
  pivot_longer(
    cols = -date,
    names_to = "tag",
    values_to = "questions"
  ) |>
  mutate(
    tag = recode(
      tag,
      python_questions = "Python",
      javascript_questions = "JavaScript",
      html_questions = "HTML",
      css_questions = "CSS",
      java_questions = "Java"
    )
  )

p_tags <- ggplot(tags_long, aes(x = date, y = questions, color = tag)) +
  geom_line(linewidth = 1.15) +
  geom_vline(
    xintercept = chatgpt_date,
    linetype = "dashed",
    linewidth = 0.8,
    color = "grey10"
  ) +
  scale_y_continuous(labels = comma) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "Beginner Tag Activity on Stack Overflow",
    subtitle = "Common beginner tags declined together after late 2022",
    x = NULL,
    y = "Questions per month",
    color = NULL
  ) +
  theme_alf_article() +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 14)
  )

ggsave(
  "../figures/raw/figure_03_beginner_tags.png",
  p_tags,
  width = 10,
  height = 5.8,
  dpi = 300
)

# Stack Overflow AI adoption survey (2023–2025)
p_survey <- ggplot(survey, aes(x = year, y = ai_usage_percent)) +
  
  # Main line
  geom_line(
    linewidth = 1.4,
    color = "#ff2f4f"
  ) +
  
  # Points
  geom_point(
    size = 4,
    color = "#ff2f4f"
  ) +
  
  # Labels above points
  geom_text(
    aes(label = paste0(ai_usage_percent, "%")),
    vjust = -1,
    size = 5,
    fontface = "bold"
  ) +
  
  # X-axis formatting
  scale_x_continuous(
    breaks = survey$year
  ) +
  
  # Y-axis formatting
  scale_y_continuous(
    labels = percent_format(scale = 1),
    limits = c(50, 100)
  ) +
  
  # Titles
  labs(
    title = "AI Tool Adoption Among Developers",
    subtitle = "Stack Overflow Developer Survey 2023–2025",
    x = NULL,
    y = "Developers using or planning to use AI tools"
  ) +
  
  # Clean minimal theme
  theme_minimal(base_size = 18) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 26
    ),
    
    plot.subtitle = element_text(
      size = 16,
      margin = margin(b = 15)
    ),
    
    axis.text = element_text(
      size = 14
    ),
    
    axis.title.y = element_text(
      size = 16
    ),
    
    panel.grid.minor = element_blank()
  )
ggsave(
  "../figures/raw/figure_04_Ai_adoption.png",
  p_survey,
  width = 10,
  height = 5.8,
  dpi = 300
)

# Google Trends: ChatGPT search interest

p_trends <- ggplot(trends, aes(x = date, y = chatgpt_interest)) +
  geom_line(linewidth = 1.25, color = "grey10") +
  geom_vline(
    xintercept = as.Date("2022-11-30"),
    linetype = "dashed",
    linewidth = 0.8,
    color = "grey10"
  ) +
  annotate(
    "text",
    x = as.Date("2023-02-01"),
    y = 95,
    label = "ChatGPT released",
    hjust = 0,
    size = 4.5,
    fontface = "bold"
  ) +
  scale_y_continuous(limits = c(0, 100)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = 'Global Search Interest for "ChatGPT"',
    subtitle = "Relative Google Trends index, not absolute search volume",
    x = NULL,
    y = "Relative search interest"
  ) +
  theme_alf_article()

ggsave(
  "../figures/raw/figure_05_google_trends_chatgpt.png",
  p_trends,
  width = 10,
  height = 5,
  dpi = 300
)
