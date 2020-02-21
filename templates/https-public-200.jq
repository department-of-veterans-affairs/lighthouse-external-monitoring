{
  "name": "$name",
  "url": "$url",
  "encryption": true,
  "port": $port,
  "verify_certificate": true,
  "host": "$host",
  "type": "http",
  "resolution": $resolution,
  "sendnotificationwhendown": 2,
  "notifyagainevery": 0,
  "notifywhenbackup": true,
  "tags" : [ "managed", "$group" ],
  "responsetime_threshold": "$responsetime_threshold",
  "integrationids": [ $integrationids_csv ]
}
