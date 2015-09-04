# Bench Rest Test
Rest Test for Bench interview

To run:

`ruby bookkeeper.rb`

Notes:

On the assingment page it mentions:

```Returns a list of transactions as well as a totalBalance, totalCount, and page number.
The totalCount tells you the total number of transactions.```

However, the `totalBalance` isn't something that is returned by the API. I think this is a typo, as the objective of the assignment is to calculate that.

There are some limitations to cleaning the vendor names:
- If there is a stop word in the vendor name, then it will remove it, i.e., VANCOUVER CABS => CABS
- Looking at the data, location is always at the end, modify to factor that into account.

If the fetch encounters a non 2XX response from the server it will stop fetching and proceed with processing.

I copied a useful function from ActiveRecord to do some string manipulation.

I attempted the extra credit options with the exception of the deduplicating. I lost track of time working on the name cleaning. That problem is a rabbit hole that dissertations can be written on.
