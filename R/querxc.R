#' Access Xeno-Canto recordings and metadata
#' 
#' \code{querxc} downloads recordings and metadata from Xeno-Canto (\url{http://www.xeno-canto.org/}).
#' @usage querxc(qword, download = FALSE, X = NULL, file.name = c("Genus", "Specific_epithet"), 
#' parallel = 1, path = NULL, pb = TRUE)  
#' @param qword Character vector of length one indicating the genus, or genus and
#'  species, to query Xeno-Canto database. For example, \emph{Phaethornis} or \emph{Phaethornis longirostris}. 
#'  (\url{http://www.xeno-canto.org/}). More complex queries can be done by using search terms that follow the 
#'  xeno-canto advance query syntax.This syntax uses tags to search within a particular aspect of the recordings 
#'  (e.g. country, location, sound type). Tags are of the form tag:searchterm'. For instance, 'type:song' 
#'  will search for all recordings in which the sound type description contains the word 'song'. 
#'  Several tags can be included in the same query. The query "phaethornis cnt:belize' will only return 
#'  results for birds in the genus \emph{Phaethornis} that were recorded in  Belize. 
#'  See \url{http://www.xeno-canto.org/help/search} for a full description and see examples below 
#'  for queries using terms with more than one word.
#' @param download Logical argument. If \code{FALSE} only the recording file names and
#'   associated metadata are downloaded. If \code{TRUE}, recordings are also downloaded to the working
#'   directory as .mp3 files. Default is \code{FALSE}. Note that if the recording is already in the 
#'   working directory (as when the downloading process has been interrupted) it will be skipped. 
#'   Hence, resuming downloading processes will not start from scratch.   
#' @param X Data frame with a 'Recording_ID' column and any other column listed in the file.name argument. Only the recordings listed in the data frame 
#' will be download (\code{download} argument is automatically set to \code{TRUE}). This can be used to select
#' the recordings to be downloaded based on their attributes.  
#' @param file.name Character vector indicating the tags (or column names) to be included in the sound file names (if download = \code{TRUE}). Several tags can be included. If \code{NULL} only the Xeno-Canto recording identification number ("Recording_ID") is used. Default is c("Genus", "Specific_epithet").
#' Note that recording id is always used (whether or not is listed by users) to avoid duplicated names.
#' @param parallel Numeric. Controls whether parallel computing is applied when downloading mp3 files.
#' It specifies the number of cores to be used. Default is 1 (i.e. no parallel computing). Currently only applied when downloading files. Might not work 
#' improve performance on Windows OS. 
#' @param path Character string containing the directory path where the sound files are located. 
#' If \code{NULL} (default) then the current working directory is used.
#' @param pb Logical argument to control progress bar. Default is \code{TRUE}. Note that progress bar is only used
#' when parallel = 1.
#' @return If X is not provided the function returns a data frame with the following recording information: recording ID, Genus, Specific epithet, Subspecies, English name, Recordist, Country, Locality, Latitude, Longitude, Vocalization type, Audio file, License, URL, Quality, Time, Date. Sound files in .mp3 format are downloaded into the working directory if download = \code{TRUE} or if X is provided; a column indicating the  names of the downloaded files is included in the output data frame.  
#' @export
#' @name querxc
#' @details This function queries for avian vocalization recordings in the open-access
#' online repository Xeno-Canto (\url{http://www.xeno-canto.org/}). It can return recordings metadata
#' or download the associated sound files. Maps of recording coordinates can be produced using 
#' \code{\link{xcmaps}}
#' @seealso \code{\link{xcmaps}}, 
#' \url{https://marce10.github.io/2016-12-22-Download_a_single_recording_for_each_species_in_a_site_from_Xeno-Canto/} 
#' @examples
#' \dontrun{
#' # Set temporary working directory
#' setwd(tempdir())
#' 
#' # search without downloading
#' df1 <- querxc(qword = 'Phaethornis anthophilus', download = FALSE)
#' View(df1)
#'
#' # downloading files
#'querxc(qword = 'Phaethornis anthophilus', download = TRUE)
#'
#' # check this folder
#' getwd()
#' 
#' ## search using xeno-canto advance query ###
#' orth.pap <- querxc(qword = 'gen:orthonyx cnt:papua loc:tari', download = FALSE)
#'  
#' # download file using the output data frame as input
#' querxc(X = orth.pap)
#' 
#' # use quotes for queries with more than 1 word (e.g. Costa Rica),note that the 
#' # single quotes are used for the whole 'qword' and double quotes for the 2-word term inside
#' #Phaeochroa genus in Costa Rica 
#' phae.cr <- querxc(qword = 'gen:phaeochroa cnt:"costa rica"', download = FALSE)
#' 
#' # several terms can be searched for in the same field
#' # search for all female songs in sound type
#' femsong <- querxc(qword = 'type:song type:female', download = FALSE)
#' }
#' @author Marcelo Araya-Salas (\email{araya-salas@@cornell.edu}) 
#last modification on nov-16-2016 (MAS)

