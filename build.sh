#!/usr/bin/env bash


arrayJoin() {
  (($#)) || return 1 # At least delimiter required
  local -- delim="$1" str IFS=
  shift
  str="${*/#/$delim}" # Expand arguments with prefixed delimiter (Empty IFS)
  echo "${str:${#delim}}" # Echo without first delimiter
}

echo "--- Static code analysis ---"

# get an array of modified files
files=$(git diff --name-only --diff-filter=MA master...dafe8bb | grep \.php || true)
#echo "Raw: $files"

# convert file list to array
declare -a modifiedFiles=($files)
#echo "Array: $modifiedFiles"

# convert array to comma separated string
filesCommaSeparated=$(arrayJoin ',' "${modifiedFiles[@]}")
#echo "Comma separated: $filesCommaSeparated"

# count the array
filesCount=${#modifiedFiles[@]}
echo "--- Files to analyze: $filesCount ---"

if [ $filesCount -gt 0 ]
then
    echo "--- PHPMD execution start ---"

    echo "Analyze: $filesCommaSeparated"
    php vendor/bin/phpmd $filesCommaSeparated text \
	vendor/phpmd/phpmd/src/main/resources/rulesets/cleancode.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/codesize.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/controversial.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/design.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/naming.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/unusedcode.xml \
	--reportfile phpmd_report.txt
    echo "--- PHPMD end ---"

    echo "--- PHPCS execution start ---"
    php vendor/bin/phpcs --config-set installed_paths vendor/magento/magento-coding-standard/
    php vendor/bin/phpcs --extensions=php \
	    --standard=Magento2 \
	    --exclude=Ecg.PHP.PrivateClassMember \
	    --ignore=*/tests/* \
	    --report=full $files > phpcs_report.txt || true
    echo "--- PHPCS end ---"

    # ${PHPPATH} html/vendor/bin/phpcs --extensions=php --standard=Magento2 --exclude=Ecg.PHP.PrivateClassMember --ignore=*/tests/* --report=full $FILES || true

    #    cat phpcs.json
#
#    if [ -f "phpcs.json" ]; then
#        add_comment "\"$(cat phpcs.json | sed "s/\"/'/g")\""
#    fi
else
	echo 'No files for analysis this time'
fi

exit 0
