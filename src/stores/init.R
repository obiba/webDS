# R session setup, run once at startup

# install.packages() fetches wasm binaries instead of building sources
webr::shim_install()
options(device = webr::canvas)

# curl's 10s connect timeout is too short through the webR websocket relay;
# httr (used by opalr/DSOpal) is set up whenever it gets loaded
setHook(
  packageEvent("httr", "onLoad"),
  function(...) httr::set_config(httr::config(connecttimeout = 60))
)

# help: text pages (help(package = ), ??) go through the webR pager,
# topic pages are rendered as HTML and sent through the same pager message
webr::pager_install()
local({
  print_help <- utils:::print.help_files_with_topic
  registerS3method("print", "help_files_with_topic", function(x, ...) {
    # no match: original method prints "No documentation for ..."
    if (length(x) == 0L) return(print_help(x, ...))
    # ponytail: first match only, list all matches if topics clash across packages
    file <- tempfile(fileext = ".html")
    # help file path is .../<package>/help/<topic>
    package <- basename(dirname(dirname(x[[1L]])))
    tools::Rd2HTML(utils:::.getHelpFile(x[[1L]]), out = file, package = package, dynamic = TRUE)
    # footer index link is relative to the package html dir: make it a package link
    html <- readLines(file)
    index <- sprintf('href="../../%s/html/00Index.html"', package)
    writeLines(sub('href="00Index.html"', index, html, fixed = TRUE), file)
    getOption("pager")(file, "", attr(x, "topic"), TRUE)
    invisible(x)
  }, envir = asNamespace("utils"))
})
