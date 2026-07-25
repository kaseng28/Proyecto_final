library(haven)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(forcats)

# 1. IMPORTACION DE MODULOS ---------------------------------------------

# Módulo 5 - EMPLEO
ruta_mod5 <- "data/Enaho01a-2025-500.sav"
mod5 <- read_sav(ruta_mod5)

# Módulo 3 - EDUCACIÓN
ruta_mod3 <- "data/Enaho01A-2025-300.sav"
mod3 <- read_sav(ruta_mod3)

# Módulo 34 - SUMARIA
ruta_mod34 <- "data/Sumaria-2025.sav"
mod34 <- read_sav(ruta_mod34)

# 2. SELECCION DE VARIABLES ---------------------------------------------

mod5_select <- mod5 %>%
  select(CONGLOME, VIVIENDA, HOGAR, CODPERSO,
         UBIGEO, DOMINIO, ESTRATO, 
         P208A,     # Edad en años cumplidos
         P207,      # Sexo (1=Hombre, 2=Mujer)
         OCU500,    # Condicion de ocupacion
         P511A,     # Ingreso
         FAC500A) 

mod3_select <- mod3 %>%
  select(CONGLOME, VIVIENDA, HOGAR, CODPERSO, 
         P301A, P301B, P303, P305, P306)

mod34_select <- mod34 %>%
  select(CONGLOME, VIVIENDA, HOGAR,
         POBREZA, POBREZAV, LINPE, ESTRSOCIAL, FACTOR07)

# 3. UNION DE MODULOS ---------------------------------------------------

datos_completos <- mod5_select %>%
  left_join(mod3_select, by = c("CONGLOME", "VIVIENDA", "HOGAR", "CODPERSO")) %>%
  left_join(mod34_select, by = c("CONGLOME", "VIVIENDA", "HOGAR"))

# 4. FILTRAR JUNIN ------------------------------------------------------

datos_junin <- datos_completos %>%
  mutate(
    ubigeo_num = as.numeric(UBIGEO),
    ubidepartamento = floor(ubigeo_num / 10000)
  ) %>%
  filter(ubidepartamento == 12)

# 5. FILTRAR JOVENES (15-29) Y DEFINIR NINI ----------------------------

