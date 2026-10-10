# R session setup, run once at startup

# install.packages() fetches wasm binaries instead of building sources
webr::shim_install()
# CRAN packages missing from the webR repo (e.g. rootSolve) have wasm builds on r-universe
local({
  repos <- c("https://repo.r-wasm.org/", "https://cran.r-universe.dev")
  options(repos = repos, webr_pkg_repos = repos)
})
options(device = webr::canvas)

# curl's 10s connect timeout is too short through the webR websocket relay;
# httr (used by opalr/DSOpal) is set up whenever it gets loaded
setHook(
  packageEvent("httr", "onLoad"),
  function(...) {
    httr::set_config(httr::config(connecttimeout = 60))
    httr::set_callback("request", .webds_fetch)
  }
)

# fetch transport: requests to hosts listed in options(webds.fetch = ) are sent
# by the browser (sync XMLHttpRequest in the webR worker) instead of curl over
# the websocket relay (see issue #2). No browser cookies: the Opal session id is
# kept per connection and sent in the X-Opal-Session header, so the server must
# support it and allow CORS from this page's origin.
# ponytail: sessions are matched by curl handle with a linear scan, never pruned
options(webds.fetch = "opal-demo.obiba.org")
.webds_sessions <- new.env()
.webds_sessions$list <- list()
.webds_fetch <- function(req) {
  if (!httr::parse_url(req$url)$hostname %in% getOption("webds.fetch")) return(NULL)
  # ponytail: multipart uploads (opal.file_upload) still go through curl
  if (!is.null(req$fields)) return(NULL)
  headers <- as.list(req$headers[nzchar(req$headers)])
  # one session per connection: request_perform() runs the callback with the connection's curl handle
  handle <- dynGet("handle")
  i <- Position(function(s) identical(s$handle, handle), .webds_sessions$list)
  headers[["X-Opal-Session"]] <- if (is.na(i)) "" else .webds_sessions$list[[i]]$id
  body <- req$options$postfields
  if (is.character(body)) body <- charToRaw(enc2utf8(paste(body, collapse = "")))
  # empty bodies come as postfields = 0L
  if (!is.raw(body)) body <- NULL
  js <- sprintf('(() => {
    const r = %s;
    const xhr = new XMLHttpRequest();
    xhr.open(r.method, r.url, false);
    xhr.responseType = "arraybuffer";
    for (const [k, v] of Object.entries(r.headers)) xhr.setRequestHeader(k, v);
    try {
      xhr.send(r.body === null ? null : Uint8Array.from(atob(r.body), (c) => c.charCodeAt(0)));
    } catch (e) {
      return 0;
    }
    // explicit webR list: a plain object would be converted to a data.frame
    return {
      type: "list",
      names: ["status", "url", "headers", "body"],
      values: [xhr.status, xhr.responseURL, xhr.getAllResponseHeaders(), xhr.response],
    };
  })()', jsonlite::toJSON(list(
    method = req$method, url = req$url, headers = headers,
    body = if (length(body)) jsonlite::base64_enc(body) else NULL
  ), auto_unbox = TRUE, null = "null"))
  start <- Sys.time()
  res <- webr::eval_js(js)
  if (identical(res, 0)) {
    stop("Request to ", req$url, " failed: network error or CORS not allowed by the server", call. = FALSE)
  }
  lines <- strsplit(res$headers, "\r\n", fixed = TRUE)[[1]]
  sep <- regexpr(": ", lines, fixed = TRUE)
  headers <- httr:::insensitive(as.list(setNames(substring(lines, sep + 2), substring(lines, 1, sep - 1))))
  cookies <- data.frame(domain = character(), flag = logical(), path = character(), secure = logical(),
                        expiration = as.POSIXct(character()), name = character(), value = character())
  sid <- headers[["x-opal-session"]]
  if (!is.null(sid)) {
    if (is.na(i)) i <- length(.webds_sessions$list) + 1
    .webds_sessions$list[[i]] <- list(handle = handle, id = sid)
    # opalr reads the session id from the cookies, to delete the session on logout
    if (nzchar(sid)) cookies[1, ] <- list("", FALSE, "/", TRUE, NA, "opalsid", sid)
  }
  content <- res$body
  if (inherits(req$output, "write_disk")) {
    writeBin(content, req$output$path)
    content <- httr:::path(req$output$path)
  }
  httr:::response(
    url = res$url, status_code = as.integer(res$status), headers = headers, all_headers = NULL,
    cookies = cookies, content = content, date = Sys.time(),
    times = c(total = as.numeric(Sys.time() - start, units = "secs")),
    request = req, handle = NULL
  )
}

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
