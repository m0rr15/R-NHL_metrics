
# descriptive_1314.R
# Morris Trachsler, 2014
#
# This script loads, cleans and plays around with the retrieved NHL data 
# (sections "VARIABLE TREATMENT", "DESCRIPTIVE STATS"). In the 
# "STATISTICS" section, it computes the probabilities and marginal probabilites 
# of winning a game in function of the Goals scored For and Against. Hence, it 
# reckons the value of the i'th goal scored. I will use this marginal
# probability in another script (true_scorers_1314.R) to propose an alternative 
# top scorer list.


# Load Packages, set working Dir, load data
library("biglm", lib.loc="~/R/win-library/3.1")
library("bitops", lib.loc="~/R/win-library/3.1")
library("nhlscrapr", lib.loc="~/R/win-library/3.1")
library("RCurl", lib.loc="~/R/win-library/3.1")
library("rjson", lib.loc="~/R/win-library/3.1")
library("ggplot2", lib.loc="~/R/win-library/3.1")
library("lmtest", lib.loc="~/R/win-library/3.1")
library("rstudio", lib.loc="~/R/win-library/3.1")
library("graphics", lib.loc="~/R/win-library/3.1")
library("stats", lib.loc="~/R/win-library/3.1")
library("plyr", lib.loc="~/R/win-library/3.1")
library("psych", lib.loc="~/R/win-library/3.1")
library("MASS", lib.loc="C:/Program Files/R/R-3.1.1/library")
library("reshape2", lib.loc="~/R/win-library/3.1")

# Set Working Directory
setwd("C:/Users/morris/Desktop/RR")
# Load NHL data
load("C:/Users/morris/Desktop/RR/Season1314.RData")  
# remove unnecessary dfs
rm(distance.adjust, grand.data, roster.master, shot.tables, scoring.models)
colnames(games)  # print variable names in games

# VARIABLE TREATMENT ---------------------------------------------------------
# POINTS WON, at home and on the road
games$awaypoints <- 0
games$homepoints <- 0
attach(games)
games$awaypoints[session == "Regular" & periods >= 3 &
                   awayscore > homescore] <- 2
games$awaypoints[session == "Regular" & periods  > 3 &
                   awayscore < homescore] <- 1

games$homepoints[session == "Regular" & periods >= 3 &
                   awayscore < homescore] <- 2
games$homepoints[session == "Regular" & periods > 3 &
                   awayscore > homescore] <- 1
games$awaypoints[session == "Playoffs" & awayscore > homescore] <- 2
games$homepoints[session == "Playoffs" & awayscore < homescore] <- 2
detach(games)
attach(games) # change type to factor
games$awaypoints <- factor(awaypoints,ordered=TRUE)
games$homepoints <- factor(homepoints,ordered=TRUE)
detach(games)

# GOALS SCORED (numeric)
attach(games)
games$awayscore <- as.numeric(awayscore)
games$homescore <- as.numeric(homescore)
detach(games)

# DESCRIPTIVE STATS ------------------------------------------------------
# TABLES
attach(games)
gpaway <- table(awayscore,awaypoints)
gpmaway <- prop.table(gpaway,1)
gphome <- table(homescore,homepoints)
gpmhome <- prop.table(gphome,1)
detach(games)
gpaway
gpmaway
gphome
gpmhome
# CROSS TABLES
ftable(xtabs(~ awayscore + awaypoints, data=games))
ftable(xtabs(~ homescore + homepoints, data=games))
# SCATTER PLOTS
attach(games)
plot(awayscore,awaypoints, main="Goals and Points", type="p",
     xlab="Goals scored", ylab="Points won", col=2)
# abline(lm(mpg~wt), col="red") # regression line (y~x)
#lines(lowess(awayscore,awaypoints), col="blue") # lowess line (x,y) 
par(new=T)
plot(homescore,homepoints, main="Goals and Points", type="p",
     xlab="Goals scored", ylab="Points won", axes=F, col=3)
par(new=T)
detach(games)