datos_ninis <- datos_junin %>%
  mutate(
    edad = as.numeric(P208A),
    sexo = as.numeric(P207),
    cond_ocup = as.numeric(OCU500),
    ingreso = as.numeric(P511A),
    nivel_educ = as.numeric(P301A),
    anios_educ = as.numeric(P301B),
    asiste_educ = as.numeric(P303)
  ) %>%
  filter(edad >= 15 & edad <= 29) %>%
  mutate(
    # Estudia = 1 si P303 == 1 (Sí asiste)
    estudia = case_when(
      asiste_educ == 1 ~ 1,
      asiste_educ == 0 ~ 0,
      asiste_educ %in% c(2, 3, 4, 5) ~ 0,
      TRUE ~ NA_real_
    ),
    
    # Trabaja = 1 si OCU500 == 1 (Ocupado)
    trabaja = case_when(
      cond_ocup == 1 ~ 1,
      cond_ocup %in% c(2, 3, 4, 5, 6) ~ 0,
      TRUE ~ NA_real_
    ),
    
    # NINI: No estudia Y No trabaja
    nini = case_when(
      estudia == 0 & trabaja == 0 ~ "Sí",
      estudia == 1 | trabaja == 1 ~ "No",
      TRUE ~ NA_character_
    ),
    
    # Sexo etiquetado
    sexo_label = factor(sexo, levels = c(1, 2), labels = c("Hombre", "Mujer")),
    
    # ==========================================
    # NIVEL EDUCATIVO - CORREGIDO CON VALORES REALES
    # ==========================================
    nivel_educ_label = case_when(
      nivel_educ == 1 ~ "Sin nivel",
      nivel_educ == 4 ~ "Primaria completa",
      nivel_educ == 5 ~ "Secundaria incompleta",
      nivel_educ == 6 ~ "Secundaria completa",
      nivel_educ == 7 ~ "Superior no univ. incompleta",
      nivel_educ == 8 ~ "Superior no univ. completa",
      nivel_educ == 9 ~ "Superior univ. incompleta",
      nivel_educ == 10 ~ "Superior univ. completa",
      TRUE ~ NA_character_ ),
    
    # Version agrupada de nivel educativo
    nivel_educ_grupo = case_when(
      nivel_educ %in% c(1) ~ "Sin nivel/Primaria",
      nivel_educ %in% c(4) ~ "Sin nivel/Primaria",
      nivel_educ %in% c(5, 6) ~ "Secundaria",
      nivel_educ %in% c(7, 8, 9, 10) ~ "Superior",
      TRUE ~ NA_character_ ),
    
    # Grupo de edad
    grupo_edad = case_when(
      edad %in% 15:19 ~ "15-19",
      edad %in% 20:24 ~ "20-24",
      edad %in% 25:29 ~ "25-29"
    ),
    
    # Estrato
    estrato_label = ifelse(ESTRATO %in% 1:5, "Urbano", ifelse(ESTRATO %in% 6:8, "Rural", NA_character_)),
    
    # Pobreza
    pobreza_label = case_when(
      POBREZA == 1 ~ "Pobre Extremo",
      POBREZA == 2 ~ "Pobre No Extremo",
      POBREZA == 3 ~ "No Pobre",
      TRUE ~ NA_character_
    ),
    
    pobreza_extrema_label = case_when(
      POBREZAV == 1 ~ "Pobre Extremo",
      POBREZAV == 2 ~ "Pobre No Extremo",
      POBREZAV == 3 ~ "Vulnerable",
      POBREZAV == 4 ~ "No Vulnerable",
      TRUE ~ NA_character_
    ),
    
    estrato_social_label = case_when(
      ESTRSOCIAL >= 1 & ESTRSOCIAL < 2 ~ "Estrato 1 (Muy bajo)",
      ESTRSOCIAL >= 2 & ESTRSOCIAL < 3 ~ "Estrato 2 (Bajo)",
      ESTRSOCIAL >= 3 & ESTRSOCIAL < 4 ~ "Estrato 3 (Medio bajo)",
      ESTRSOCIAL >= 4 & ESTRSOCIAL < 5 ~ "Estrato 4 (Medio)",
      ESTRSOCIAL >= 5 & ESTRSOCIAL < 6 ~ "Estrato 5 (Medio alto)",
      ESTRSOCIAL >= 6 & ESTRSOCIAL < 7 ~ "Estrato 6 (Alto)",
      TRUE ~ NA_character_
    )
  )

# 6. DATOS NACIONALES PARA COMPARACION ----------------------------------

datos_peru <- datos_completos %>%
  mutate(
    edad = as.numeric(P208A),
    asiste_educ = as.numeric(P303),
    cond_ocup = as.numeric(OCU500)
  ) %>%
  filter(edad >= 15 & edad <= 29) %>%
  mutate(
    estudia = case_when(
      asiste_educ == 1 ~ 1,
      asiste_educ == 0 ~ 0,
      asiste_educ %in% c(2, 3, 4, 5) ~ 0,
      TRUE ~ NA_real_
    ),
    trabaja = case_when(
      cond_ocup == 1 ~ 1,
      cond_ocup %in% c(2, 3, 4, 5, 6) ~ 0,
      TRUE ~ NA_real_
    ),
    nini = case_when(
      estudia == 0 & trabaja == 0 ~ "Sí",
      estudia == 1 | trabaja == 1 ~ "No",
      TRUE ~ NA_character_
    )
  )

# 7. ESTADISTICAS DESCRIPTIVAS -----------------------------------------

cat("\n")
cat(rep("=", 70), "\n")
cat("ESTADISTICAS DESCRIPTIVAS - JOVENES NINIS EN JUNIN 2025\n")
cat(rep("=", 70), "\n")

total_jovenes <- nrow(datos_ninis)
total_ninis <- sum(datos_ninis$nini == "Sí", na.rm = TRUE)
pct_ninis <- ifelse(total_jovenes > 0, (total_ninis / total_jovenes) * 100, 0)

cat("\nRESUMEN GENERAL:\n")
cat("--------------------------------------------------\n")
cat("Total de jovenes (15-29 años) en Junin:", total_jovenes, "\n")
cat("Total de Ninis en Junin:", total_ninis, "\n")
cat("Porcentaje de Ninis en Junin:", round(pct_ninis, 2), "%\n")

total_nac <- nrow(datos_peru)
ninis_nac <- sum(datos_peru$nini == "Sí", na.rm = TRUE)
pct_ninis_nac <- ifelse(total_nac > 0, (ninis_nac / total_nac) * 100, 0)

