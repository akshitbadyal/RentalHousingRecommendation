---
title: "Housing Recommendation"
author: "Akshit Badyal"
date: "09/12/2021"
output:
  pdf_document: default
  word_document: default
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
library(ggplot2)
library(waffle)
library(textdata)
library(reshape2)
library(factoextra)
library(tidyr)
library(tidytext)
library(dplyr) 
library(tm)
library(lubridate)
library(fpc)
library(lemon)
library(readr)
library(magrittr)
library(stringr)
library(devtools)
library(clValid)
library(knitr)
library(rmarkdown)
library(markdown)
library(datasets)
library(plotly)
library(wordcloud)
```
# Loading the Datasets:
```{r}
event_types<-read.csv("C:/Users/Adity/Desktop/Recommender/event_types.csv",
             na.strings = "")
property<-read.csv("C:/Users/Adity/Desktop/Recommender/property.csv",
                      na.strings = "")
user_activity<-read.csv("C:/Users/Adity/Desktop/Recommender/user_activity.csv",
                      na.strings = "")
ads_df <- read.csv("C:/Users/Adity/Desktop/Recommender/room-rental-ads.csv",
                      na.strings = "")
```
#Data Wrangling:
```{r}
#Creating date & time columns
user_activity <-
  user_activity %>%
  mutate(
    New_Date=ymd_hms(create_timestamp,tz=Sys.timezone())
  )

user_activity$Date <- as.Date(user_activity$New_Date)

user_activity$Time <- format(user_activity$New_Date,"%H:%M:%S")
```

```{r}
#Checking for NA's:
sum(((is.na(property$monthly_rent)))) 
sum(((is.na(property$building_floor_count))))
#1648 missing values in floor count.
sum(((is.na(property$unit_floor))))
# 37 missing values
sum(((is.na(property$property_age))))
# 4 missing values
sum(((is.na(property$unit_area))))
sum(((is.na(property$deposit))))
# 5 missing values
sum(((is.na(property$room_qty))))
# 3 missing values
```
```{r}
#Removing NA's:

property_clean <- na.omit(property)
```

```{r}
#Correlation matrix for different features:
property_num <- property_clean %>% select(deposit,monthly_rent,room_qty, 
                                          unit_area)
cormat <- round(cor(property_num),2)
head(cormat)
melted_cormat <- melt(cormat)
```

```{r}
property_num2 <- property_clean %>% select(deposit,monthly_rent,room_qty, 
                                          unit_area, property_age, building_floor_count)
cormat2 <- round(cor(property_num2),2)
head(cormat2)
melted_cormat2 <- melt(cormat2)
```

```{r}
#Lower and upper triangles:
get_lower_tri<-function(cormat){
  cormat[lower.tri(cormat)] <- NA
  return(cormat)
}
# Get upper triangle of the correlation matrix
get_upper_tri <- function(cormat){
  cormat[upper.tri(cormat)]<- NA
  return(cormat)
}
```

```{r}
reorder_cormat <- function(cormat){
  # Use correlation between variables as distance
  dd <- as.dist((1-cormat)/2)
  hc <- hclust(dd)
  cormat <-cormat[hc$order, hc$order]
}
# Reorder the correlation matrix
cormat <- reorder_cormat(cormat)
upper_tri <- get_upper_tri(cormat)
# Melt the correlation matrix
melted_cormat <- melt(upper_tri, na.rm = TRUE)
```

```{r}
#Creating a heatmap:
ggheatmap <- ggplot(melted_cormat, aes(Var2, Var1, fill = value))+
  geom_tile(color = "white")+
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                       midpoint = 0, limit = c(-1,1), space = "Lab", 
                       name="Pearson\nCorrelation") +
  theme_minimal()+ # minimal theme
  theme(axis.text.x = element_text(angle = 45, vjust = 1, 
                                   size = 12, hjust = 1))+
  coord_fixed()
```

```{r}
#Final heatmap:
ggheatmap + 
  geom_text(aes(Var2, Var1, label = value), color = "black", size = 4) +
  theme(
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.grid.major = element_blank(),
    panel.border = element_blank(),
    panel.background = element_blank(),
    axis.ticks = element_blank(),
    legend.justification = c(1, 0),
    legend.position = c(1.05, 0.2),
    legend.direction = "horizontal")+
  guides(fill = guide_colorbar(barwidth = 7, barheight = 1,
                               title.position = "top", title.hjust = 0.5))
```
#Conditional Probabilities for user activity event types:
```{r}
user_activity_summarized<- user_activity %>% group_by(event_type) %>% summarize(total=n())
```

```{r}
#Catalogue links sent vs visits requested:
events <- c(`Catalogs Sent:`=9520, `Visits Requested:`=5285)
```

```{r}
waffle(events/1000, rows=1, size=0.6, 
       colors=c("#44D2AC", "#E48B8B"), 
       title="Visits Requested after viewing Catalog:", 
       xlab="1 square = 2000 persons")
