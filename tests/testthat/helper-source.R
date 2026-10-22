# The helpers use repository-relative paths, so source them from the root
local({
  owd <- setwd(file.path("..", ".."))
  on.exit(setwd(owd))
  for (f in c("R/functions.R", "R/evaluation.R")) source(f)
})