cat("\nCOMPARACION NACIONAL:\n")
cat("--------------------------------------------------\n")
cat("Total de jovenes (15-29 años) en Peru:", total_nac, "\n")
cat("Total de Ninis en Peru:", ninis_nac, "\n")
cat("Porcentaje de Ninis en Peru:", round(pct_ninis_nac, 2), "%\n")
cat("Diferencia Junin vs Nacional:", round(pct_ninis - pct_ninis_nac, 2), "p.p.\n")

# PERFIL DE NINIS
if (total_ninis > 0) {
  perfil <- datos_ninis %>%
    filter(nini == "Sí") %>%
    summarise(
      Edad_Promedio = round(mean(edad, na.rm = TRUE), 1),
      Edad_Mediana = median(edad, na.rm = TRUE),
      Pct_Mujeres = round(mean(sexo == 2, na.rm = TRUE) * 100, 1),
      Pct_Hombres = 100 - Pct_Mujeres,
      Educacion_Promedio = round(mean(anios_educ, na.rm = TRUE), 1),
      Pct_Pobreza = round(mean(POBREZA %in% c(1,2), na.rm = TRUE) * 100, 1),
      Pct_Urbano = round(mean(ESTRATO %in% 1:5, na.rm = TRUE) * 100, 1)
    )
  
  cat("\nPERFIL DE NINIS EN JUNIN:\n")
  cat("--------------------------------------------------\n")
  print(perfil)
  
  # TABLAS DE FRECUENCIA
  cat("\nDISTRIBUCION POR SEXO:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(sexo_label) %>% mutate(Pct = round(n/sum(n)*100,1)) %>% print()
  
  cat("\nDISTRIBUCION POR NIVEL EDUCATIVO:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(nivel_educ_label) %>% mutate(Pct = round(n/sum(n)*100,1)) %>% print()
  
  cat("\nDISTRIBUCION POR NIVEL EDUCATIVO (AGRUPADO):\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(nivel_educ_grupo) %>% mutate(Pct = round(n/sum(n)*100,1)) %>% print()
  
  cat("\nDISTRIBUCION POR POBREZA:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(pobreza_label) %>% mutate(Pct = round(n/sum(n)*100,1)) %>% print()
  
  cat("\nTABLA CRUZADA: SEXO x EDUCACION:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(sexo_label, nivel_educ_label) %>% 
    pivot_wider(names_from = nivel_educ_label, values_from = n, values_fill = 0) %>% print()
  
  cat("\nTABLA CRUZADA: SEXO x POBREZA:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% count(sexo_label, pobreza_label) %>% 
    pivot_wider(names_from = pobreza_label, values_from = n, values_fill = 0) %>% print()
}

cat("\nCOMPARACION NINI vs NO NINI:\n")
cat("--------------------------------------------------\n")
datos_ninis %>% filter(!is.na(nini)) %>% group_by(nini) %>% summarise(
  n = n(),
  Edad_Prom = round(mean(edad, na.rm=TRUE),1),
  Educ_Prom = round(mean(anios_educ, na.rm=TRUE),1),
  Pct_Mujeres = round(mean(sexo==2, na.rm=TRUE)*100,1),
  Pct_Pobreza = round(mean(POBREZA %in% c(1,2), na.rm=TRUE)*100,1)
) %>% print()

# 8. GRÁFICOS 
tema_ninis <- theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5, 
                              color = "#1a237e", margin = margin(b = 10)),
    plot.subtitle = element_text(size = 12, hjust = 0.5, 
                                 color = "#546e7a", margin = margin(b = 20)),
    plot.caption = element_text(size = 9, color = "#78909c", 
                                hjust = 0, margin = margin(t = 15)),
    axis.title = element_text(size = 11, face = "bold", color = "#37474f"),
    axis.text = element_text(size = 10, color = "#455a64"),
    axis.text.x = element_text(angle = 0, hjust = 0.5),
    legend.position = "bottom",
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 9),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "#fafafa", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  )

# Paleta de colores profesional
colores_ninis <- c(
  "Sí" = "#e53935",
  "No" = "#43a047",
  "Hombre" = "#1e88e5",
  "Mujer" = "#ec407a",
  "Pobre Extremo" = "#c62828",
  "Pobre No Extremo" = "#f57c00",
  "No Pobre" = "#2e7d32"
)


# GRÁFICO 1: Ninis por Sexo y Nivel Educativo


if (total_ninis > 0) {
  
  # Preparar datos con porcentajes
  datos_grafico1 <- datos_ninis %>%
    filter(nini == "Sí") %>%
    count(sexo_label, nivel_educ_label) %>%
    filter(!is.na(nivel_educ_label)) %>%
    group_by(sexo_label) %>%
    mutate(porcentaje = n / sum(n) * 100) %>%
    ungroup() %>%
    mutate(nivel_educ_label = fct_reorder(nivel_educ_label, n, .desc = TRUE))
  
  # Crear gráfico
  grafico1 <- ggplot(datos_grafico1, 
                     aes(x = nivel_educ_label, y = n, fill = sexo_label)) +
    geom_bar(stat = "identity", 
             position = position_dodge(width = 0.9), 
             width = 0.8,
             color = "white",
             size = 0.5) +
    geom_text(aes(label = paste0(n, " (", round(porcentaje, 1), "%)")),
              position = position_dodge(width = 0.9),
              vjust = -0.5,
              size = 3.2,
              fontface = "bold",
              color = "#37474f") +
    scale_fill_manual(values = colores_ninis) +
    labs(
      title = "Jóvenes Ninis en Junín por Sexo y Nivel Educativo",
      subtitle = "Distribución de los Ninis según nivel educativo alcanzado y sexo",
      x = "Nivel Educativo",
      y = "Frecuencia",
      caption = paste("Fuente: ENAHO 2025 - Módulos 3 y 5 | Total Ninis:", total_ninis)
    ) +
    tema_ninis +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8))
  
  print(grafico1)
}

# GRÁFICO 2: Ninis por Grupo de Edad 

# Calcular totales para mostrar
totales_edad <- datos_ninis %>%
  filter(!is.na(nini), !is.na(grupo_edad)) %>%
  count(grupo_edad, nini) %>%
  group_by(grupo_edad) %>%
  mutate(
    total_grupo = sum(n),
    porcentaje = n / sum(n) * 100,
    etiqueta = paste0(round(porcentaje, 1), "%\n(n = ", n, ")")
  ) %>%
  ungroup()

grafico2 <- totales_edad %>%
  mutate(grupo_edad = factor(grupo_edad, levels = c("15-19", "20-24", "25-29"))) %>%
  ggplot(aes(x = grupo_edad, y = porcentaje, fill = nini)) +
  geom_bar(stat = "identity", 
           position = position_stack(reverse = TRUE), 
           width = 0.7,
           color = "white",
           size = 0.5) +
  geom_text(aes(label = etiqueta),
            position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 3.5,
            fontface = "bold",
            color = "white") +
  scale_fill_manual(values = colores_ninis) +
  labs(
    title = "Proporción de Ninis por Grupo de Edad en Junín",
    subtitle = "Distribución porcentual de jóvenes Ninis según rango etario",
    x = "Grupo de Edad",
    y = "Porcentaje (%)",
    caption = paste("Fuente: ENAHO 2025 - Módulo 5 | Total de jóvenes:", total_jovenes)
  ) +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     limits = c(0, 100),
                     breaks = seq(0, 100, 20)) +
  tema_ninis

