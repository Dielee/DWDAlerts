# Set own data here
url="https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json"
bundesland="Nordrhein-Westfalen"
kreis="Kreis Wesel"
fixtime=7200 #Difference to UTC in seconds

# Fetch data from DWD
data=$(curl -s $url | cut -d '(' -f 2- | jq --arg b "$bundesland" --arg k "$kreis" '.warnings[] | .[] | select(.state == $b) | select(.regionName == $k) | {start,"end",type,level,event,state,regionName,headline,description}')

# Calc starttime and endtime from warnings (MESZ)
start=$(echo $data | jq --argjson f "$fixtime" '.start/1000 + $f | strftime("%d-%m-%Y %H:%M")' | tr -d '"' )
end=$(echo $data | jq --argjson f "$fixtime" '.end/1000 + $f | strftime("%d-%m-%Y %H:%M")' | tr -d '"' )

# Insert start and end to data
data=$(echo $data | jq --arg s "$start" --arg e "$end" '{type,level,event,state,regionName,headline,description} | . |= . + {"start": $s, "end": $e}')

# Publish data to broker (HA)
if [ -z "$data" ]
then
        data='{"type": 0, "level": 0, "event": "Keine Meldung", "state": "'"$bundesland"'", "regionName": "'"$kreis"'", "headline": "Keine Meldung", "description": "", "start": "", "end": ""}'
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
else
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
fi
