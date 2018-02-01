adding_order   <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "adding-order")
expl_variables <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "variables")

library(ggraph)
library(igraph)

edges <- expl_variables %>%
  select(-lags) %>%
  rename(from = explanatory, to = response) %>%
  select(from, to)

nodes <- data_frame(variable = c("sex", "born_nz", "birth_year_nbr", "birth_month_nbr", adding_order$response))
nodes <- nodes %>%
  mutate(sequence = 1:nrow(nodes),
         label = paste(sequence, variable))


g <- graph_from_data_frame(edges, vertices = nodes)

png("synthesis/variable-sequence.png", 8000, 5000, res = 600)
set.seed(42)
ggraph(g, layout = 'kk') +
  geom_edge_fan(colour = "grey75", arrow = arrow(length = unit(0.07, "inches"))) +
  geom_node_text(aes(label = label, colour = sequence), fontface = "bold") +
  theme_graph(base_family = "Source Sans Pro", background = "grey50") +
  scale_color_viridis(direction = -1, option = "C") +
  ggtitle("Sequence of modelling and synthesising variables for pop_exp_synth",
          "The synthetic version of the IDI Population Explorer")
dev.off()