# avo_hist.gmt version 0.2
# GMT script for creating a 3-D histogram showing the number of earthquakes
# per week at volcanoes seismically monitored by AVO.
# Author: Modified by Matt Gardine from code originally written by Seth Moran
# 01/21/2008
# 
# Changes from version 0.1:
# Now scales the x-axis based on the number of earthquakes in the avo_volcs.pf file
# Increased font size of volcano names
# Added a title

\rm ./.gmtdefaults4
\rm ./AVO_recent_EQ_hist.ps
#set time = `date +%m/%d/%Y%t%H:%M%Z`
set time = `cat temp2.dat`
set data = temp.dat
gmtset HEADER_FONT_SIZE 24

# Finds the number of volcanoes in the temp.dat file created by avo_hist.pl script
# and sets the value to variable count for use scaling the x-axis of final plot
set count = `wc -l $data | awk '{print $1}'`

# Plot the lines around the graph
#psxyz -B0/1::/5::wnZ:."Earthquakes Located per Week by AVO": -R0/$count/0/5/0/35 -Jx0.3 -Jz0.12 -L -M -E195/20 -K -G205 <<END>> AVO_recent_EQ_hist.ps
psxyz -B0/1::/5::wnZ:."Earthquakes located by AVO in the past 4 weeks": -R0/$count/0/5/0/35 -Jx0.3 -Jz0.12 -L -M -E195/20 -K -G205 <<END>> AVO_recent_EQ_hist.ps
>
0 5 0 
$count 5 0
$count 5 35
0 5 35
>
$count 5 0
$count 5 35
$count 0 35
$count 0 0
>
END

psxyz -R -Jx -Jz -L -M -E195/20 -G155 -K -O <<END>> AVO_recent_EQ_hist.ps
>
$count 5 0
$count 5 35
$count 0 35
$count 0 0
>
END

psxyz -R -Jx -Jz -L -M -O -K -E195/20 -W2ta <<END>> AVO_recent_EQ_hist.ps
>
0 5 10
0 0 10
>
0 5 20
0 0 20
>
0 5 30
0 0 30
>
0 5 35
0 0 35
>
0 0 0
0 0 35
>
END

psxyz -R -Jx -Jz -L -O -K -E195/20 -G235 <<END>> AVO_recent_EQ_hist.ps
0 0 35
$count 0 35
$count 5 35
0 5 35
0 0 35
END

# Draw lines for back of box
psxyz -R -Jx -Jz -L -M -E195/20 -K -O <<END>> AVO_recent_EQ_hist.ps
>
$count 5 0
$count 5 35
>
$count 0 0
$count 0 35
>
0 5 0
$count 5 0
>
0 5 10
$count 5 10
>
0 5 20
$count 5 20
>
0 5 30
$count 5 30
>
0 5 35
$count 5 35
>
$count 5 10
$count 0 10
>
$count 5 20
$count 0 20
>
$count 5 30
$count 0 30
>
$count 5 35
$count 0 35
>
END

# Plots the data in 3-D bar graph format from the temporary data file created by the avo_hist perl script
awk '{print $1,$9,$10}' $data | psxyz -R -Jx -Jz -L -G0/155/255 -So0.12/0.35 -E195/20 -W1/0/0/0 -K -O >> AVO_recent_EQ_hist.ps
awk '{print $1,$7,$8}' $data | psxyz -R -Jx -Jz -L -G0/155/255 -So0.12/0.35 -E195/20 -W1/0/0/0 -K -O >> AVO_recent_EQ_hist.ps
awk '{print $1,$5,$6}' $data | psxyz -R -Jx -Jz -L -G0/155/255 -So0.12/0.35 -E195/20 -W1/0/0/0 -K -O >> AVO_recent_EQ_hist.ps
awk '{print $1,$3,$4}' $data | psxyz -R -Jx -Jz -L -G0/155/255 -So0.12/0.35 -E195/20 -W1/0/0/0 -K -O >> AVO_recent_EQ_hist.ps
   
psxyz -R -Jx -Jz -L -M -O -K -E195/20 -W2ta <<END>> AVO_recent_EQ_hist.ps
>
0 0 10
$count 0 10
>
0 0 20
$count 0 20
>
0 0 30
$count 0 30
>
0 0 35
$count 0 35
>
END

# Labels the Y-axis
#echo '   -1 0 17 90 1 1 Weeks Ago'|pstext -Jx -Jz -R -O -E195/20 -N -K -G0/89/0 >> AVO_recent_EQ_hist.ps
echo '-1.66  4.5 22 -90 1 1 weeks ago'|pstext -Jx -Jz -R -O -E195/20 -N -K -G0/89/0 >> AVO_recent_EQ_hist.ps
echo '-0.75 0 15 0 1 1 0'|pstext -Jx -Jz -R -O -E195/20 -N -K >> AVO_recent_EQ_hist.ps
echo '-0.75 1 15 0 1 1 1'|pstext -Jx -Jz -R -O -E195/20 -N -K >> AVO_recent_EQ_hist.ps
echo '-0.75 2 15 0 1 1 2'|pstext -Jx -Jz -R -O -E195/20 -N -K >> AVO_recent_EQ_hist.ps
echo '-0.75 3 15 0 1 1 3'|pstext -Jx -Jz -R -O -E195/20 -N -K >> AVO_recent_EQ_hist.ps
echo '-0.75 4 15 0 1 1 4'|pstext -Jx -Jz -R -O -E195/20 -N -K >> AVO_recent_EQ_hist.ps

# Labels the Z-axis
echo '-1.2 4 17 90 1 1 no. of earthquakes' |pstext -Jx -Jz -R -O -N -K -G0/89/0 >> AVO_recent_EQ_hist.ps

# Date label
echo '22 18 10 0 2 1 through '$time'' |pstext -Jx -Jz -R -O -N -K -G0/0/0 >> AVO_recent_EQ_hist.ps

# Adds a title to the top of the graph
#echo '15 40.5 18 0 1 1 (as of '$time')' |pstext -Jx -Jz -R -O -E195/20 -N -K -G0/89/0 >> AVO_recent_EQ_hist.ps
#echo '15.3 39.75 18 0 1 9 at Volcanoes Seismically Monitored by AVO' |pstext -Jx -Jz -R -O -E195/20 -N -K -G0/89/0 >> AVO_recent_EQ_hist.ps

# Adds the X-axis labels (Volcano Names) from the temporary data file created by the avo_hist perl script
awk '{print $1-.3,-0.5,22,270,1,1,$2}' $data | pstext -G0/0/0 -Jx -Jz -R -E195/20 -O -N >> AVO_recent_EQ_hist.ps