querxc <- function(qword, download = FALSE, X = NULL, file.name = c("Genus", "Specific_epithet"), 
                   parallel = 1, path = NULL, pb = TRUE) {
  
  #check path to working directory
  if(!is.null(path))
  {wd <- getwd()
  if(class(try(setwd(path), silent = TRUE)) == "try-error") stop("'path' provided does not exist") else 
    setwd(path)} #set working directory
  
  #check internet connection
  a <- try(RCurl::getURL("www.xeno-canto.org"), silent = TRUE)
  if(substr(a[1],0,5) == "Error") stop("No connection to xeno-canto.org (check your internet connection!)")
  
  if(a == "Could not connect to the database")  stop("xeno-canto.org website is apparently down")
  
  # If parallel is not numeric
  if(!is.numeric(parallel)) stop("'parallel' must be a numeric vector of length 1") 
  if(any(!(parallel %% 1 == 0),parallel < 1)) stop("'parallel' should be a positive integer")
  
  #if parallel and pb in windows
  if(parallel > 1 &  pb & Sys.info()[1] == "Windows") {
    message("parallel with progress bar is currently not available for windows OS")
    message("running parallel without progress bar")
    pb <- FALSE
  } 
  
  file.name <- gsub(" ", "_", file.name) 
  file.name <- tolower(file.name) 
  
  if(is.null(X) & !is.null(file.name))  
  {
    
    if(any(!(file.name %in%
             c("recording_id", "genus", "specific_epithet", "subspecies", "english_name", "recordist"   , 
               "country", "locality", "latitude", "longitude", "vocalization_type", "audio_file",        "license",
               "url", "quality", "time", "date")))) stop("File name tags don't match column names in the output of this function (see documentation)")
  }
  
  
  if(is.null(X))
  {
    
    #search recs in xeno-canto (results are returned in pages with 500 recordings each)
    if(any(parallel == 1, Sys.info()[1] == "Linux") & pb)
      message("Obtaining recording list...")
    
    #format JSON
    qword <- gsub(" ", "%20", qword)
    
    #initialize search
    q <- rjson::fromJSON(, paste0("http://www.xeno-canto.org/api/2/recordings?query=", qword))
    
    if(as.numeric(q$numRecordings) == 0) message("No recordings were found") else {
      
      nms <- c("id", "gen", "sp", "ssp", "en", "rec", "cnt", "loc", "lat", "lng", "type", "file", "lic", "url", "q", "time", "date")
      
      #loop over pages
      if(pb) f <- pbapply::pblapply(1:q$numPages, function(y)
      {
        #search for each page
        a <- rjson::fromJSON(, paste0("http://www.xeno-canto.org/api/2/recordings?query=", qword, "&page=", y))  
        
        #put together as data frame
        d <-lapply(1:length(a$recordings), function(z) data.frame(t(unlist(a$recordings[[z]]))))
        
        d2 <- lapply(d,  function(x) 
        {
          if(!all(nms %in% names(x))){ 
            dif <- setdiff(nms, names(x))
            mis <- rep(NA, length(dif))
            names(mis) <- dif
            return(cbind(x, t(mis)))
          }
          return(x)
        })
        
        e <- do.call(rbind, d2)
        
        return(e)
      }
      ) else f <- lapply(1:q$numPages, function(y)
      {
        #search for each page
        a <- rjson::fromJSON(, paste0("http://www.xeno-canto.org/api/2/recordings?query=", qword, "&page=", y))  
        
        #put together as data frame
        d <-lapply(1:length(a$recordings), function(z) data.frame(t(unlist(a$recordings[[z]]))))
        
        d2 <- lapply(d,  function(x) 
        {
          if(!all(nms %in% names(x))){ 
            dif <- setdiff(nms, names(x))
            mis <- rep(NA, length(dif))
            names(mis) <- dif
            return(cbind(x, t(mis)))
          }
          return(x)
        })
        
        e <- do.call(rbind, d2)
        
        return(e)
      }
      )
      
      results <- do.call(rbind, f)
      
      #order columns
    results <- results[ ,order(match(names(results), nms))]
    
    names(results) <- c("Recording_ID", "Genus", "Specific_epithet", "Subspecies", "English_name", "Recordist", 
                        "Country", "Locality", "Latitude", "Longitude", "Vocalization_type", "Audio_file",        "License",
                        "Url", "Quality", "Time", "Date")[1:ncol(results)]
  
    
    #remove duplicates
    results <- results[!duplicated(results$Recording_ID), ]
    
    if(pb)
      message(paste( nrow(results), " recordings found!", sep=""))  
    } 
  } else { 
    #stop if X is not a data frame
    if(class(X) != "data.frame") stop("X is not a data frame")
    
    #stop if the basic columns are not found
    if(!is.null(file.name))
    {if(any(!c(file.name, "recording_id") %in% tolower(colnames(X)))) 
      stop(paste(paste(c(file.name, "recording_id")[!c(file.name, "recording_id") %in% tolower(colnames(X))], collapse=", "), "column(s) not found in data frame"))} else
        if(!"recording_id" %in% colnames(X)) 
          stop("Recording_ID column not found in data frame")
    
    download <- TRUE
    results <- X  
  }
  
  #download recordings
  if(download) {
    if(any(file.name == "recording_id")) file.name <- file.name[-which(file.name == "recording_id")]
    
    if(!is.null(file.name))  {  if(length(which(tolower(names(results)) %in% file.name)) > 1)
      fn <- apply(results[,which(tolower(names(results)) %in% file.name)], 1 , paste , collapse = "-" ) else 
        fn <- results[,which(tolower(names(results)) %in% file.name)]
      results$sound.files <- paste(paste(fn, results$Recording_ID, sep = "-"), ".mp3", sep = "")     
    } else
      results$sound.files <- paste(results$Recording_ID, ".mp3", sep = "")   
    
    
    xcFUN <-  function(results, x){
      if(!file.exists(results$sound.files[x]))
        download.file(url = paste("http://xeno-canto.org/download.php?XC=", results$Recording_ID[x], sep=""), destfile = results$sound.files[x],
                      quiet = TRUE,  mode = "wb", cacheOK = TRUE,
                      extra = getOption("download.file.extra"))
      return (NULL)
    }
    if(any(parallel == 1, Sys.info()[1] == "Linux") & pb)
      message("Downloading sound files...")

      
  if(parallel > 1) {if(Sys.info()[1] == "Windows") 
    {
    
    x <- NULL #only to avoid non-declared objects
    
    cl <- parallel::makeCluster(parallel)
    
    doParallel::registerDoParallel(cl)
    
    a1 <- parallel::parLapply(cl, 1:nrow(results), function(x)
    {
      xcFUN(results, x) 
    })
    
    parallel::stopCluster(cl)
    
  } 
    
    if(Sys.info()[1] == "Linux") {    # Run parallel in Linux
      
     if(pb) 
       a1 <- pbmcapply::pbmclapply(1:nrow(results), mc.cores = parallel, function(x) {
         xcFUN(results, x)  })  else
       a1 <- parallel::mclapply(1:nrow(results), mc.cores = parallel, function(x) {
      xcFUN(results, x) })
    }
    if(!any(Sys.info()[1] == c("Linux", "Windows"))) # parallel in OSX
    {
      cl <- parallel::makePSOCKcluster(getOption("cl.cores", parallel))
      
       doParallel::registerDoParallel(cl)
 
      a1 <- foreach::foreach(x = 1:nrow(results)) %dopar% {
            xcFUN(results, x)
      }
      
      parallel::stopCluster(cl)
    }
    
  } else {
    if(pb)
       a1 <- pbapply::pblapply(1:nrow(results), function(x) 
  { 
      xcFUN(results, x) 
  }) else
    a1 <- lapply(1:nrow(results), function(x) 
    { 
      xcFUN(results, x) 
    })
  }
  
if(pb)
   message("double-checking downloaded files")
   
   #check if some files have no data
    fl <- list.files(pattern = ".mp3$")
    size0 <- fl[file.size(fl) == 0]
   
    #if so redo those files
    if(length(size0) > 1)
  {  Y <- results[results$sound.files %in% size0, ]
     unlink(size0)
     
    
     
       if(parallel > 1) {if(Sys.info()[1] == "Windows") 
    {
    
    x <- NULL #only to avoid non-declared objects
    
    cl <- parallel::makeCluster(parallel)
    
    doParallel::registerDoParallel(cl)
    
    a1 <- parallel::parLapply(cl, 1:nrow(Y), function(x)
    {
      xcFUN(Y, x) 
    })
    
    parallel::stopCluster(cl)
    
  } 
    
    if(Sys.info()[1] == "Linux") {    # Run parallel in Linux
      
    if(pb)
      a1 <- pbmcapply::pbmclapply(1:nrow(Y), mc.cores = parallel, function(x) {
        xcFUN(Y, x) }) else      
        a1 <- parallel::mclapply(1:nrow(Y), mc.cores = parallel, function(x) {
      xcFUN(Y, x) })
    }
    if(!any(Sys.info()[1] == c("Linux", "Windows"))) # parallel in OSX
    {
      cl <- parallel::makePSOCKcluster(getOption("cl.cores", parallel))
      
       doParallel::registerDoParallel(cl)
 
      a1 <- foreach::foreach(x = 1:nrow(Y)) %dopar% {
            xcFUN(Y, x)
      }
      
      parallel::stopCluster(cl)
    }
    
  } else {
    if(pb)
    a1 <- pbapply::pblapply(1:nrow(Y), function(x) 
  { 
      xcFUN(Y, x) 
  }) else
    a1 <- lapply(1:nrow(Y), function(x) 
    { 
      xcFUN(Y, x) 
    })
  
  }
     
     
     }
    
    
  }
 if(is.null(X)) if(as.numeric(q$numRecordings) > 0) return(droplevels(results))
    if(!is.null(path)) setwd(wd)
   }
