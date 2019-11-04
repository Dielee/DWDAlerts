#!/bin/bash

# Set own data here
url="https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json"
bundesland="Nordrhein-Westfalen"
kreis="Kreis Wesel"
fixtime=7200 #Difference to UTC in seconds
date=$(date +'%d.%m.%Y %T')

# Fetch data from DWD
data=$(curl -s $url | cut -d '(' -f 2- | rev | cut -c 3- | rev | \
jq --arg b "$bundesland" --arg k "$kreis" '.warnings[] | .[] | select(.state == $b) | select(.regionName == $k) | {start,"end",type,level,event,state,regionName,headline,description}')

occurrences=$(tr -dc '{' <<<"$data" | wc -c)

i=1
while [ $i -le $occurrences ]
do

data_tmp=$(echo $data | cut -d "}" -f $i)
data_out="${data_tmp}}"

# Calc starttime and endtime from warnings (CEST)
start=$(echo $data_out | jq --argjson f "$fixtime" '.start/1000 + $f | strftime("%d.%m.%Y %H:%M")' | tr -d '"' )
end=$(echo $data_out | jq --argjson f "$fixtime" '.end/1000 + $f | strftime("%d.%m.%Y %H:%M")' | tr -d '"' )
event=$(echo $data_out | jq '.event' | tr '[:upper:]Ã„Ã–Ãœ' '[:lower:]Ã¤Ã¶Ã¼' | sed -e "s/\b\(.\)/\u\1/g" |  tr -d '"')
level=$(echo $data_out | jq '.level' )
headline=$(echo $data_out | jq '.headline')
description=$(echo $data_out | jq '.description')

# Write data to array
start_array[$i]=$start
end_array[$i]=$end
event_array[$i]=$event
level_array[$i]=$level
headline_array[$i]=$headline
description_array[$i]=$description

((i++))
done

start1=${start_array[1]}
start2=${start_array[2]}
end1=${end_array[1]}
end2=${end_array[2]}
event1=${event_array[1]}
event2=${event_array[2]}
headline=${headline_array[@]}
description1=$(echo ${description_array[1]} | tr -d '"')
description2=$(echo ${description_array[2]} | tr -d '"')
level1=${level_array[1]}
level2=${level_array[2]}

if [ "$level1" == "0" ]
then
	level1=""
elif [ "$level1" == "1" ]
then
	level1="Wetterwarnung"
elif [ "$level1" == "2" ]
then
	level1="Markantes Wetter"
elif [ "$level1" == "3" ]
then
	level1="Unwetterwarnung"
elif [ "$level" == "4" ]
then
	level1="Extremes Wetter"
fi

if [ "$level2" == "0" ]
then
        level2=""
elif [ "$level2" == "1" ]
then
        level2="Wetterwarnung"
elif [ "$level2" == "2" ]
then
        level2="Markantes Wetter"
elif [ "$level2" == "3" ]
then
        level2="Unwetterwarnung"
elif [ "$leve2" == "4" ]
then
        level2="Extremes Wetter"
fi


# Publish data to broker (HA)
if [ -z "$data" ]
then
	out_data='{"type": "", "level1": "","level2":"", "event1": "", "event2": "", "state": "'"$bundesland"'", "regionName": "'"$kreis"'", "headline": "", "description1": "",
                   "description2": "", "start1": "","start2":"", "end1": "", "end2": ""}'
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$out_data" -r
        echo $date $out_data >> /home/homeassistant/dwd/dwd.log
else
        out_data=$(echo $data_out | jq --arg d2 "$description2" --arg d1 "$description1" --arg h "$headline" --arg l1 "$level1" --arg l2 "$level2" --arg ev1 "$event1" --arg ev2 "$event2" \
        --arg s2 "$start2" --arg s1 "$start1" --arg e1 "$end1" --arg e2 "$end2" \
        '{type,state,regionName} | . |= . + {"headline": $h, "description1": $d1, "description2": $d2, "level1": $l1,"level2": $l2, "event1": $ev1, "event2": $ev2, "start1": $s1, "start2": $s2, "end1": $e1, "end2": $e2}')
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$out_data" -r
        echo $date $out_data >> /home/homeassistant/dwd/dwd.log
        echo $out_data > /home/homeassistant/dwd/last.json
fi
