

server <- function(input, output, session) {

  df <- .aecay.df %>% arrange(desc(epg))
  esc <- .aecay.esc %>% arrange(desc(Nom_municipi))
  evo <- .aecay.evo

  # Colour scale based input
  col <- reactive({
    if (input$colour == 1) {
      col <- "clean_epg"
    } else if (input$colour == 2) {
      col <- "clean_taxa_incidencia_14d"
    } else if (input$colour == 3) {
      col <- "clean_rho"
    } else if (input$colour == 4) {
      col <- "harvard"
    }
  })

  pal <- reactive({
    if (input$colour == 1) {
      pal <-
        colorNumeric(palette = palette,
                     domain = df[["clean_epg"]],
                     reverse = rev)
    } else if (input$colour == 2) {
      pal <-
        colorNumeric(palette = palette,
                     domain = df[["clean_taxa_incidencia_14d"]],
                     reverse = rev)
    } else if (input$colour == 3) {
      pal <-
        colorNumeric(palette = palette,
                     domain = df[["clean_rho"]],
                     reverse = rev)
    } else if (input$colour == 4) {
      pal <-
        colorFactor(palette = "RdYlGn",
                    domain = df[["harvard"]],
                    reverse = T)
    }

  })
  # FIXME: this is very stupid
  tit <- reactive({
    if (input$colour == 1) {
      tit <- "Risc de rebrot*"
    } else if (input$colour == 2) {
      tit <- "Taxa de positius*"
    } else if (input$colour == 3) {
      tit <- "Rho*"
    } else if (input$colour == 4) {
      tit <- "Guia de Harvard"
    }
  })

  # School type based input
  clean_schools <- reactive({
    if (is.null(input$school_status)) {
      clean_schools <- esc[esc$Codi_centre == "1",]
    } else {
      vals <- NULL
      if (1 %in% input$school_status) {
        vals <- c(vals, "Normalitat")
      }
      if (2 %in% input$school_status) {
        vals <- c(vals, "Grups en quarantena")
      }
      if (3 %in% input$school_status) {
        vals <- c(vals, "Tancada")
      }
      if (4 %in% input$school_status) {
        vals <- c(vals, "Desconnegut")
      }
      
      clean_schools <- esc[esc$Estat %in% vals | esc$Codi_centre == "1",]
      
    }
  })


  # Output
  output$mymap <- renderLeaflet({
    
    orb <- clean_schools()$Codi_centre == "1"
    norm <- clean_schools()$Estat == "Normalitat"
    q <- clean_schools()$Estat == "Grups en quarantena"
    norm_esc <- clean_schools()[norm | orb, ]
    q_esc <- clean_schools()[q | orb, ]
    if (length(which(!(norm | q)))) {
      t_esc <- clean_schools()[which(!(norm | q)), ]
    } else {
      t_esc <- clean_schools()[clean_schools()$Codi_centre == "1", ]  # FIXME
    }
    
    
    withProgress(
    leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
      addProviderTiles(
        provider = providers$CartoDB.Voyager,
        options = providerTileOptions(updateWhenZooming = FALSE,
                                      updateWhenIdle = TRUE)
      ) %>%
      setView(lat = 41.7,
              lng = 2,
              zoom = 8) %>%
      addPolygons(
        data = df,
        weight = 2,
        smoothFactor = 0.2,
        fillOpacity = .7,
        color = ~ pal()(df[[col()]]),
        label = df$Municipi,
        popup = mun_popup(df),
        popupOptions = popup_options()
      ) %>%
      addLegend(
        "bottomright",
        pal = pal(),
        values = df[[col()]],
        title = tit(),
        opacity = .8
      ) %>%
      addAwesomeMarkers(
        clusterOptions = markerClusterOptions(
          disableClusteringAtZoom=13,
          iconCreateFunction=JS("function (cluster) {    
    var childCount = cluster.getChildCount(); 
    var c = ' marker-cluster-custom-green';  
    return new L.DivIcon({ html: '<div><span>' + childCount + '</span></div>', className: 'marker-cluster' + c, iconSize: new L.Point(40, 40) });

  }")
          ),
        layerId = as.character(norm_esc$Codi_centre),
        as.numeric(norm_esc$Coordenades_GEO_X),
        as.numeric(norm_esc$Coordenades_GEO_Y),
        popup = esc_popup(norm_esc),
        popupOptions = popup_options(),
        label = as.character(norm_esc$Denominacio_completa),
        icon = get_icons(norm_esc)
      ) %>%
      addAwesomeMarkers(
        clusterOptions = markerClusterOptions(
          disableClusteringAtZoom=13,
          iconCreateFunction=JS("function (cluster) {    
    var childCount = cluster.getChildCount(); 
    var c = ' marker-cluster-custom-orange';  
    return new L.DivIcon({ html: '<div><span>' + childCount + '</span></div>', className: 'marker-cluster' + c, iconSize: new L.Point(40, 40) });

  }")),
        layerId = as.character(q_esc$Codi_centre),
        as.numeric(q_esc$Coordenades_GEO_X),
        as.numeric(q_esc$Coordenades_GEO_Y),
        popup = esc_popup(q_esc),
        popupOptions = popup_options(),
        label = as.character(q_esc$Denominacio_completa),
        icon = get_icons(q_esc)
      ) %>%
      addAwesomeMarkers(
        layerId = as.character(t_esc$Codi_centre),
        as.numeric(t_esc$Coordenades_GEO_X),
        as.numeric(t_esc$Coordenades_GEO_Y),
        popup = esc_popup(t_esc),
        popupOptions = popup_options(),
        label = as.character(t_esc$Denominacio_completa),
        icon = get_icons(t_esc)
      ) %>%
      addMarkers(
        lat = 41.0,
        lng = 2.1,
        icon =   icons(
          iconUrl = file.path(getwd(), "icons", "logo_icon.png"),
          iconWidth = 40,
          iconHeight = 40,
          iconAnchorX = 40 / 2,
          iconAnchorY = 40 / 2
        ),
        popup = orbita_popup,
        popupOptions = popup_options(),
        label = "Projecte Òrbita"
      )
    )
  })
  output$school_table <- DT::renderDataTable({
    withProgress(
      DT::datatable(
        as.data.frame(clean_schools())[, school_vars] %>%
          mutate(
            prob_one_case_class = round(prob_one_case_class, 2),
            prob_one_case_school = round(prob_one_case_school, 2)
          ) %>%
          rename_all(funs(c(new_school_names))),
        selection = "single",
        options = list(pageLength = 5,
                       stateSave = TRUE),
        rownames = F
      )
    )
  })

  output$summary_table <- DT::renderDataTable({
    withProgress(
      DT::datatable(
        as.data.frame(df %>%
                        mutate(
                          per_num = round(infected / n * 100, 2),
                          per_quarantena = case_when(
                            !is.na(n) ~ paste0(round(infected / n * 100, 2), "% (", infected, "/", n, ")"),
                            TRUE ~ "Cap centre educatiu"
                          )
                        )) %>%
          select(all_of(mun_vars)) %>%
          rename_all(funs(c(new_mun_names))),
        selection = "single",
        options = list(pageLength = 5,
                       stateSave = TRUE),
        rownames = F
      )
    )  
  })


  output$docs <- renderUI({
    HTML(docs)
  })
  output$quisom <- renderUI({
    HTML(orbita_popup)
  })
  
  output$evo1 <- renderPlotly({
    evo_plot_1(evo)
  })
  output$evo2 <- renderPlotly({
    evo_plot_2(evo)
  })
  
  # longitudinal
  # TODO
  
  
  # Actions
  
  # Schools
  prev_vals <- reactiveValues()

  observeEvent(input$school_table_rows_selected, {
    row_selected = clean_schools()[input$school_table_rows_selected,]
    proxy <- leafletProxy('mymap')
    proxy %>% 
      setView(lng=row_selected$Coordenades_GEO_X, 
              lat=row_selected$Coordenades_GEO_Y + .05, # so that the popup is correctly displayed, 
              zoom = 12) %>%
      addPopups(layerId = as.character(row_selected$Codi_centre),
        lng=row_selected$Coordenades_GEO_X, 
                lat=row_selected$Coordenades_GEO_Y,
                popup = esc_popup(row_selected), 
                options = popup_options())
        
    if(!is.null(prev_vals$school))
    {
      proxy %>% 
        removePopup(layerId = as.character(prev_vals$school$Codi_centre))
    }
    
    if (!is.null(prev_vals$mun))
    {
      proxy %>% removePopup(layerId = as.character(prev_vals$mun$Codi_municipi))
    }
    
    # set new value to reactiveVal 
    prev_vals$school <- row_selected
      
  })
  
  # Municipis

  observeEvent(input$summary_table_rows_selected, {
    row_selected = df[input$summary_table_rows_selected,]
    loc <- sf::st_bbox(row_selected$geometry)
    x <- (loc[1] + loc[3]) / 2
    y <- (loc[2] + loc[4]) / 2
    proxy <- leafletProxy('mymap')
    proxy %>%
      setView(lng=x,
              lat=y + .05,
              zoom = 9) %>%
      addPopups(layerId = as.character(row_selected$Codi_municipi),
                lng=x,
                lat=y,
                mun_popup(row_selected),
                options = popup_options())

    if(!is.null(prev_vals$school))
    {
      proxy %>% 
        removePopup(layerId = as.character(prev_vals$school$Codi_centre))
    }
    
    if (!is.null(prev_vals$mun))
    {
      proxy %>% removePopup(layerId = as.character(prev_vals$mun$Codi_municipi))
    }
    
    
    # set new value to reactiveVal
    prev_vals$mun <- row_selected

  })

  

  



}