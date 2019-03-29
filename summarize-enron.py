#!/usr/bin/python

###############################################################################################################
# Import required packages & assign variables
###############################################################################################################
import pandas as pd
import numpy as np
import datetime
import matplotlib.pyplot as plt
import sys

fname= sys.argv[1]
yearlist=[1998,1999,2000,2001,2002]

###############################################################################################################
# Read the input csv file and create a dataframe
###############################################################################################################
df_raw=pd.read_csv(fname,names = ["time", "message_identifier", "sender", "recipients","topic","mode"])

###############################################################################################################
# Explode the recipients column ( 1 to many ) Eg: lingeshkumar.n@gmail.com|john smith -- to two rows
# (lingeshkumar.n@gmail.com,john smith ) with same index value
###############################################################################################################
df_explode=df_raw.recipients.str.split('|', expand=True).stack().str.strip().reset_index(level=1, drop=True)
df_explode.name='recipient'
###############################################################################################################
# Join the exploded dataframe back to the raw data frame loaded at the begining
###############################################################################################################
df_raw_explode=df_raw.drop(['recipients'], axis=1).join(df_explode).reset_index(drop=True)
df_raw_explode['sender']= df_raw_explode.sender.str.lower()
df_raw_explode['recipient']= df_raw_explode.recipient.str.lower()
###############################################################################################################
#Convert time in milliseconds to datetimestamp and add year/month fields
###############################################################################################################
df_raw_explode['message_creation_dttime'] = (df_raw_explode['time']/(1000)).apply(lambda x: datetime.datetime.fromtimestamp(x))
df_raw_explode['year']=df_raw_explode['message_creation_dttime'].dt.year
df_raw_explode['month']=df_raw_explode['message_creation_dttime'].dt.month

###############################################################################################################
# df_sender dataframe  - with sender and its email count
# df_recipient dataframe  - with receipient and its email count
###############################################################################################################

df_sender=df_raw_explode.groupby(['sender','year','month'],as_index=True).agg({"time": "count"}).sort_values("time",ascending=False).reset_index().rename(columns={'time': 'sender_count'}).fillna(0)
df_recipient=df_raw_explode.groupby(['recipient','year','month'],as_index=True).agg({"time": "count"}).sort_values("time",ascending=False).reset_index().rename(columns={'time': 'recipient_count'}).fillna(0)

###############################################################################################################
# Merge - outer join both sender and recipient dataframes and fill the null values to zero.
###############################################################################################################

df_merged_sender_recipient=pd.merge(df_sender,df_recipient, how='outer',left_on=('year','month','sender'),right_on=('year','month','recipient'))
df_merged_sender_recipient['people'] = np.where(df_merged_sender_recipient["sender"].isnull() == True, df_merged_sender_recipient["recipient"], df_merged_sender_recipient["sender"] )
df_merged_sender_recipient.drop(['recipient','sender'],axis=1,inplace=True)
df_merged_sender_recipient_year=df_merged_sender_recipient[['year','people','sender_count','recipient_count']].groupby(['people','year'],as_index=True).agg({"sender_count": "sum","recipient_count": "sum"}).sort_values('sender_count', ascending=False).reset_index().fillna(0)


###############################################################################################################
# Add sender and recipient rank in descending counts. The highest count gets rank in that particular year
###############################################################################################################

df_merged_sender_recipient_year['sender_count_rank'] = df_merged_sender_recipient_year.groupby(['year'])['sender_count'].rank("dense",ascending=False)
df_merged_sender_recipient_year['recipient_count_rank'] = df_merged_sender_recipient_year.groupby(['year'])['recipient_count'].rank("dense",ascending=False)
df_merge_out=df_merged_sender_recipient_year.groupby(['people'],as_index=True).agg({"sender_count": "sum","recipient_count": "sum"}).sort_values("sender_count",ascending=False).reset_index()

###############################################################################################################
# Solution1 output: Generate the First output file with People ( sender/recipient ) and its counts
###############################################################################################################
df_merge_out.to_csv("out_sender_recepient_count.csv",index=False)

###############################################################################################################
# Filter top 5 records with highest count for sender or recipient and plot the graph
###############################################################################################################
Filtered_records=df_merged_sender_recipient_year[((df_merged_sender_recipient_year['sender_count_rank'] >= 1) & (df_merged_sender_recipient_year['sender_count_rank'] <= 5)) | ((df_merged_sender_recipient_year['recipient_count_rank'] >= 1) & (df_merged_sender_recipient_year['recipient_count_rank'] <= 5)) ]

###############################################################################################################
# Use the solution(1) output and plot to show top 10 senders bar diagram
###############################################################################################################
df_merge_out[['people','sender_count']].head(10).plot(x='people', kind='bar')
plt.savefig('Top_10_Senders.png',bbox_inches='tight')

###############################################################################################################
# Solution2 output: Plot the graph for each year showing the top5 senders and recipients in a single diagram.
###############################################################################################################
for i in yearlist:
    df_plot=Filtered_records[Filtered_records['year'] == i]
    df_plot[['people','sender_count','recipient_count']].plot(x='people', kind='bar')
    plt.title('Top 10 sender & recipient count for year {}'.format(i))
    plt.xlabel("People")
    plt.savefig('Top_10_SendersandRecipients_for_{}.png'.format(i),bbox_inches='tight')

###############################################################################################################
# Solution3 output : Generate bar chart of sender/recipient at year/month level. Also generates difference
# of sender and recpient at year/month level
###############################################################################################################

df_temp=df_merged_sender_recipient[['year','month','sender_count','recipient_count']].fillna(0).astype(int)
df_plot3=df_temp.groupby(['year','month'],as_index=True).agg({"sender_count":"sum","recipient_count":"sum" }).sort_values('sender_count', ascending=False).reset_index().fillna(0)
df_plot3['datetime']=pd.to_datetime(df_plot3['year'].astype(str)  + df_plot3['month'].astype(str), format='%Y%m')
df_plot3.set_index('datetime', inplace=True)
df_plot3.drop(['year','month'], axis=1, inplace=True)
df_plot3.plot(kind='bar',figsize=(20,10), linewidth=5, fontsize=20)
plt.savefig('Sender_recipient_yearmonth_count_breakdown.png',bbox_inches='tight')
df_plot3['relative_recipient_diff_with_sender']= df_plot3['sender_count'] - df_plot3['recipient_count']
df_plot3.drop(['sender_count','recipient_count'], axis=1, inplace=True)
df_plot3.plot()
plt.savefig('recipient_relative_difference_of_Sender_yearmonth.png',bbox_inches='tight')
