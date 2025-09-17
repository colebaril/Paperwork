library(shiny)
library(jsTreeR)
library(tidyverse)
library(here)
library(janitor)
library(readxl)
library(openxlsx)
library(pdftools)

# Initialize Functions ----

create_project_folders <<- function(group, program) {
  # Define the paths for the required folders
  message("Checking file structure before document generation...")
  raw_folder <- here("Raw")
  tmp_folder <- here("tmp")
  group_folder <- here(group)
  program_folder <- here(group, program)


  # Create the folders if they don't already exist
  if (!dir.exists(raw_folder)) {
    dir.create(raw_folder)
    message("Raw folder created.")
  } else {
    message("Raw folder already exists.")
  }

  if (!dir.exists(tmp_folder)) {
    dir.create(tmp_folder)
    message("tmp folder created.")
  } else {
    message("tmp folder already exists.")
  }

  if (!dir.exists(group_folder)) {
    dir.create(group_folder)
    message(paste(group, "folder created."))
  } else {
    message(paste(group, "folder already exists."))
  }

  if (!dir.exists(program_folder)) {
    dir.create(program_folder)
    message(paste(program, " folder created inside ", here(group)))
  } else {
    message(paste(program, " folder already exists inside group."))
  }


}

generate_file_packages <<- function(mail_merge_path,
                                   instructions_path,
                                   data_submission_instructions_path = NA,
                                   spims_disclaimer_path,
                                   full_dsf_path,
                                   group, program, session,
                                   bilingual = FALSE) {


  # Check for required file structure

  if (!file.exists(here("/Raw/"))) {
    stop(paste0(here(), "/Raw/", " does not exist. Please ensure a \"Raw\" folder is created in your working directory."))
  }

  if (!file.exists(here(paste0("/", group, "/")))) {
    stop(paste0(here(), "/", group, "/", " does not exist. Please ensure a \"/", group,  "/\" folder is created in your working directory."))
  }

  if(bilingual == FALSE) {

    df <- read_excel(here(mail_merge_path)) %>%
      clean_names() %>%
      select(lab_code, language_preference) %>%
      arrange(lab_code) %>%
      mutate(page_number = row_number()) %>%
      suppressMessages()

    number_sites <- nrow(df)

  } else if(bilingual == TRUE) {

    message("Group will be processed as a bilingual country.")

    df <- read_excel(here(mail_merge_path)) %>%
      clean_names() %>%
      select(lab_code, language_preference) %>%
      arrange(lab_code) %>%
      group_by(language_preference) %>%
      mutate(page_number = row_number()) %>%
      suppressMessages()

    number_sites <- nrow(df)
  }

  for(lab in df$lab_code) {

    df_lab <- df %>%
      filter(lab_code == lab)

    page_num <- df_lab$page_number

    lab_code <- df_lab$lab_code


    message(paste0("Extracting data for ", lab_code, "..."))



    # Handling sites with both languages
    if(df_lab$language_preference == "fr") {

      instructions_path <- gsub(".pdf", "", instructions_path)
      instructions_path <- gsub("_FR", "", instructions_path)
      instructions_path <- paste0(instructions_path, "_FR.pdf")
    } else {
      instructions_path <- gsub(".pdf", "", instructions_path)
      instructions_path <- gsub("_FR", "", instructions_path)
      instructions_path <- paste0(instructions_path, ".pdf")
    }

    if(df_lab$language_preference == "fr") {
      full_dsf_path <- gsub(".pdf", "", full_dsf_path)
      full_dsf_path <- gsub("_FR", "", full_dsf_path)
      full_dsf_path <- paste0(full_dsf_path, "_FR.pdf")
    } else {
      full_dsf_path <- gsub(".pdf", "", full_dsf_path)
      full_dsf_path <- gsub("_FR", "", full_dsf_path)
      full_dsf_path <- paste0(full_dsf_path, ".pdf")
    }

    if(df_lab$language_preference == "fr") {
      data_submission_instructions_path <- gsub(".pdf", "", data_submission_instructions_path)
      data_submission_instructions_path <- gsub("_FR", "", data_submission_instructions_path)
      data_submission_instructions_path <- paste0(data_submission_instructions_path, "_FR.pdf")
    } else {
      data_submission_instructions_path <- gsub(".pdf", "", data_submission_instructions_path)
      data_submission_instructions_path <- gsub("_FR", "", data_submission_instructions_path)
      data_submission_instructions_path <- paste0(data_submission_instructions_path, ".pdf")
    }

    pdf_subset(full_dsf_path,
               pages = page_num, output = "tmp/subset_dsf_temp.pdf")

    if(is.na(data_submission_instructions_path)) {
      pdf_combine(c("tmp/subset_dsf_temp.pdf",
                    instructions_path,
                    spims_disclaimer_path),
                  output = paste0(group, "/",
                                  program, "/", lab_code, " QASI-", program, "-", session, " Paperwork", ".pdf"))

    } else {
      pdf_combine(c("tmp/subset_dsf_temp.pdf",
                    instructions_path,
                    data_submission_instructions_path,
                    spims_disclaimer_path),
                  output = paste0(group, "/",
                                  program, "/", lab_code, " QASI-", program, "-", session, " Paperwork", ".pdf"))
    }


    message(paste0("Document packaged created for ", lab_code, "."))
  }

  message(paste0("QASI-", program, " document packages successfully created for ", group, " with ", number_sites, " sites."))

  message(paste0("Document packages have been saved here: ", here(), "/", group, "/", program, "/"))



}

