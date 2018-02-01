library(Cairo)

all_vars <- names(data_synth_w)
all_vars <- all_vars[all_vars != 'snz_uid']


CairoPDF("synthesis/distributions.pdf", 11, 8)
for(i in 1:length(all_vars)){
# for(i in 1:15){ # used during dev
  the_var <- all_vars[i]
  comp <- data_frame(
    x = c(data_orig_w[ , the_var], data_synth_w[ , the_var]),
    type = rep(c("original", "synthetic"), c(nrow(data_orig_w), nrow(data_synth_w)))
  )
  p <- ggplot(comp, aes(x = x, colour = type, fill = type)) + 
    ggtitle(the_var) +
    facet_wrap(~type)
  
  if(class(comp$x) %in% c("character", "factor")){
    p <- p + geom_bar(alpha = 0.5)
  } else {
    p <- p + geom_density(alpha = 0.5) + scale_x_sqrt()
  }
  print(p )
  cat(i)
}

dev.off()

