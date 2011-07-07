awk '9>1440 {print 9, -bash}' diagnostic/hourlydetections.txt | sort -nr | awk  '{print , 0}'
