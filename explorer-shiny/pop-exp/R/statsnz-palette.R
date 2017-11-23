# This R script is a quick way to help default graphics look more like a Stats NZ look and feel.
# It's probably not good enough for official publications, but could be polished up for that.
#
# Usage - run this file as the first step in a project.  Note that it assumes the existence
# of a folder called "assets" that holds various .otf font files in it.
#
# Peter Ellis, 3 August 2017

library(ggplot2)
library(scales)


#==================set up typeface family=====================
# this next line needs to point to somewhere that holds all the .otf files for SourceSansPro.
# These can be downloaded from https://www.fontsquirrel.com/fonts/source-sans-pro
# font.paths("assets")

# load in the font:
# font.add("SourceSansPro", 
#          regular = "SourceSansPro-Regular.otf",
#          italic = "SourceSansPro-It.otf",
#          bold = "SourceSansPro-Bold.otf",
#          bolditalic  = "SourceSansPro-BoldIt.otf")

# tell R to use showtext fonts for all devices, and set the resolution in dots per inch 
# (note that this overrides the dpi= or res= arguments in graphics devices from now on,
# so need to change with showtext.opts if you want them)
# showtext.auto()
# showtext.opts(dpi = 300)


theme_set(theme_minimal(base_family = "Source Sans Pro"))

#======================define colours================
# brand colours for things like headings and titles and so on
snz_brand <- c(
  black = "#272525",
  orange = "#ec6607",
  blue = "#004f9e",
  purple = "#5f2282",
  cyan = "#31b7bc",
  red = "#e4003a",
  yellow = "#fbb900",
  green = "#51ae32",
  grey = "#706f6e"
)

# graph colours
snz_graph_colour <- c("#4a148c", "#004f9e", "#0378bd", "#ff1745", "#f47c00", "#ffab40")
snz_graph_blue <- c("#00407d", "#004f9e", "#2b6bad", "#5489bf", "#80a6cf", "#aac4dd")

#======================change ggplot2 defaults===================
# set a sensible default for discrete colour scales
scale_colour_discrete <- function(...) scale_colour_manual(..., values = snz_graph_colour[c(6, 1, 3, 4, 2, 5)])
scale_fill_discrete <- function(...) scale_fill_manual(..., values = snz_graph_colour[c(6, 1, 3, 4, 2, 5)])

# a few small changes to defaults for other geoms
update_geom_defaults(c("line", "point", "text", "segment", "path"), list(colour = snz_graph_blue[2]))
update_geom_defaults("point", list(fill = snz_graph_blue[2]))
update_geom_defaults("smooth", list(colour = snz_graph_blue[4]))
update_geom_defaults(c("rect", "bar", "histogram"), list(fill = snz_graph_blue[4]))
update_geom_defaults("text", list(family = "Source Sans Pro"))

