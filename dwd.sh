url="https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json"
bundesland="Nordrhein-Westfalen"
kreis="Kreis Düren"

data=$(curl -s $url | cut -d '(' -f 2- | jq --arg b "$bundesland" --arg k "$kreis" '.warnings[] | .[] | select(.state == $b) | select(.regionName == $k) | {type,level,event,state,regionName,headline,description}')

if [ -z "$data" ]
then
        data='{"type": 0, "level": 0, "event": "Keine Meldung", "state": "'"$bundesland"'", "regionName": "'"$kreis"'", "headline": "Keine Meldung", "description": "Keine Meldung."}'
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
else
        mosquitto_pub -h 127.0.0.1 -t weather/alerts -m "$data" -r
        echo $data >> /home/homeassistant/dwd/dwd.log
fi