```
```{r}
events_1<- c(`Visit Requests`=5285, `Requests Cancelled`=2521)
waffle(events_1/500, rows=1, size=0.6, 
       colors=c("#44D2AC", "#E48B8B"), 
       title="Visit Requests Cancelled:", 
       xlab="1 square = 500 persons")
```
```{r}
events_3<- c( `Visit Successful`=288,`Visit Unseccessful`=986, `Need to follow up`=1586)
waffle(events_3/250, rows=2, size=0.6, 
       colors=c("#44D2AC", "#E48B8B", "#B67093"), 
       title="Apartments Booked on visit", 
       xlab="1 square = 250 persons")
```


#Clustering:

#PAM:
```{r}
property_scaled <- scale(property_num)
fviz_nbclust(property_scaled, FUNcluster = pam, method = "silhouette")+theme_classic()
```
```{r}
property_scaled2 <- scale(property_num2)
fviz_nbclust(property_scaled2, FUNcluster = pam, method = "silhouette")+theme_classic()
```

```{r}
pam.res <-  pam(property_scaled, 2, metric ='euclidean')
```
```{r}
pam2.res <-  pam(property_scaled2, 2, metric ='euclidean')
```

```{r}
property_scaled$cluster = pam.res$cluster
head(property_scaled)
```
```{r}
pam.res$medoids
```
```{r}
property_scaled2$cluster = pam2.res$cluster
head(property_scaled2)
pam.res$medoids
```
```{r}
fviz_cluster(pam2.res, 
             palette =c("#007892","#D9455F"),
             ellipse.type ="euclid",
             repel =TRUE,
             ggtheme =theme_minimal())
```


```{r}
fviz_cluster(pam.res, 
             palette =c("#007892","#D9455F"),
             ellipse.type ="euclid",
             repel =TRUE,
             ggtheme =theme_minimal())
```
```{r}
pam.res$medoids
```
# 1878 86400000 1080000 2 85 4 3 14
# 1981 64800000 864000 1 58 4 2 14


# Text mining:

```{r}
ads_clean <- ads_df %>%
unnest_tokens(word, Description) %>% 
  anti_join(stop_words,by='word') %>% 
  filter(str_detect(word,"[:alpha:]")) 
```

```{r}
words_count<- ads_df %>%
unnest_tokens(word, Description) %>% 
  anti_join(stop_words,by='word') %>% 
  count(word, sort = TRUE)%>% 
  filter(str_detect(word,"[:alpha:]")) %>% 
  distinct()

head(words_count,10) %>% ggplot( aes(x =n, y=word )) +
geom_bar(stat="identity")+
ggtitle("The most common words in Housing Ads.")+
labs(x="Word", y="Occurences")+
coord_flip()+
theme_minimal()+
theme(axis.text.x = element_text(face="bold",
size=10))
```

```{r}

set.seed(1234) 
wordcloud(words = words_count$word, freq = words_count$n, min.freq = 1, max.words=200, random.order=FALSE, rot.per=0.35,colors=brewer.pal(8, "Dark2"))

```


#Sentiment Analysis:
```{r}
get_sentiments("nrc") %>%
group_by(sentiment) %>% 
  summarise(total=n())
```
```{r}
nrc_pos <- get_sentiments("nrc") %>%
filter(sentiment == "positive")

nrc_joy <- get_sentiments("nrc") %>%
filter(sentiment == "joy")

nrc_trust <- get_sentiments("nrc") %>%
filter(sentiment == "trust")
```

```{r}
ad_word_counts <- ads_clean %>%
inner_join(get_sentiments("bing")) %>%
count(word, sentiment, sort = TRUE) %>%
ungroup()
kable(head(ad_word_counts,10)) 
```
```{r}
ads_clean %>%
inner_join(get_sentiments("bing")) %>%
count(word, sentiment, sort = TRUE) %>%
  group_by(sentiment) %>% 
  summarise(total=n())
```



```{r}
ad_word_counts %>% head(10) %>%   ggplot(aes(n, word, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~sentiment, scales = "free_y") +
  labs(x = "Contribution to sentiment",
       y = NULL)
```
```{r}
ad_word_counts %>%filter(sentiment=='negative') %>% head(10) %>%   ggplot(aes(n, word, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~sentiment, scales = "free_y") +
  labs(x = "Contribution to sentiment",
       y = NULL)
```

# Word Cloud:
```{r}
ads_clean %>%
inner_join(get_sentiments("bing")) %>%
count(word, sentiment, sort = TRUE) %>%
acast(word ~ sentiment, value.var = "n", fill = 0) %>%
comparison.cloud(colors = c("red", "green"),
max.words = 100)
```
```{r}
user_activity_short<- user_activity %>% filter(event_type!='seen',event_type!='seen_in_list')
```

