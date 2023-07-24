# speedtest-basic-testing 

Works on all Linux and also Mac computers.

This is a simple bash script that tests, using the speedtest-cli, to get readings for the internet connection speed (download/upload) on the current network interface that is connected.
If the speedtest-cli is not present then it proceeds to install it automatically. 

 You can define:
 - when it will run
 - how many times
 - how much time to elapse during each run
 - where to save the end results  (append the results in a csv and do the same in case there is an error during the test)

There is good input sanitization but could be improved in the future. 
 
Future options:
- option to pick the network interface we need to test, in case of multiple network cards or wifi cards
- notifications in case of greatly irregular results
- scheduled runs perhaps with cron jobs
- introduce the use of flags
- 



Tested on a 2006 IBM Z61 :) 