print(grafico2)


# GRÁFICO 3: Ninis por Sexo y Pobreza 

if (total_ninis > 0) {
  
  datos_grafico3 <- datos_ninis %>%
    filter(nini == "Sí", !is.na(pobreza_label)) %>%
    count(sexo_label, pobreza_label) %>%
    group_by(sexo_label) %>%
    mutate(porcentaje = n / sum(n) * 100) %>%
    ungroup() %>%
    mutate(pobreza_label = factor(pobreza_label, 
                                  levels = c("Pobre Extremo", "Pobre No Extremo", "No Pobre")))
  
  grafico3 <- ggplot(datos_grafico3, 
                     aes(x = sexo_label, y = n, fill = pobreza_label)) +
    geom_bar(stat = "identity", 
             position = position_dodge(width = 0.9), 
             width = 0.8,
             color = "white",
             size = 0.5) +
    geom_text(aes(label = paste0(n, " (", round(porcentaje, 1), "%)")),
              position = position_dodge(width = 0.9),
              vjust = -0.5,
              size = 3.5,
              fontface = "bold",
              color = "#37474f") +
    scale_fill_manual(values = colores_ninis) +
    labs(
      title = "Ninis en Junín por Sexo y Condición de Pobreza",
      subtitle = "Distribución según nivel de pobreza del hogar",
      x = "Sexo",
      y = "Frecuencia",
      caption = paste("Fuente: ENAHO 2025 - Módulo 34 | Total Ninis:", total_ninis)
    ) +
    tema_ninis
  
  print(grafico3)
}

