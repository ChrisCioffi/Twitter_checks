


#here's the doc. Helpful when you're trying to find user-class itens like followers, friends, etc. https://cran.r-project.org/web/packages/twitteR/twitteR.pdf

library(tidyverse)
library(twitteR)
#Thanks to SARA WISE for the renvirontrick to store api keys
#access api info from: open your preferred terminal app, type in nano ~/.Renviron  then paste in these two lines
#those ^ are your keys, as pushed to git. after that, press ctrl+X to exit and then Y to save the file as modified.

consumer_key <- Sys.getenv("TWITTER_CONSUMER_KEY")
consumer_secret <- Sys.getenv("TWITTER_CONSUMER_SECRET")
access_token <- Sys.getenv("TWITTER_ACCESS_TOKEN")
access_secret <- Sys.getenv("TWITTER_ACCESS_SECRET")
#Log your info with the Twitter API:
options(httr_oauth_cache=T) #This will enable the use of a local file to cache OAuth access credentials between R sessions.
setup_twitter_oauth(consumer_key,
                    consumer_secret,
                    access_token,
                    access_secret)
#######
#https://www.rdocumentation.org/packages/rtweet/versions/0.6.9
# Step 2: Download the Followers of a Given Twitter Account
#######
reportercioffi <- getUser("reportercioffi")
AOC <- getUser("AOC")
#See this user's location:
AOC$location

#Download data on this user's followers:
cioffi_follower_ids<-reportercioffi$getFollowers(retryOnRateLimit=180)
length(cioffi_follower_IDs)
AOC_follower_ids<-AOC$getFollowers(retryOnRateLimit=180)
length(AOC_follower_ids)

#to get who the account is following....
cioffi_friend_ids <-reportercioffi$getFriends(retryOnRateLimit=250)
length(cioffi_friend_ids)
#######




# Step 3: Organize the data you've just collected:
#######
#Install / load the "data.table" package:
if (!require("data.table")) {
  install.packages("data.table", repos="http://cran.rstudio.com/") 
  library("data.table")
}
#Turn this data into a data frame:
cioffi_followers_df <- rbindlist(lapply(cioffi_follower_ids,as.data.frame))


#turn friend list into df
cioffi_friends_df <- rbindlist(lapply(cioffi_friend_ids,as.data.frame))

write_csv(ratcliffe_friends_df , "ratcliffe_following.csv") 
write_csv(TXratcliffe_friend_DF  , "TXratcliffe_following.csv") 

#Quick quick of length:
head(lucaspuente_followers_df$location, 10)
#Remove entries with blank locations:
lucaspuente_followers_df<-subset(lucaspuente_followers_df, location!="")
#######
# Step 4: Geocode Followers' Locations
#######
#Remove special characters:
lucaspuente_followers_df$location<-gsub("%", " ",lucaspuente_followers_df$location)
#Install key package helpers:
source("https://raw.githubusercontent.com/LucasPuente/geocoding/master/geocode_helpers.R")
#Install modified version of the geocode function
#(that now includes the api_key parameter):
source("https://raw.githubusercontent.com/LucasPuente/geocoding/master/modified_geocode.R")
#Generate specific geocode function:
geocode_apply<-function(x){
  geocode(x, source = "google", output = "all", api_key="[INSERT YOUR GOOGLE API KEY HERE]")
}
#Apply this new function to entire list:
geocode_results<-sapply(lucaspuente_followers_df$location, geocode_apply, simplify = F)
#Look at the number of geocoded locations:
length(geocode_results)
#######
# Step 5: Clean Geocoding Results
#######
#Only keep locations with "status" = "ok"
condition_a <- sapply(geocode_results, function(x) x["status"]=="OK")
geocode_results<-geocode_results[condition_a]
#Only keep locations with one match:
condition_b <- lapply(geocode_results, lapply, length)
condition_b2<-sapply(condition_b, function(x) x["results"]=="1")
geocode_results<-geocode_results[condition_b2]
#Look at the number of *successfully* geocoded locations:
length(geocode_results)
#Address formatting issues:
source("https://raw.githubusercontent.com/LucasPuente/geocoding/master/cleaning_geocoded_results.R")
#Turn list into a data.frame:
results_b<-lapply(geocode_results, as.data.frame)
results_c<-lapply(results_b,function(x) subset(x, select=c("results.formatted_address", "results.geometry.location")))
#Format thes new data frames:
results_d<-lapply(results_c,function(x) data.frame(Location=x[1,"results.formatted_address"],
                                                   lat=x[1,"results.geometry.location"],
                                                   lng=x[2,"results.geometry.location"]))
#Bind these data frames together:
results_e<-rbindlist(results_d)
#Add info on the original (i.e. user-provided) location string:
results_f<-results_e[,Original_Location:=names(results_d)]
#Only keep American results:
american_results<-subset(results_f,
                         grepl(", USA", results_f$Location)==TRUE)
head(american_results,5)
#Remove entries that are too vague:
american_results$commas<-sapply(american_results$Location, function(x)
  length(as.numeric(gregexpr(",", as.character(x))[[1]])))
american_results<-subset(american_results, commas==2)
#Drop the "commas" column:
american_results<-subset(american_results, select=-commas)
#Examine number of successes:
nrow(american_results)
#######
# Step 6: Map the Geocoded Results
#######
#Load Relevant Packages:
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}
packages <- c("maps", "mapproj", "splancs")
ipak(packages)
#Generate a blank map:
albers_proj<-map("state", proj="albers", param=c(39, 45), col="#999999", fill=FALSE, bg=NA, lwd=0.2, add=FALSE, resolution=1)
#Add points to it:
points(mapproject(american_results$lng, american_results$lat), col=NA, bg="#00000030", pch=21, cex=1.0)
#Add a title:
mtext("The Geography of @LucasPuente's Followers", side = 3, line = -3.5, outer = T, cex=1.5, font=3)
#For more on mapping, see: http://flowingdata.com/2014/03/25/how-to-make-smoothed-density-maps-in-r/.