# STATISTICS -----------------------------------------------------------------
# There are more important goals than others! How much is the n'th scored goal
# worth? -> ORDERED LOGIT/PROBIT regressions
p_sfor.away.logit <- polr(awaypoints ~ awayscore, data=games, method="logistic")
p_sfor.home.logit <- polr(homepoints ~ homescore, data=games, method="logistic")
p_sag.away.logit <- polr(awaypoints ~ homescore, data=games, method="logistic")
p_sag.home.logit <- polr(homepoints ~ awayscore, data=games, method="logistic")

# Postestimation
# Points ~ Goals FOR
p_s.for.dat <- data.frame(cbind(  # cont. var from zero to ten
  awayscore = seq(from=0, to=10,length.out=500),
  homescore = seq(from=0,to=10, length.out=500)))
p_s.for.dat <- cbind(  # predictions from logit regressions
  p_s.for.dat,
  predict(p_sfor.away.logit,p_s.for.dat,type="probs"),
  predict(p_sfor.home.logit,p_s.for.dat,type="probs"))
p_s.for.dat <- p_s.for.dat[-c(3,4,6,7)]
p_s.for.dat <- rename(p_s.for.dat,c("2"="P2away","2.1"="P2home"))
p_s.for.dat.diff <- data.frame(cbind(  # MARGINAL probabilities
  dP2away = diff(p_s.for.dat$P2away)/diff(p_s.for.dat$awayscore),
  dP2home = diff(p_s.for.dat$P2home)/diff(p_s.for.dat$homescore),
  Score = p_s.for.dat$awayscore[-500]))
p_s.for.dat <- rename(p_s.for.dat,c("P2away"="Away","P2home"="Home"))
p_s.for.dat.diff <- rename(p_s.for.dat.diff,
                           c("dP2away"="Away","dP2home"="Home"))
p_s.for.dat  <- melt(
  p_s.for.dat,id.vars=c("awayscore","homescore"),
  variable.name="Location",value.name="Probability")  # tidy dataframes
p_s.for.dat.diff <- melt(
  p_s.for.dat.diff,id.vars=c("Score"),
  variable.name="Location",value.name="mProbability")  # tidy dataframes

# Points ~ Goals AGAINST
p_s.ag.dat <- data.frame(cbind(
  awayscore = seq(from=0, to=10, length.out=500),
  homescore = seq(from=0, to=10, length.out=500)))
p_s.ag.dat <- cbind(
  p_s.ag.dat,
  predict(p_sag.away.logit,p_s.ag.dat,type="probs"),
  predict(p_sag.home.logit,p_s.ag.dat,type="probs"))
p_s.ag.dat <- p_s.ag.dat[-c(3,4,6,7)]
p_s.ag.dat <- rename(p_s.ag.dat,c("2"="P2away","2.1"="P2home"))
p_s.ag.dat.diff <- data.frame(cbind(  # MARGINAL probabilities
  dP2away = diff(p_s.ag.dat$P2away)/diff(p_s.ag.dat$awayscore),
  dP2home = diff(p_s.ag.dat$P2home)/diff(p_s.ag.dat$homescore),
  Score = p_s.ag.dat$awayscore[-500]))
p_s.ag.dat <- rename(p_s.ag.dat,c("P2away"="Away","P2home"="Home"))
p_s.ag.dat.diff <- rename(p_s.ag.dat.diff,c("dP2away"="Away","dP2home"="Home"))
p_s.ag.dat <- melt(
  p_s.ag.dat,id.vars=c("awayscore","homescore"),
  variable.name="Location",value.name="Probability")  # tidy df
p_s.ag.dat.diff <- melt(
  p_s.ag.dat.diff,id.vars=c("Score"),
  variable.name="Location",value.name="mProbability")  # tidy df


# PLOTS-------------------------------------------------------------------------
ggplot(p_s.for.dat, aes(x=awayscore, y=Probability, colour=Location)) +
  geom_line() +
  xlab("Goals scored") +
  ylab("Probability") +
  ggtitle("Probability to win 2 points versus Goals Scored") +
  scale_x_continuous(breaks=seq(0, 10, 1))  # Ticks from 0-10, every 1