# GRÁFICO 4: Mapa de Calor 

# Preparar datos con porcentajes
datos_heatmap <- datos_ninis %>%
  filter(!is.na(nini), !is.na(grupo_edad)) %>%
  count(sexo_label, grupo_edad, nini) %>%
  group_by(sexo_label, grupo_edad) %>%
  mutate(porcentaje_grupo = n / sum(n) * 100) %>%
  ungroup() %>%
  mutate(
    grupo_edad = factor(grupo_edad, levels = c("15-19", "20-24", "25-29")),
    nini = factor(nini, levels = c("Sí", "No")),
    etiqueta = paste0(n, "\n(", round(porcentaje_grupo, 1), "%)")
  )

grafico4 <- datos_heatmap %>%
  ggplot(aes(x = sexo_label, y = grupo_edad, fill = porcentaje_grupo)) +
  geom_tile(color = "white", linewidth = 1.5, width = 0.9, height = 0.9) +
  geom_text(aes(label = etiqueta),
            color = "black",
            size = 3.5,
            fontface = "bold",
            lineheight = 0.9) +
  facet_wrap(~nini, ncol = 2, 
             labeller = labeller(nini = c("No" = "No NINI", "Sí" = "NINI"))) +
  scale_fill_gradient2(
    low = "#e3f2fd",
    mid = "#64b5f6",
    high = "#1565c0",
    midpoint = 50,
    name = "Porcentaje\npor grupo"
  ) +
  labs(
    title = "Distribución de Jóvenes por Sexo, Edad y Condición NINI",
    subtitle = "Análisis multidimensional de la población joven en Junín",
    x = "Sexo",
    y = "Grupo de Edad",
    caption = paste("Fuente: ENAHO 2025 - Módulos 3, 5 y 34 | Total de jóvenes:", total_jovenes)
  ) +
  tema_ninis +
  theme(
    strip.text = element_text(size = 12, face = "bold", color = "white"),
    strip.background = element_rect(fill = "#1a237e", color = NA),
    legend.position = "right",
    legend.title = element_text(size = 9, face = "bold"),
    legend.text = element_text(size = 8),
    panel.grid = element_blank(),
    axis.text.y = element_text(size = 11),
    axis.text.x = element_text(size = 11)
  )

print(grafico4)


# GRÁFICO 5: Boxplot 

# Calcular estadísticas para mostrar
stats_edad <- datos_ninis %>%
  filter(!is.na(nini)) %>%
  group_by(nini) %>%
  summarise(
    media = round(mean(edad, na.rm = TRUE), 1),
    mediana = median(edad, na.rm = TRUE),
    n = n()
  )

grafico5 <- datos_ninis %>%
  filter(!is.na(nini)) %>%
  mutate(nini = factor(nini, levels = c("Sí", "No"), 
                       labels = c("NINI", "No NINI"))) %>%
  ggplot(aes(x = nini, y = edad, fill = nini)) +
  geom_boxplot(width = 0.5, 
               alpha = 0.9, 
               outlier.size = 2,
               outlier.color = "#e53935",
               outlier.alpha = 0.5,
               color = "#37474f") +
  geom_jitter(width = 0.1, 
              alpha = 0.3, 
              size = 1,
              color = "#546e7a") +
  stat_summary(fun = mean, 
               geom = "point", 
               shape = 18, 
               size = 4, 
               color = "#1a237e") +
  scale_fill_manual(values = c("NINI" = "#e53935", "No NINI" = "#43a047")) +
  labs(
    title = "Distribución de Edad según Condición NINI",
    subtitle = "Comparación de edades entre Ninis y No Ninis en Junín",
    x = "Condición",
    y = "Edad (años)",
    caption = paste("Fuente: ENAHO 2025 - Módulo 5 | Ninis:", total_ninis, 
                    "| No Ninis:", total_jovenes - total_ninis)
  ) +
  scale_y_continuous(limits = c(14, 31), breaks = seq(15, 30, 5)) +
  tema_ninis +
  theme(legend.position = "none")

print(grafico5)

# GRÁFICO 6  Comparación Junín vs Nacional

