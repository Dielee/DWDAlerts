# Set own data here
url="https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json"
bundesland="Nordrhein-Westfalen"
kreis="Kreis Wesel"
fixtime=7200 #Difference to UTC in seconds

# Fetch data from DWD
data=$(curl -s $url | cut -d '(' -f 2- | rev | cut -c 3- | rev | \
jq --arg b "$bundesland" --arg k "$kreis" '.warnings[] | .[] | select(.state == $b) | select(.regionName == $k) | {start,"end",type,level,event,state,regionName,headline,description}')

# Calc starttime and endtime from warnings (CEST)
start=$(echo $data | jq --argjson f "$fixtime" '.start/1000 + $f | strftime("%d.%m.%Y %H:%M")' | tr -d '"' )
end=$(echo $data | jq --argjson f "$fixtime" '.end/1000 + $f | strftime("%d.%m.%Y %H:%M")' | tr -d '"' )
event=$(echo $data | jq '.event' | tr '[:upper:]ÄÖÜ' '[:lower:]äöü' | sed -e "s/\b\(.\)/\u\1/g" |  tr -d '"')
level=$(echo $data | jq '.level' )

if [ "$level" == "0" ]
then
        level=""
elif [ "$level" == "1" ]
then
        level="Wetterwarnung"
elif [ "$level" == "2" ]
then
        level="Markantes Wetter"
elif [ "$level" == "3" ]
then
        level="Unwetterwarnung"
elif [ "$level" == "4" ]
then
        level="Extremes Wetter"
fi

# Publish data to broker (HA)
if [ -z "$data" ]
then
        data='{"type": 0, "level": "", "event": "", "state": "'"$bundesland"'", "regionName": "'"$kreis"'", "headline": "", "description": "", "start": "", "end": ""}'
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
else
        data=$(echo $data | jq --arg l "$level" --arg ev "$event" --arg s "$start" --arg e "$end" '{type,state,regionName,headline,description} | . |= . + {"level": $l,"event": $ev,"start": $s, "end": $e}')
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
fi