ggplot(p_s.for.dat.diff, aes(x=Score, y=mProbability, colour=Location)) +
  geom_line() +
  xlab("Goals scored") +
  ylab("Marginal Probability") +
  ggtitle("Marginal Probability to win 2 points versus Goals Scored") +
  scale_x_continuous(breaks=seq(0, 10, 1)) +
  scale_y_continuous(breaks=seq(0, 1, 0.05))

ggplot(p_s.ag.dat, aes(x=awayscore, y=Probability, colour=Location)) +
  geom_line() +
  xlab("Goals scored by opponent") +
  ylab("Probability") +
  ggtitle("Probability to win 2 points") +
  scale_x_continuous(breaks=seq(0, 10, 1))
ggplot(p_s.ag.dat.diff, aes(x=Score, y=mProbability, colour=Location)) +
  geom_line() +
  xlab("Goals scored by opponent") +
  ylab("Marginal Probability") +
  ggtitle("Marginal Probability to win 2 points") +
  scale_x_continuous(breaks=seq(0, 10, 1)) +
  scale_y_continuous(breaks=seq(0, 1, 0.05))

# Points ~ Goals For/Against
ggplot(p_s.for.dat, aes(x=awayscore,y=Probability, colour=Location)) +
  geom_line() +
  xlab("Goals scored") +
  ylab("Probability") +
  geom_line(data=p_s.ag.dat,
            aes(x=awayscore, y=Probability, colour=Location),
            show.legend=FALSE) +
  ggtitle("Probability to win 2 points versus Goals Scored for and against") +
  scale_x_continuous(breaks=seq(0, 10, 1))

ggplot(p_s.for.dat.diff, aes(x=Score, y=mProbability, colour=Location)) +
  geom_line() +
  xlab("Goals scored") +
  ylab("Marginal Probability") +
  ggtitle(paste("Marginal Probability to win 2 points versus Goals ", 
                "Scored for and against", sep="")) +
  geom_line(data=p_s.ag.dat.diff,
            aes(x=Score, y=mProbability, colour=Location),
            show.legend=FALSE) +
  scale_x_continuous(breaks=seq(0, 10, 1)) +
  scale_y_continuous(breaks=seq(-1, 1, 0.05))

# DESCRIPTIVE TABLES (0/1,1/2,2/3,....approx integral)
# again, calculating prob. to win 2 pts for each goal, discrete table
p_s.descr <- data.frame(cbind(awayscore=0:10,homescore=0:10))
p_s.descr <- cbind(p_s.descr,predict(p_sfor.away.logit,p_s.descr,type="probs"),
                predict(p_sfor.home.logit,p_s.descr,type="probs"))
p_s.descr <- p_s.descr[-c(3,4,6,7)]
p_s.descr <- rename(p_s.descr,c("2"="P2away","2.1"="P2home"))

p_s.descr$dP2away <- 0
p_s.descr$dP2away[p_s.descr$awayscore == 0] <- p_s.descr$P2away
p_s.descr$dP2away[p_s.descr$awayscore > 0] <- diff(p_s.descr$P2away)

p_s.descr$dP2home <- 0
p_s.descr$dP2home[p_s.descr$homescore == 0] <- p_s.descr$P2home
p_s.descr$dP2home[p_s.descr$homescore > 0] <- diff(p_s.descr$P2home)

# START OF SEASON VS END OF SEASON (DUMMY)
games$startend <- 0
games$startend[as.numeric(games$gamenumber) < 616 &
                 games$session == "Regular"] <- 1
games$startend[as.numeric(games$gamenumber) >= 616 &
                 games$session == "Regular"] <- 2
games$startend[games$session == "Playoffs"] <- 3

games$sumscore <- games$awayscore + games$homescore

ftable(xtabs(~ awayscore + startend, data = games))
ftable(xtabs(~ homescore + startend, data = games))
ftable(xtabs(~ sumscore + startend, data = games))

