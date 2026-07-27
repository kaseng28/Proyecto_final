# ============================================
# ANALISIS FINAL - PREGUNTA DE INVESTIGACION
# ============================================
# ¿Existe relación entre nivel educativo, pobreza y ser NINI en Junín?
# ============================================

library(haven)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(forcats)

 ruta_mod5 <- "C:/Users/vale/Downloads/1031-Modulo055/1031-Modulo05/Enaho01a-2025-500.sav"
 ruta_mod3 <- "C:/Users/vale/Downloads/1031-Modulo035/1031-Modulo03/Enaho01A-2025-300.sav"
 ruta_mod34 <- "C:/Users/vale/Downloads/1031-Modulo345/1031-Modulo34/Sumaria-2025.sav"

mod5 <- read_sav(ruta_mod5)
mod3 <- read_sav(ruta_mod3)
mod34 <- read_sav(ruta_mod34)

# 2. SELECCIONAR VARIABLES Y UNIR
mod5_select <- mod5 %>%
  select(CONGLOME, VIVIENDA, HOGAR, CODPERSO,
         UBIGEO, ESTRATO, P208A, P207, OCU500, FAC500A)

mod3_select <- mod3 %>%
  select(CONGLOME, VIVIENDA, HOGAR, CODPERSO,
         P301A, P301B, P303)

mod34_select <- mod34 %>%
  select(CONGLOME, VIVIENDA, HOGAR,
         POBREZA, POBREZAV, ESTRSOCIAL)

datos_completos <- mod5_select %>%
  left_join(mod3_select, by = c("CONGLOME", "VIVIENDA", "HOGAR", "CODPERSO")) %>%
  left_join(mod34_select, by = c("CONGLOME", "VIVIENDA", "HOGAR"))

# 3. FILTRAR JUNIN Y JOVENES 15-29
datos_junin <- datos_completos %>%
  mutate(ubigeo_num = as.numeric(UBIGEO),
         ubidepartamento = floor(ubigeo_num / 10000)) %>%
  filter(ubidepartamento == 12) %>%
  mutate(edad = as.numeric(P208A),
         sexo = as.numeric(P207),
         cond_ocup = as.numeric(OCU500),
         asiste_educ = as.numeric(P303),
         nivel_educ = as.numeric(P301A)) %>%
  filter(edad >= 15 & edad <= 29) %>%
  mutate(
    estudia = ifelse(asiste_educ == 1, 1, 0),
    trabaja = ifelse(cond_ocup == 1, 1, 0),
    nini = ifelse(estudia == 0 & trabaja == 0, 1, 0),
    sexo_label = factor(sexo, levels = c(1, 2), labels = c("Hombre", "Mujer")),
    nivel_educ_grupo = case_when(
      nivel_educ %in% c(1, 4) ~ "Sin nivel/Primaria",
      nivel_educ %in% c(5, 6) ~ "Secundaria",
      nivel_educ %in% c(7, 8, 9, 10) ~ "Superior",
      TRUE ~ "Otros"
    ),
    pobreza_label = case_when(
      POBREZA == 1 ~ "Pobre Extremo",
      POBREZA == 2 ~ "Pobre No Extremo",
      POBREZA == 3 ~ "No Pobre",
      TRUE ~ NA_character_
    )
  )

# 4. TABLAS DE INCIDENCIA
# Tabla 1: NINI por Nivel Educativo
tabla_educ <- datos_junin %>%
  filter(!is.na(nini), !is.na(nivel_educ_grupo)) %>%
  group_by(nivel_educ_grupo) %>%
  summarise(
    Total = n(),
    Ninis = sum(nini == 1, na.rm = TRUE),
    Porcentaje = round((Ninis / Total) * 100, 1)
  )

print("Tabla 1: Incidencia de NINI por Nivel Educativo")
print(tabla_educ)

# Tabla 2: NINI por Pobreza
tabla_pobreza <- datos_junin %>%
  filter(!is.na(nini), !is.na(pobreza_label)) %>%
  group_by(pobreza_label) %>%
  summarise(
    Total = n(),
    Ninis = sum(nini == 1, na.rm = TRUE),
    Porcentaje = round((Ninis / Total) * 100, 1)
  )

print("Tabla 2: Incidencia de NINI por Condicion de Pobreza")
print(tabla_pobreza)

# 5. GRAFICO FINAL 
datos_grafico <- datos_junin %>%
  filter(!is.na(nini), !is.na(nivel_educ_grupo), !is.na(pobreza_label)) %>%
  group_by(nivel_educ_grupo, pobreza_label) %>%
  summarise(
    Total = n(),
    Ninis = sum(nini == 1, na.rm = TRUE),
    Porcentaje = round((Ninis / Total) * 100, 1)
  ) %>%
  ungroup()

grafico_final <- ggplot(datos_grafico, 
                        aes(x = nivel_educ_grupo, 
                            y = Porcentaje, 
                            fill = pobreza_label)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Porcentaje, "%")),
            position = position_dodge(width = 0.8),
            vjust = -0.5,
            size = 3.5,
            fontface = "bold") +
  scale_fill_manual(
    values = c("Pobre Extremo" = "#C0392B",
               "Pobre No Extremo" = "#E67E22",
               "No Pobre" = "#27AE60"),
    name = "Condicion de Pobreza"
  ) +
  labs(
    title = "Jovenes NINI en Junin segun Nivel Educativo y Pobreza",
    subtitle = "Porcentaje de jovenes que no estudian ni trabajan (15-29 anos)",
    x = "Nivel Educativo",
    y = "Porcentaje de NINIs (%)",
    caption = "Fuente: ENAHO 2025 - Elaboracion propia"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 11, hjust = 0.5),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "bottom",
    legend.title = element_text(size = 10, face = "bold"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

print(grafico_final)

# 6. GUARDAR GRAFICO
ggsave("figures/grafico_final.png", 
       grafico_final, width = 10, height = 6, dpi = 300)
