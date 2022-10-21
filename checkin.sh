#!/bin/bash

# Init variables
TOOLS_JSON_FILE=~/recon/tools.json

# check if command exist
exists()
{
  command -v "$1" >/dev/null 2>&1
}

# check if go exist to run the script
command -v go >/dev/null 2>&1 || { apt install golang-go -y; }

# check if jq exist to run the script
if ! exists jq ; then
    apt install jq -y
fi

echo "-------------------------------" 
echo "Tool Status" 
echo "-------------------------------" 

# validate each tool installed
for i in $(jq -r '.tools[] | @base64' $TOOLS_JSON_FILE)
do
    row() {
        echo ${i} | base64 -di | jq -r ${1}
    }
    
    tool_name=$(row '.name')
    
    # check if tool exist and if not, install 
    if exists $tool_name ; then
        echo "✅ ${tool_name}" 
    else
        echo "❌ ${tool_name}"
        $(row '.install')
    fi
done

echo "-------------------------------" 