# Preparar datos de comparación
comparacion <- data.frame(
  Region = c("Junín", "Perú"),
  Porcentaje_Ninis = c(pct_ninis, pct_ninis_nac),
  Total_Jovenes = c(total_jovenes, total_nac),
  Ninis = c(total_ninis, ninis_nac)
)

grafico6 <- ggplot(comparacion, aes(x = Region, y = Porcentaje_Ninis, fill = Region)) +
  geom_bar(stat = "identity", width = 0.6, color = "white", size = 0.5) +
  geom_text(aes(label = paste0(round(Porcentaje_Ninis, 2), "%\n(n = ", Ninis, ")")),
            vjust = -0.5,
            size = 4,
            fontface = "bold",
            color = "#37474f") +
  scale_fill_manual(values = c("Junín" = "#1e88e5", "Perú" = "#43a047")) +
  labs(
    title = "Comparación de Ninis: Junín vs Perú",
    subtitle = "Porcentaje de jóvenes Ninis (15-29 años)",
    x = "Región",
    y = "Porcentaje de Ninis (%)",
    caption = "Fuente: ENAHO 2025 - Módulos 3, 5 y 34"
  ) +
  scale_y_continuous(labels = function(x) paste0(x, "%"),
                     limits = c(0, max(comparacion$Porcentaje_Ninis) * 1.3)) +
  tema_ninis +
  theme(legend.position = "none")

print(grafico6)

# 9. ESTADISTICAS ADICIONALES -------------------------------------------

if (total_ninis > 0) {
  cat("\nESTADISTICAS POR SEXO:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>% group_by(sexo_label) %>%
    summarise(
      n = n(),
      Edad_Media = round(mean(edad, na.rm=TRUE),1),
      Edad_Mediana = median(edad, na.rm=TRUE),
      Educ_Media = round(mean(anios_educ, na.rm=TRUE),1),
      Educ_SD = round(sd(anios_educ, na.rm=TRUE),2)
    ) %>% print()
  
  cat("\nMEDIDAS DE DISPERSION:\n")
  cat("--------------------------------------------------\n")
  datos_ninis %>% filter(nini == "Sí") %>%
    summarise(
      Edad_Min = min(edad), Edad_Max = max(edad), Edad_Rango = max(edad)-min(edad),
      Edad_Q1 = quantile(edad,0.25), Edad_Q3 = quantile(edad,0.75), Edad_IQR = Edad_Q3 - Edad_Q1
    ) %>% print()
}

# 10. RESUMEN EJECUTIVO -------------------------------------------------

cat("\n")
cat(rep("=", 70), "\n")
cat("RESUMEN EJECUTIVO - NINIS EN JUNIN 2025\n")
cat(rep("=", 70), "\n")

if (total_ninis > 0) {
  cat("\nPOBLACION ESTUDIADA:\n")
  cat("  Total jovenes 15-29 en Junin:", total_jovenes, "\n")
  cat("  Total NINIs:", total_ninis, "\n")
  cat("  Porcentaje:", round(pct_ninis, 2), "%\n")
  cat("  Nacional:", round(pct_ninis_nac, 2), "%\n")
  
  n_mujeres <- sum(datos_ninis$sexo == 2 & datos_ninis$nini == "Sí", na.rm = TRUE)
  n_hombres <- sum(datos_ninis$sexo == 1 & datos_ninis$nini == "Sí", na.rm = TRUE)
  
  cat("\nPERFIL DEL NINI:\n")
  if (n_mujeres > n_hombres) {
    cat("  Sexo: Mayoria femenina (", round(n_mujeres/total_ninis*100, 1), "%)\n")
  } else {
    cat("  Sexo: Mayoria masculina (", round(n_hombres/total_ninis*100, 1), "%)\n")
  }
  cat("  Edad promedio:", round(mean(datos_ninis$edad[datos_ninis$nini=="Sí"], na.rm=TRUE), 1), "años\n")
  
  # Nivel educativo mas comun
  educ_comun <- datos_ninis %>% filter(nini=="Sí") %>% count(nivel_educ_label) %>% 
    filter(!is.na(nivel_educ_label)) %>% arrange(desc(n)) %>% slice(1)
  if (nrow(educ_comun) > 0) cat("  Nivel educativo más común:", educ_comun$nivel_educ_label, "\n")
  
  n_pobres <- sum(datos_ninis$POBREZA %in% c(1,2) & datos_ninis$nini == "Sí", na.rm = TRUE)
  cat("  En pobreza:", round(n_pobres/total_ninis*100, 1), "%\n")
}