# CSS for Tree ----

css <- HTML("
  .flexcol {
    display: flex;
    flex-direction: column;
    width: 100%;
    margin: 0;
  }
  .stretch {
    flex-grow: 1;
    height: 1px;
  }
  .topright {
    position: fixed;
    bottom: 0;
    right: 15px;
    min-width: calc(50% - 15px);
  }
")

# UI ----

ui <- fixedPage(
  tags$head(
    tags$style(css)
  ),
  class = "flexcol",
  
  br(),
  
  fixedRow(
    column(
      width = 6,
      
      ## File Inputs ----
      
      fileInput("mail_merge", "Mail Merge (Excel input; mandatory)",
                accept = c(".xls", ".xlsx"),
                multiple = FALSE),
      
      fileInput("instructions", "Instructions for Participants (PDF; mandatory)",
                accept = ".pdf"),
      
      fileInput("data_submission_instructions", "Data Submission Instructions (PDF; optional)",
                accept = ".pdf", placeholder = "NA if empty"),
      
      fileInput("ip_letter", "IP Letter (PDF; mandatory)",
                accept = ".pdf"),
      
      fileInput("data_submission_forms", "Data Submission Forms (All Sites) (PDF; mandatory)",
                accept = ".pdf"),
      
      textInput("group", "Group"),
      textInput("program", "Program"),
      textInput("session", "Session"),
      
      checkboxInput("bilingual", "Is the group bilingual?", value = FALSE),
      
      actionButton("submit", "Generate Paperwork")
    ),
    column(
      width = 3,
      treeNavigatorUI("explorer")
    ),
    column(
      width = 3,
      tags$div(class = "stretch"),
      tags$fieldset(
        class = "bottomright",
        tags$legend(
          tags$h1("Selections:", style = "float: left;"),
          downloadButton(
            "dwnld",
            class = "btn-primary btn-lg",
            style = "float: right;",
            icon  = icon("save")
          )
        ),
        verbatimTextOutput("selections")
      )
    )
  )
)

server <- function(input, output, session){
  
  

  

observeEvent(input$submit,{
  print("test")
  create_project_folders(group = input$group, program = input$program)
  
  # print("Submit clicked")
  # req(input$mail_merge, input$instructions, input$ip_letter, input$data_submission_forms)
  # 
  # mail_merge_path <<- input$mail_merge$datapath
  # instructions_path <<- input$instructions$datapath
  # data_submission_instructions_path <<- ifelse(is.null(input$data_submission_instructions), NA, input$data_submission_instructions$datapath)
  # spims_disclaimer_path <<- input$ip_letter$datapath
  # full_dsf_path <<- input$data_submission_forms$datapath
  # 
  # group <<- input$group
  # program <<- input$program
  # session <<- input$session
  # bilingual <<- input$bilingual
  # 
  # result <- tryCatch({
  #   generate_file_packages(mail_merge_path, instructions_path, data_submission_instructions_path,
  #                          spims_disclaimer_path, full_dsf_path, group, program, session, bilingual)
  #   "File package generation successful."
  # }, error = function(e) {
  #   paste("Error:", e$message)
  # })
  
  Paths <<- treeNavigatorServer(
    "explorer", rootFolder = getwd(),
    search = list( # (search in the visited folders only)
      show_only_matches  = TRUE,
      case_sensitive     = TRUE,
      search_leaves_only = TRUE
    )
  )
  
  output[["selections"]] <- renderPrint({
    cat(Paths(), sep = "\n")
  })
  

})
  
  output[["dwnld"]] <- downloadHandler(
    filename = "myfiles.zip",
    content = function(file){
      zip(file, files = Paths())
    }
  )

}

shinyApp(ui, server)
