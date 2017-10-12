#!/bin/sh

if [[ -z $CF_ORG ]]; then
  CF_ORG="$BLUEMIX_ORG"
fi
if [[ -z $CF_SPACE ]]; then
  CF_SPACE="$BLUEMIX_SPACE"
fi


if ([ -z "$BLUEMIX_USER" ] || [ -z "$BLUEMIX_PASSWORD" ] || [ -z "$BLUEMIX_ACCOUNT" ]) && [[ -z "$API_KEY" ]]
then
    echo "Define BLUEMIX_USER, BLUEMIX PASSWORD and BLUEMIX_ACCOUNT environment variables or just use the API_KEY environment variable."
    exit 1
fi
echo "Deploy pods"

echo "bx login -a $CF_TARGET_URL"

if [[ -z "$API_KEY" ]]; then
  bx login -a "$CF_TARGET_URL" -u "$BLUEMIX_USER" -p "$BLUEMIX_PASSWORD" -c "$BLUEMIX_ACCOUNT" -o "$CF_ORG" -s "$CF_SPACE"
else
  bx login -a "$CF_TARGET_URL" --apikey "$API_KEY" -o "$CF_ORG" -s "$CF_SPACE"
fi

# Init container clusters
echo "bx cs init"
if bx cs init -ne 0
then
  echo "Failed to initialize to Bluemix Container Service"
  exit 1
fi
