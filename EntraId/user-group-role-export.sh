#!/bin/bash

GRAPH="https://graph.microsoft.com/v1.0"

echo "UserId;displayName;FirstName;LastName;UPN;Email;Company;JobTitle;Department;Groups" > users_export.csv

url="$GRAPH/users?\$select=id,displayName,givenName,surname,userPrincipalName,mail,companyName,jobTitle,department&\$top=999"

while [ -n "$url" ]; do

  response=$(az rest --method GET --uri "$url" -o json)

  echo "$response" | jq -c '.value[]' | while read user; do

    uid=$(echo $user | jq -r '.id')

    displayName=$(echo $user | jq -r '.displayName')
    first=$(echo $user | jq -r '.givenName')
    last=$(echo $user | jq -r '.surname')
    upn=$(echo $user | jq -r '.userPrincipalName')
    email=$(echo $user | jq -r '.mail')
    company=$(echo $user | jq -r '.companyName')
    title=$(echo $user | jq -r '.jobTitle')
    dept=$(echo $user | jq -r '.department')

    groups=$(az rest --method GET \
      --uri "$GRAPH/users/$uid/transitiveMemberOf?\$select=id" -o json \
      | jq -r '.value[].id' \
      | tr '\n' ',' | sed 's/,$//')

    echo "$uid  $displayName  $first  $last  $upn  $email  $company  $title  $dept  $groups"

    echo "$uid;$displayName;$first;$last;$upn;$email;$company;$title;$dept;$groups" >> users_export.csv

  done

  url=$(echo "$response" | jq -r '."@odata.nextLink" // empty')

done

echo "Done -> users_export.csv"
