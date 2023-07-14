# speedtest-basic-testing

 This is a simple bash script that tests the internet connection speed (download/upload) on the current network interface that is connected.
The user is asked to provide the number of tests and sleep time in between them to get the average download and upload speed. There is some input sanitization but nothing crazy. 

The script also writes and appends the results in a csv while also doing the same in case there is an error during the test (written in an a error log).
