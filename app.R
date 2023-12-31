#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
#   Team Members:
#   Zihan Wang, Sara Shen, Kelly Wang.
#

library(shiny)

source("ct-util.R")
max_num_studies = 1000

# Define UI for application that draws a histogram
ui <- fluidPage(
  
  # Application title
  titlePanel("Clinical Trials Query"),
  
  # Sidebar with a slider input for number of bins 
  sidebarLayout(
    position = 'left',
    sidebarPanel(
      textInput("brief_title_kw", h3("Brief Title Keywords")),
      ################ Feature 2:search by Conditions.#################
      ################ Apply to first 3 tabs. #################
      textInput("condition_kw", h3("Condition Names")),
      # Q3: Add a drop-down on sponsor type
      selectInput("source_class", 
                  label = h3("Sponsor Type"),
                  choices = list("Federal" = "FED", 
                                 "Individual" = "INDIV", 
                                 "Industry" = "INDUSTRY", 
                                 "Network" = "NETWORK", 
                                 "NTH" = "NTH",
                                 "Other" = "OTHER", 
                                 "Other gov" = "OTHER_GOV", 
                                 "Unknown" = "Unknown"),
                  multiple = TRUE),
      ################ Feature 4:search by Outcome Types.#################
      selectInput("interventionType", 
                  label = h3("Choose an Intervention"),
                  choices = c(unique(interventions_local$intervention_type))),
    ),
    
    # Show a plot of the generated distribution
    mainPanel(
      tabsetPanel(
        type = "tabs",
        tabPanel("Phase", plotOutput("phase_plot")),
        tabPanel("Concurrent", plotOutput("concurrent_plot")),
        tabPanel("Conditions", plotOutput("condition_plot")),
        tabPanel("World Map", 
                 ######### Feature 6: Add dropdown for selecting a country ########
                 selectInput("world_map_country", "Select a country:", choices = names_countries),
                 textOutput("country_info"),
                 plotOutput("world_map_plot")
        ),
        tabPanel("Outcome Types", plotOutput("outcomePieChart")), #### feature 4
        tabPanel("Condition Bar Plot", plotOutput("conditionsPlot")), #### feature 3
        tabPanel("Word Cloud", plotOutput("world_cloud_plot")), #### feature 5
      ),
      dataTableOutput("trial_table")
    )
  )
)


# Define server logic required to draw a histogram
server <- function(input, output) {
  # react to user input
  # when user input change, get_studies will be updated, this will trigger other functions
  get_studies = reactive({
    if (input$brief_title_kw != "") {
      si = input$brief_title_kw |>
        strsplit(",") |>
        unlist() |>
        trimws()
      ret = query_kwds(studies, si, "brief_title", match_all = TRUE)
    } else {
      ret = studies
    }
    
    # if input is NULL, return all values
    if (!is.null(input$source_class)) {
      ret = ret |> 
        filter(source_class %in% !!input$source_class) 
    }
    ret |>
      head(max_num_studies) |>
      collect()
    
  })
  
  ############## Feature 2: Conditions keyword input. ##############
  ######### Add a conditions input to search for conditions ########
  get_conditions = reactive({
    if (input$condition_kw != "") {
      si = input$condition_kw |>
        strsplit(",") |>
        unlist() |>
        trimws()
      ret2 = query_kwds(conditions, si, "name", match_all = FALSE)
    } else {
      ret2 = conditions
    }
    ret2 |>
      collect()
  })
  
  ############# phase_plot
  output$phase_plot = renderPlot({
    studies <- get_studies()
    conditions <- get_conditions()
    
    studies |>
      left_join(conditions, by="nct_id") |>
      plot_phase_histogram()
  })
  ############# concurrent_plot
  output$concurrent_plot = renderPlot({
    studies <- get_studies()
    conditions <- get_conditions()
    
    studies |>
      left_join(conditions, by="nct_id") |>
      select(start_date, completion_date) |>
      get_concurrent_trials() |>
      ggplot(aes(x = date, y = count)) +
      geom_line() +
      xlab("Date") +
      ylab("Count") + 
      theme_bw()
  })
  
  ############# Condition_plot
  output$condition_plot = renderPlot({
    ############## Feature 2: Update on Condition.##############
    study = get_studies()
    condition = get_conditions()
    condition_data <- get_condition_histogram(study, condition) 
    
    ggplot(condition_data, aes(x=name, y=n)) +
      geom_col()+
      theme_bw()+
      xlab("Condition")+
      ylab("Count") + 
      title("Top 6 Conditions by Condition Name") + 
      theme(axis.text.x = element_text(angle = 30, hjust = 1))
    
  })
  
  ############# Feature 1: World Map plot.##########################
  output$world_map_plot = renderPlot({
    selected_country <- input$world_map_country 
    get_studies()|>
      plot_country_map()
  })
  
  ############# Feature 3: Intervention-Condition mapping.##########
  output$conditionsPlot <- renderPlot({
    get_conditions_for_intervention_type(input$interventionType)
  })
  
  
  ############## Feature 4: Pie Charts for outcomes.##############
  output$outcomePieChart <- renderPlot({
    interventionTypes <- input$interventionType
    get_outcome_pie_for_intervention(interventionTypes)
  })

  
  ######### Feature 5: Add dropdown for selecting a country ########
  output$country_info <- renderText({
    selected_country <- input$world_map_country
    selected_data <- filtered_countries %>%
      filter(name %in% selected_country)
    paste("Country: ", selected_country, "|",
          "Number of Trials: ", selected_data$ID_count[1], "\n")
  })


  ############## Feature 6: Word cloud of conditions.##############
  output$world_cloud_plot = renderPlot({
    studies <- get_studies()
    conditions <- get_conditions()
    
    word_cloud(studies, conditions)
  })
  
}
# Run the application 
shinyApp(ui = ui, server = server)
