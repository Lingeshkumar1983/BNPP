# BNPP Practicetest

Parameters:
===========

script  summarize-enron.py takes input csv file as parameter.
Eg: summarize-enron.py enron-event-history-all.csv

Code Logic:
===========

1. Load csv file to dataframe and name the columns
2. Recpient column is '|' delimited. Explode this field into a seperate dataframe.
3. Combine Raw and exploded dataframes (Bascially now the data is having 1 to many records).
4. Split two dataframes a) sender and its count (at year/month level) v) Recpient and its count (year/month level).
5. Merge - Outerjoin the two dataframes built in (4). There will be only one name i.e People
6. Aggregate the dataframe built in 5 at People level to get sender/recipient counts and generate the output.
7. Using the (5) & (6) some meaning full visulizations are generated.
      -- Top10 senders bar plot
      -- Top10 senders/recipients bar plot for each year
      -- A bar plot to show the monthly split of sender/recipient counts
      -- A plot bult taking the difference of sender count and recipient count ( at year/month level ) to show the change overtime
      
 Other Considerations( Not taken due to not time constraint ):
 =============================================================
 
1) Exception handlings not built
2) Could have done better in reusability & efficiency in the code
3) Have done sample checks but didn't do through unit testing so not captured any test results

 
